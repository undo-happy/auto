import Foundation
import SwiftUI
import Combine

enum DownloadState {
    case idle
    case downloading
    case paused
    case completed
    case failed(String)
}

@MainActor
class ContentViewModel: ObservableObject {
    
    @Published var selectedTier: ModelTier = .low
    @Published var showSettings = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var availableSpace: String = ""
    
    @Published var downloadState: DownloadState = .idle
    @Published var downloadProgress: Double = 0.0
    @Published var downloadSpeed: Int64 = 0
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    
    let downloadService: any ModelDownloadServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    nonisolated(unsafe) private var progressTimer: Timer?
    
    init(downloadService: any ModelDownloadServiceProtocol = ModelDownloadService()) {
        self.downloadService = downloadService
        updateAvailableSpace()
        setupProgressMonitoring()
    }
    
    private func updateAvailableSpace() {
        let bytes = AppBundleStorageManager.getAvailableSpace()
        availableSpace = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func setupProgressMonitoring() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateDownloadProgress()
            }
        }
        progressTimer = timer
    }
    
    private func updateDownloadProgress() async {
        guard let service = downloadService as? ModelDownloadService else { return }
        
        let chunkService = service.chunkDownloadService
        
        if chunkService.isDownloading {
            downloadState = .downloading
            downloadProgress = chunkService.overallProgress
            downloadSpeed = Int64(chunkService.downloadSpeed)
            
            let totalFileBytes = chunkService.fileChunks.reduce(0) { $0 + $1.totalSize }
            let downloadedFileBytes = chunkService.fileChunks.reduce(0) { result, fileChunk in
                result + fileChunk.chunks.reduce(0) { $0 + $1.downloadedBytes }
            }
            
            downloadedBytes = downloadedFileBytes
            totalBytes = totalFileBytes
            estimatedTimeRemaining = chunkService.estimatedTimeRemaining
        } else if !chunkService.fileChunks.isEmpty && downloadProgress > 0 && downloadProgress < 1.0 {
            downloadState = .paused
        } else if downloadProgress >= 1.0 || isModelDownloaded {
            downloadState = .completed
        } else {
            downloadState = .idle
        }
        
        if let errorMessage = chunkService.errorMessage {
            downloadState = .failed(errorMessage)
        }
    }
    
    func startDownload() {
        downloadState = .downloading
        downloadProgress = 0.0
        downloadSpeed = 0
        downloadedBytes = 0
        totalBytes = 0
        estimatedTimeRemaining = 0
        
        Task {
            // 다운로드 서비스 초기화 (이전 상태 클리어)
            if let service = downloadService as? ModelDownloadService {
                await service.chunkDownloadService.cancelDownload()
            }
            
            // 부분 다운로드된 파일들 정리
            cleanupPartialFiles()
            
            await downloadService.downloadModel(selectedTier)
            
            let errorMessage = await downloadService.errorMessage
            if let error = errorMessage {
                downloadState = .failed(error)
                alertMessage = error
                showAlert = true
            } else {
                // 다운로드 완료 후 실제 파일 존재 여부 확인
                if isModelDownloaded {
                    downloadState = .completed
                    downloadProgress = 1.0
                } else {
                    // 에러는 없지만 파일이 완전히 다운로드되지 않은 경우
                    downloadState = .paused
                }
            }
        }
    }
    
    func pauseDownload() {
        downloadState = .paused
        Task {
            await downloadService.pauseDownload()
        }
    }
    
    func resumeDownload() {
        downloadState = .downloading
        Task {
            await downloadService.resumeDownload()
        }
    }
    
    func cancelDownload() {
        downloadState = .idle
        downloadProgress = 0.0
        downloadSpeed = 0
        downloadedBytes = 0
        totalBytes = 0
        estimatedTimeRemaining = 0
        
        Task {
            await downloadService.cancelDownload()
        }
    }
    
    func deleteModel() {
        Task {
            await downloadService.cancelDownload()
        }
        
        downloadState = .idle
        downloadProgress = 0.0
        downloadSpeed = 0
        downloadedBytes = 0
        totalBytes = 0
        estimatedTimeRemaining = 0
        
        guard let modelsDirectory = AppBundleStorageManager.getModelsDirectory() else {
            alertMessage = "Cannot access models directory"
            showAlert = true
            return
        }
        
        let modelDirectory = modelsDirectory.appendingPathComponent(selectedTier.folderName)
        
        do {
            if FileManager.default.fileExists(atPath: modelDirectory.path) {
                try FileManager.default.removeItem(at: modelDirectory)
                print("🗑️ [DELETE] Removed model directory: \(selectedTier.folderName)")
                alertMessage = "Model deleted successfully"
                showAlert = true
            }
            
            AppBundleStorageManager.cleanupTempFiles()
            print("🧹 [DELETE] Cleaned up temporary files")
            
        } catch {
            alertMessage = "Failed to delete model: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    var isModelDownloaded: Bool {
        guard let modelsDirectory = AppBundleStorageManager.getModelsDirectory() else {
            return false
        }
        
        let modelDirectory = modelsDirectory.appendingPathComponent(selectedTier.folderName)
        
        guard FileManager.default.fileExists(atPath: modelDirectory.path) else {
            return false
        }
        
        let requiredFiles = selectedTier.fileNames
        for fileName in requiredFiles {
            let filePath = modelDirectory.appendingPathComponent(fileName)
            
            guard FileManager.default.fileExists(atPath: filePath.path) else {
                return false
            }
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath.path)
                if let fileSize = attributes[.size] as? Int64 {
                    if fileSize < 1024 {
                        return false
                    }
                }
            } catch {
                return false
            }
        }
        
        print("✅ [MODEL CHECK] All model files are present and valid")
        return true
    }
    
    private func cleanupPartialFiles() {
        guard let modelsDirectory = AppBundleStorageManager.getModelsDirectory() else {
            return
        }
        
        let modelDirectory = modelsDirectory.appendingPathComponent(selectedTier.folderName)
        
        do {
            if FileManager.default.fileExists(atPath: modelDirectory.path) {
                let files = try FileManager.default.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: [.fileSizeKey])
                
                for file in files {
                    // 부분적으로 다운로드된 작은 파일들 삭제
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                       let fileSize = attributes[.size] as? Int64 {
                        if fileSize < 1024 * 1024 { // 1MB 미만의 파일들은 부분 다운로드로 간주
                            try FileManager.default.removeItem(at: file)
                            print("🗑️ [CLEANUP] Removed partial file: \(file.lastPathComponent) (\(fileSize) bytes)")
                        }
                    }
                }
            }
        } catch {
            print("⚠️ [CLEANUP] Failed to cleanup partial files: \(error)")
        }
    }
    
    deinit {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}