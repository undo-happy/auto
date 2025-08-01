import Foundation
import SwiftUI

protocol ModelDownloadServiceProtocol: ObservableObject, Sendable {
    var isDownloading: Bool { get async }
    var downloadProgress: Double { get async }
    var canResume: Bool { get async }
    var errorMessage: String? { get async }
    var networkManager: NetworkResilienceManagerProtocol { get }
    
    func downloadModel(_ tier: ModelTier) async
    func pauseDownload() async
    func resumeDownload() async
    func cancelDownload() async
}

@MainActor
class ModelDownloadService: ObservableObject, ModelDownloadServiceProtocol, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published private var _isDownloading = false
    @Published private var _downloadProgress: Double = 0.0
    @Published var selectedTier: ModelTier?
    @Published private var _errorMessage: String?
    @Published var isModelDownloaded = false
    @Published private var _canResume = false
    
    var isDownloading: Bool {
        get async { _isDownloading }
    }
    
    var downloadProgress: Double {
        get async { _downloadProgress }
    }
    
    var errorMessage: String? {
        get async { _errorMessage }
    }
    
    var canResume: Bool {
        get async { _canResume }
    }
    @Published var currentFileName = ""
    @Published var downloadSpeed: Double = 0.0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var downloadFiles: [DownloadFileInfo] = []
    @Published var totalDownloadSize: Int64 = 0
    @Published var completedDownloadSize: Int64 = 0
    
    // MARK: - Dependencies
    private let apiClient: HuggingFaceAPIClientProtocol
    private let storageManager: StorageManagerProtocol.Type
    let networkManager: NetworkResilienceManagerProtocol
    let chunkDownloadService: ParallelChunkDownloadService
    
    init(
        apiClient: HuggingFaceAPIClientProtocol = HuggingFaceAPIClient(),
        storageManager: StorageManagerProtocol.Type = AppBundleStorageManager.self,
        networkManager: NetworkResilienceManagerProtocol = NetworkResilienceManager(),
        chunkDownloadService: ParallelChunkDownloadService = ParallelChunkDownloadService()
    ) {
        self.apiClient = apiClient
        self.storageManager = storageManager
        self.networkManager = networkManager
        self.chunkDownloadService = chunkDownloadService
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind to chunk download service
        chunkDownloadService.$overallProgress
            .assign(to: &$_downloadProgress)
        
        chunkDownloadService.$isDownloading
            .assign(to: &$_isDownloading)
        
        chunkDownloadService.$downloadSpeed
            .assign(to: &$downloadSpeed)
        
        chunkDownloadService.$estimatedTimeRemaining
            .assign(to: &$estimatedTimeRemaining)
        
        chunkDownloadService.$errorMessage
            .assign(to: &$_errorMessage)
    }
    
    func downloadModel(_ tier: ModelTier) async {
        print("🚀 [DOWNLOAD] Starting download for: \(tier.rawValue)")

        // Force a network connectivity check before starting the download
        print("🔍 [DOWNLOAD] Checking network connectivity...")
        let isConnected = await networkManager.checkConnectivity()

        guard isConnected else {
            let connectionType = await networkManager.connectionType
            _errorMessage = "네트워크 연결을 확인할 수 없습니다. 현재 상태: \(connectionType.rawValue)"
            print("❌ [DOWNLOAD] Network check failed. Current type: \(connectionType.rawValue)")

            // Manually update the connection type to none to reflect the failure in the UI
            if let networkManager = self.networkManager as? NetworkResilienceManager {
                networkManager.setConnectionType(.none)
            }

            return
        }

        print("✅ [DOWNLOAD] Network connectivity confirmed")
        
        do {
            print("🔧 [RELIABLE DOWNLOAD] Resetting download state and cleaning up...")
            
            // FORCE CANCEL ANY EXISTING DOWNLOADS
            chunkDownloadService.cancelDownload()
            try await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s for cleanup
            
            resetDownloadState()
            selectedTier = tier
            _isDownloading = true
            
            // Fetch repository files
            print("🔍 [DOWNLOAD] Fetching repository files for: \(tier.repoId)")
            let repoFiles = try await apiClient.fetchRepoFiles(for: tier)
            print("✅ [DOWNLOAD] Successfully fetched \(repoFiles.count) files from repository")
            
            for file in repoFiles {
                print("   📄 Found file: \(file)")
            }

            // Use predefined file sizes for now to ensure downloads work
            let files: [(url: String, fileName: String, totalSize: Int64)]
            
            switch tier {
            case .low:
                // Gemma E2B 4bit - approximate sizes
                files = tier.fileNames.map { fileName in
                    let estimatedSize: Int64 = fileName.contains("model") ? 4_200_000_000 : 1_000_000 // 4.2GB for model, 1MB for config
                    let downloadURL = "https://huggingface.co/\(tier.repoId)/resolve/main/\(fileName)"
                    return (url: downloadURL, fileName: fileName, totalSize: estimatedSize)
                }
            case .medium:
                // Gemma E2B BF16 - approximate sizes  
                files = tier.fileNames.map { fileName in
                    let estimatedSize: Int64 = fileName.contains("model") ? 10_500_000_000 : 1_000_000 // 10.5GB for model, 1MB for config
                    let downloadURL = "https://huggingface.co/\(tier.repoId)/resolve/main/\(fileName)"
                    return (url: downloadURL, fileName: fileName, totalSize: estimatedSize)
                }
            case .high:
                // Gemma E4B - approximate sizes
                files = tier.fileNames.map { fileName in
                    let estimatedSize: Int64 = fileName.contains("model") ? 15_200_000_000 : 1_000_000 // 15.2GB for model, 1MB for config
                    let downloadURL = "https://huggingface.co/\(tier.repoId)/resolve/main/\(fileName)"
                    return (url: downloadURL, fileName: fileName, totalSize: estimatedSize)
                }
            }
            
            print("🎯 [DOWNLOAD] Using predefined file sizes for \(files.count) files")
            for file in files {
                print("   📁 \(file.fileName): \(ByteCountFormatter.string(fromByteCount: file.totalSize, countStyle: .file))")
            }
            
            guard !files.isEmpty else {
                _errorMessage = "No model files found"
                return
            }
            
            // Create destination directory
            let destinationDirectory = try storageManager.createModelDirectory(for: tier)
            
            // Check available space
            let totalSize = files.reduce(0) { $0 + $1.totalSize }
            let availableSpace = storageManager.getAvailableSpace()
            
            guard availableSpace > totalSize * 2 else { // 2x for safety margin
                _errorMessage = DownloadError.insufficientStorage.localizedDescription
                return
            }
            
            totalDownloadSize = totalSize
            
            // Start chunk-based download
            print("🚀 [DOWNLOAD] Starting chunk-based download of \(files.count) files")
            print("📊 [DOWNLOAD] Total download size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
            print("📂 [DOWNLOAD] Destination: \(destinationDirectory.path)")
            
            for (index, file) in files.enumerated() {
                print("   📁 File \(index + 1): \(file.fileName) (\(ByteCountFormatter.string(fromByteCount: file.totalSize, countStyle: .file)))")
            }
            
            await chunkDownloadService.startDownload(files: files, to: destinationDirectory)
            print("🏁 [DOWNLOAD] Chunk download service completed")
            
            // Check if download completed successfully
            let allChunksCompleted = chunkDownloadService.fileChunks.allSatisfy({ $0.isCompleted })
            let noErrors = _errorMessage == nil
            
            print("📊 [DOWNLOAD] Final status check:")
            print("   - All chunks completed: \(allChunksCompleted)")
            print("   - No errors: \(noErrors)")
            print("   - File chunks count: \(chunkDownloadService.fileChunks.count)")
            
            for (index, fileChunk) in chunkDownloadService.fileChunks.enumerated() {
                let completedChunks = fileChunk.chunks.filter { $0.isCompleted }.count
                print("   - File \(index + 1): \(completedChunks)/\(fileChunk.chunks.count) chunks completed")
            }
            
            if allChunksCompleted && noErrors {
                isModelDownloaded = true
                _canResume = false
                print("✅ [DOWNLOAD] Model download completed: \(tier.rawValue)")
            } else {
                _canResume = true
                print("⚠️ [DOWNLOAD] Download incomplete, can be resumed")
            }
            
        } catch let error as URLError {
            let detailedMessage = "Network Error: \(error.localizedDescription) (Code: \(error.code.rawValue))"
            _errorMessage = detailedMessage
            _canResume = true
            print("❌ [DOWNLOAD] Download failed with URLError: \(detailedMessage)")
        } catch {
            _errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            _canResume = true
            print("❌ [DOWNLOAD] Download failed: \(error)")
        }
    }
    
    func pauseDownload() async {
        guard _isDownloading else { return }
        
        print("⏸️ [DOWNLOAD] Pausing download...")
        chunkDownloadService.pauseDownload()
        _canResume = true
    }
    
    func resumeDownload() async {
        guard _canResume, let tier = selectedTier else {
            _errorMessage = "No download to resume"
            return
        }
        
        print("▶️ [RELIABLE RESUME] Starting reliable resume process...")
        _isDownloading = true
        _canResume = false
        _errorMessage = nil
        
        // Check if we have existing incomplete chunks
        let hasIncompleteChunks = !chunkDownloadService.fileChunks.isEmpty && 
                                 chunkDownloadService.fileChunks.contains { !$0.isCompleted }
        
        if hasIncompleteChunks {
            print("🔄 [RELIABLE RESUME] Found incomplete chunks, resuming...")
            chunkDownloadService.resumePausedChunks()
            
            // Wait for resume to complete and check status
            while await chunkDownloadService.isDownloading {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
            }
            
            // Check final status after resume
            let allCompleted = await MainActor.run { 
                chunkDownloadService.fileChunks.allSatisfy { $0.isCompleted }
            }
            if allCompleted && _errorMessage == nil {
                isModelDownloaded = true
                _canResume = false
                print("✅ [RELIABLE RESUME] Resume completed successfully")
            } else {
                print("⚠️ [RELIABLE RESUME] Resume incomplete, restarting full download...")
                await downloadModel(tier)
            }
        } else {
            print("🔄 [RELIABLE RESUME] No incomplete chunks found, restarting full download...")
            await downloadModel(tier)
        }
    }
    
    func cancelDownload() async {
        print("🛑 [DOWNLOAD] Canceling download...")
        chunkDownloadService.cancelDownload()
        resetDownloadState()
    }
    
    private func resetDownloadState() {
        _isDownloading = false
        _downloadProgress = 0.0
        _errorMessage = nil
        isModelDownloaded = false
        _canResume = false
        currentFileName = ""
        downloadSpeed = 0.0
        estimatedTimeRemaining = 0
        downloadFiles = []
        totalDownloadSize = 0
        completedDownloadSize = 0
    }
}