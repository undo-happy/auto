import Foundation
import SwiftUI

// Using ChunkInfo and FileChunkInfo from Models/ChunkInfo.swift

// MARK: - Advanced Chunk Download Manager
@MainActor
class ParallelChunkDownloadService: ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var fileChunks: [FileChunkInfo] = []
    @Published var overallProgress: Double = 0.0
    @Published var downloadSpeed: Double = 0.0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var isDownloading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let chunkDownloader = ChunkDownloader()
    private var downloadStartTime: Date?
    private var totalBytesDownloaded: Int64 = 0
    private var lastProgressUpdate: Date = Date()
    private let progressUpdateInterval: TimeInterval = 0.1
    private let maxConcurrentChunks = 4 // Increased for better performance
    
    // Task management for proper pause/resume
    private var downloadTask: Task<Void, Never>?
    private var isPaused: Bool = false
    private var currentFiles: [(url: String, fileName: String, totalSize: Int64)] = []
    private var currentDestinationDirectory: URL?
    
    // MARK: - Public Methods
    func startDownload(files: [(url: String, fileName: String, totalSize: Int64)], to destinationDirectory: URL) async {
        // Cancel any existing download
        downloadTask?.cancel()
        
        downloadTask = Task { @MainActor in
            await performDownload(files: files, to: destinationDirectory)
        }
        
        await downloadTask?.value
    }
    
    private func performDownload(files: [(url: String, fileName: String, totalSize: Int64)], to destinationDirectory: URL) async {
        // AGGRESSIVE CLEANUP BEFORE STARTING
        print("🧹 [PRE-DOWNLOAD] Aggressive cleanup before starting...")
        aggressiveCleanup()
        
        // Store current download info for resume functionality
        currentFiles = files
        currentDestinationDirectory = destinationDirectory
        
        isDownloading = true
        isPaused = false
        errorMessage = nil
        downloadStartTime = Date()
        totalBytesDownloaded = 0
        
        // Smart chunk creation based on file size
        fileChunks = files.map { file in
            print("📦 [CHUNK] Processing file: \(file.fileName) (\(ByteCountFormatter.string(fromByteCount: file.totalSize, countStyle: .file)))")
            
            // Adaptive chunk sizing based on file size for optimal performance
            let optimalChunkSize = calculateOptimalChunkSize(for: file.totalSize)
            print("🔧 [CHUNK] Using adaptive chunk size: \(ByteCountFormatter.string(fromByteCount: optimalChunkSize, countStyle: .file))")
            
            let numChunks = max(1, (file.totalSize + optimalChunkSize - 1) / optimalChunkSize)
            let chunks = (0..<numChunks).map { chunkIndex in
                let startByte = chunkIndex * optimalChunkSize
                let endByte = min(startByte + optimalChunkSize - 1, file.totalSize - 1)
                
                return ChunkInfo(
                    id: "\(file.fileName)_chunk_\(chunkIndex)",
                    startByte: startByte,
                    endByte: endByte,
                    downloadedBytes: 0,
                    isCompleted: false,
                    isPaused: false,
                    isInProgress: false
                )
            }
            
            print("   ✅ Created \(chunks.count) chunks for \(file.fileName)")
            return FileChunkInfo(
                fileName: file.fileName,
                totalSize: file.totalSize,
                chunks: chunks
            )
        }
        
        // Smart chunk size calculation
        func calculateOptimalChunkSize(for fileSize: Int64) -> Int64 {
            switch fileSize {
            case 0..<(100 * 1024 * 1024): // < 100MB
                return 5 * 1024 * 1024 // 5MB chunks
            case (100 * 1024 * 1024)..<(1024 * 1024 * 1024): // 100MB - 1GB
                return 10 * 1024 * 1024 // 10MB chunks
            case (1024 * 1024 * 1024)..<(5 * 1024 * 1024 * 1024): // 1GB - 5GB
                return 25 * 1024 * 1024 // 25MB chunks
            default: // > 5GB
                return 50 * 1024 * 1024 // 50MB chunks
            }
        }
        
        let totalChunks = fileChunks.reduce(0) { $0 + $1.chunks.count }
        print("🎯 [CHUNK] Total chunks created: \(totalChunks) across \(fileChunks.count) files")
        
        // Download all files sequentially
        for (fileIndex, file) in files.enumerated() {
            // Check for cancellation or pause
            if Task.isCancelled || isPaused {
                break
            }
            
            await downloadFileChunks(fileIndex: fileIndex, file: file, destinationDirectory: destinationDirectory)
            
            if !isDownloading || isPaused {
                break // Download was paused or cancelled
            }
        }
        
        if !isPaused && !Task.isCancelled {
            isDownloading = false
        }
    }
    
    func pauseDownload() {
        print("🔄 [PAUSE] Pausing chunk downloads...")
        
        isPaused = true
        isDownloading = false
        
        // Cancel current download task
        downloadTask?.cancel()
        
        // Cancel all active chunk downloads
        Task {
            await chunkDownloader.cancelAllDownloads()
        }
        
        // Mark in-progress chunks as paused (preserve partial data)
        for fileIndex in fileChunks.indices {
            for chunkIndex in fileChunks[fileIndex].chunks.indices {
                if fileChunks[fileIndex].chunks[chunkIndex].isInProgress && !fileChunks[fileIndex].chunks[chunkIndex].isCompleted {
                    fileChunks[fileIndex].chunks[chunkIndex].isPaused = true
                }
            }
        }
        
        print("✅ [PAUSE] Chunk downloads paused")
    }
    
    func resumePausedChunks() {
        print("🔄 [RESUME] Resuming paused downloads...")
        
        guard isPaused else {
            print("⚠️ [RESUME] No paused download to resume")
            return
        }
        
        isPaused = false
        isDownloading = true
        
        // Reset paused state for incomplete chunks
        for fileIndex in fileChunks.indices {
            for chunkIndex in fileChunks[fileIndex].chunks.indices {
                if fileChunks[fileIndex].chunks[chunkIndex].isPaused {
                    fileChunks[fileIndex].chunks[chunkIndex].isPaused = false
                }
            }
        }
        
        // Restart download task with remaining chunks
        downloadTask = Task { @MainActor in
            await resumeDownloadFromCurrentState()
        }
        
        print("✅ [RESUME] Paused chunks resumed")
    }
    
    private func resumeDownloadFromCurrentState() async {
        guard let destinationDirectory = currentDestinationDirectory else {
            print("❌ [RESUME] No destination directory stored")
            return
        }
        
        // Find files that are not completed and resume downloading
        for (fileIndex, fileChunk) in fileChunks.enumerated() {
            if !fileChunk.isCompleted && !isPaused && !Task.isCancelled {
                // Find the corresponding file info from currentFiles
                if let originalFile = currentFiles.first(where: { $0.fileName == fileChunk.fileName }) {
                    print("🔄 [RESUME] Resuming file: \(fileChunk.fileName)")
                    await downloadFileChunks(fileIndex: fileIndex, file: originalFile, destinationDirectory: destinationDirectory)
                }
            }
            
            // Check for pause/cancel between files
            if isPaused || Task.isCancelled {
                break
            }
        }
        
        if !isPaused && !Task.isCancelled {
            isDownloading = false
            print("✅ [RESUME] All files completed")
        }
    }
    
    func cancelDownload() {
        print("🛑 [CANCEL] Canceling all downloads...")
        
        isPaused = false
        isDownloading = false
        
        // Cancel the main download task
        downloadTask?.cancel()
        downloadTask = nil
        
        // Cancel all active chunk downloads
        Task {
            await chunkDownloader.cancelAllDownloads()
        }
        
        // AGGRESSIVE CLEANUP: Remove ALL temporary and partial files
        aggressiveCleanup()
        
        // Reset all state
        fileChunks = []
        overallProgress = 0.0
        downloadSpeed = 0.0
        estimatedTimeRemaining = 0
        totalBytesDownloaded = 0
        currentFiles = []
        currentDestinationDirectory = nil
        errorMessage = nil
        
        print("✅ [CANCEL] All downloads canceled and everything cleaned")
    }
    
    private func aggressiveCleanup() {
        print("🧹 [AGGRESSIVE CLEANUP] Starting complete cleanup...")
        
        // 1. Clean up temporary chunk files
        cleanupTemporaryChunkFiles()
        
        // 2. Clean up other temp files
        AppBundleStorageManager.cleanupTempFiles()
        
        // 3. Remove partial model files from destination directories
        if let modelsDir = AppBundleStorageManager.getModelsDirectory() {
            for tier in ModelTier.allCases {
                let tierDir = modelsDir.appendingPathComponent(tier.folderName)
                if FileManager.default.fileExists(atPath: tierDir.path) {
                    do {
                        let files = try FileManager.default.contentsOfDirectory(at: tierDir, includingPropertiesForKeys: [.fileSizeKey])
                        
                        for file in files {
                            // Check if file is too small (likely incomplete)
                            if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                               let fileSize = attributes[.size] as? Int64 {
                                if fileSize < 1024 * 1024 { // Less than 1MB = likely incomplete
                                    try FileManager.default.removeItem(at: file)
                                    print("🗑️ [AGGRESSIVE CLEANUP] Removed incomplete file: \(file.lastPathComponent) (\(fileSize) bytes)")
                                }
                            }
                        }
                    } catch {
                        print("⚠️ [AGGRESSIVE CLEANUP] Failed to clean \(tier.folderName): \(error)")
                    }
                }
            }
        }
        
        // 4. No chunk data to clear - using zero-RAM architecture
        
        print("✅ [AGGRESSIVE CLEANUP] Complete cleanup finished")
    }
    
    private func cleanupTemporaryChunkFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            let chunkFiles = tempFiles.filter { $0.pathExtension == "tmp" && $0.lastPathComponent.contains("_chunk_") }
            
            for chunkFile in chunkFiles {
                try FileManager.default.removeItem(at: chunkFile)
                print("🗑️ [CLEANUP] Removed temp chunk: \(chunkFile.lastPathComponent)")
            }
            
            print("🧹 [CLEANUP] Removed \(chunkFiles.count) temporary chunk files")
        } catch {
            print("⚠️ [CLEANUP] Failed to cleanup temp files: \(error)")
        }
    }
    
    // MARK: - FAST ORIGINAL METHOD - Back to High Speed
    private func downloadFileChunks(fileIndex: Int, file: (url: String, fileName: String, totalSize: Int64), destinationDirectory: URL) async {
        // SAFETY CHECK: 파일 인덱스 검증
        guard fileIndex >= 0 && fileIndex < fileChunks.count else {
            print("❌ [SAFETY] downloadFileChunks - Invalid fileIndex: \(fileIndex), fileChunks.count: \(fileChunks.count)")
            await MainActor.run {
                errorMessage = "Invalid file index: \(fileIndex)"
            }
            return
        }
        
        let fileChunk = fileChunks[fileIndex]
        
        guard !fileChunk.chunks.isEmpty else {
            print("⚠️ No chunks available for file: \(fileChunk.fileName)")
            return
        }
        
        print("🚀 [FAST] Starting HIGH SPEED chunk download for file: \(fileChunk.fileName) (\(fileChunk.chunks.count) chunks)")
        
        // ORIGINAL FAST METHOD: All chunks download concurrently
        await withTaskGroup(of: Void.self) { group in
            // Start ALL chunks at once for maximum speed
            for chunkIndex in fileChunk.chunks.indices {
                // Skip completed chunks
                if fileChunk.chunks[chunkIndex].isCompleted {
                    continue
                }
                
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    await self.downloadSingleChunkWithRetry(fileIndex: fileIndex, chunkIndex: chunkIndex, file: file)
                }
            }
            
            // Wait for all to complete
            for await _ in group {
                // Update progress after each chunk
                await MainActor.run {
                    updateProgress()
                }
                
                // Check for pause/cancel
                if isPaused || Task.isCancelled {
                    print("⏸️ [FAST] Download paused or cancelled")
                    break
                }
            }
        }
        
        print("🏁 [FAST] All chunks completed for \(fileChunk.fileName)")
        
        // Merge chunks after all downloads complete
        await mergeChunks(fileIndex: fileIndex, file: file, destinationDirectory: destinationDirectory)
    }
    
    // MARK: - Retry Logic for Robust Downloads
    private func downloadSingleChunkWithRetry(fileIndex: Int, chunkIndex: Int, file: (url: String, fileName: String, totalSize: Int64)) async {
        let maxRetries = 5
        var attempt = 0
        
        while attempt < maxRetries {
            do {
                try await downloadSingleChunk(fileIndex: fileIndex, chunkIndex: chunkIndex, file: file)
                return // Success, exit retry loop
            } catch {
                attempt += 1
                print("❌ [RETRY] Chunk \(chunkIndex) attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // 빠른 재시도: 0.5s, 1s, 2s, 3s
                    let delay: TimeInterval
                    switch attempt {
                    case 1: delay = 0.5
                    case 2: delay = 1.0
                    case 3: delay = 2.0
                    default: delay = 3.0
                    }
                    
                    print("⏳ [RETRY] Retrying chunk \(chunkIndex) after \(delay)s delay...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    print("💀 [RETRY] Chunk \(chunkIndex) failed after \(maxRetries) attempts")
                    await MainActor.run {
                        errorMessage = "Failed to download chunk after \(maxRetries) attempts: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func downloadSingleChunk(fileIndex: Int, chunkIndex: Int, file: (url: String, fileName: String, totalSize: Int64)) async throws {
        // SAFETY CHECK: 배열 범위 검증
        guard fileIndex >= 0 && fileIndex < fileChunks.count else {
            print("❌ [SAFETY] Invalid fileIndex: \(fileIndex), fileChunks.count: \(fileChunks.count)")
            throw DownloadError.unknown("Invalid file index")
        }
        
        guard chunkIndex >= 0 && chunkIndex < fileChunks[fileIndex].chunks.count else {
            print("❌ [SAFETY] Invalid chunkIndex: \(chunkIndex), chunks.count: \(fileChunks[fileIndex].chunks.count)")
            throw DownloadError.unknown("Invalid chunk index")
        }
        
        let chunk = fileChunks[fileIndex].chunks[chunkIndex]
        
        // Skip if already completed, paused, or if task is cancelled
        if chunk.isCompleted || chunk.isPaused || Task.isCancelled {
            return
        }
        
        // Check pause state on MainActor
        if await MainActor.run { isPaused } {
            return
        }
        
        guard let url = URL(string: file.url) else {
            await MainActor.run {
                errorMessage = "Invalid URL for \(file.fileName)"
            }
            return
        }
        
        // Mark chunk as in progress
        await MainActor.run {
            fileChunks[fileIndex].chunks[chunkIndex].isInProgress = true
        }
        
        do {
            // Calculate actual range considering any existing partial data
            let actualStartByte = chunk.startByte + chunk.downloadedBytes
            let actualEndByte = chunk.endByte
            
            // Skip if already fully downloaded
            if actualStartByte > actualEndByte {
                await MainActor.run {
                    fileChunks[fileIndex].chunks[chunkIndex].isCompleted = true
                    fileChunks[fileIndex].chunks[chunkIndex].isInProgress = false
                }
                return
            }
            
            let (bytesDownloaded, isFullFile) = try await chunkDownloader.downloadChunk(
                from: url,
                startByte: actualStartByte,
                endByte: actualEndByte,
                chunkId: chunk.id
            )
            
            // Check one more time before updating (in case of cancellation during download)
            if Task.isCancelled {
                await MainActor.run {
                    fileChunks[fileIndex].chunks[chunkIndex].isInProgress = false
                    fileChunks[fileIndex].chunks[chunkIndex].isPaused = true
                }
                return
            }
            
            // Check pause state
            if await MainActor.run { isPaused } {
                await MainActor.run {
                    fileChunks[fileIndex].chunks[chunkIndex].isInProgress = false
                    fileChunks[fileIndex].chunks[chunkIndex].isPaused = true
                }
                return
            }
            
            // ZERO-RAM: Chunk is already written to disk by StreamingDownloadDelegate
            print("💾 [ZERO-RAM] Chunk \(chunk.id) streamed directly to disk (\(ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)))")
            
            // Update chunk info WITHOUT any memory usage
            await MainActor.run {
                // SAFETY CHECK: 배열 접근 전 재검증
                guard fileIndex < fileChunks.count && chunkIndex < fileChunks[fileIndex].chunks.count else {
                    print("❌ [SAFETY] MainActor update - Invalid indices: fileIndex=\(fileIndex), chunkIndex=\(chunkIndex)")
                    return
                }
                
                let newDownloadedBytes = fileChunks[fileIndex].chunks[chunkIndex].downloadedBytes + bytesDownloaded
                fileChunks[fileIndex].chunks[chunkIndex].downloadedBytes = newDownloadedBytes
                
                // Check completion: if we got full file (HTTP 200) or expected range size
                let expectedSize = chunk.endByte - chunk.startByte + 1
                let isComplete = isFullFile || newDownloadedBytes >= expectedSize
                
                fileChunks[fileIndex].chunks[chunkIndex].isCompleted = isComplete
                fileChunks[fileIndex].chunks[chunkIndex].isInProgress = false
                
                print("📊 [ZERO-RAM] Chunk \(chunk.id): \(newDownloadedBytes)/\(expectedSize) bytes (Complete: \(isComplete)) \(isFullFile ? "[FULL FILE]" : "[PARTIAL]")")
                
                // 실시간 진행률 업데이트
                updateProgress()
                
                // UI에 즉시 반영하기 위해 강제 업데이트
                Task { @MainActor in
                    // objectWillChange 트리거
                    self.objectWillChange.send()
                }
            }
            
        } catch {
            await MainActor.run {
                // Mark as paused rather than failed so it can be resumed
                fileChunks[fileIndex].chunks[chunkIndex].isInProgress = false
                fileChunks[fileIndex].chunks[chunkIndex].isPaused = true
            }
            // Re-throw the error so retry logic can handle it
            throw error
        }
    }
    
    private func mergeChunks(fileIndex: Int, file: (url: String, fileName: String, totalSize: Int64), destinationDirectory: URL) async {
        let outputURL = destinationDirectory.appendingPathComponent(file.fileName)
        print("🔗 [MERGE] Starting merge for \(file.fileName) (\(fileChunks[fileIndex].chunks.count) chunks)")
        
        do {
            // Create or truncate the output file
            if !FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: nil) {
                throw DownloadError.unknown("Cannot create output file")
            }
            
            let fileHandle = try FileHandle(forWritingTo: outputURL)
            defer { 
                fileHandle.closeFile()
                print("📁 [MERGE] Closed file handle for \(file.fileName)")
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            
            // ZERO-RAM MERGE: Stream chunks from disk without loading into memory
            var missingChunks = 0
            var mergedChunks = 0
            let bufferSize = 64 * 1024 // 64KB buffer for streaming
            
            for (index, chunk) in fileChunks[fileIndex].chunks.enumerated() {
                // Skip chunks that are not completed
                if !chunk.isCompleted {
                    print("⏭️ [MERGE] Skipping incomplete chunk \(index + 1)/\(fileChunks[fileIndex].chunks.count)")
                    missingChunks += 1
                    continue
                }
                
                let chunkFileName = "\(chunk.id).tmp"
                let chunkFileURL = tempDir.appendingPathComponent(chunkFileName)
                
                if FileManager.default.fileExists(atPath: chunkFileURL.path) {
                    do {
                        // ZERO-RAM: Stream copy using FileHandle instead of loading into memory
                        let inputHandle = try FileHandle(forReadingFrom: chunkFileURL)
                        defer { inputHandle.closeFile() }
                        
                        // Stream copy in small chunks to avoid memory usage
                        while true {
                            let chunkData = inputHandle.readData(ofLength: bufferSize)
                            if chunkData.isEmpty { break }
                            fileHandle.write(chunkData)
                        }
                        
                        // Clean up temporary chunk file immediately after streaming
                        try FileManager.default.removeItem(at: chunkFileURL)
                        mergedChunks += 1
                        print("🗑️ [ZERO-RAM] Streamed and deleted chunk \(index + 1)/\(fileChunks[fileIndex].chunks.count)")
                        
                    } catch {
                        print("⚠️ [MERGE] Failed to stream/delete chunk \(chunk.id): \(error)")
                        missingChunks += 1
                    }
                } else {
                    print("⚠️ [MERGE] Chunk file not found: \(chunkFileName)")
                    missingChunks += 1
                }
            }
            
            print("📊 [ZERO-RAM] Stats: \(mergedChunks) merged, \(missingChunks) missing chunks")
            
            // Check if file is complete
            if missingChunks > 0 {
                print("⚠️ [MERGE] File incomplete: \(file.fileName) - \(missingChunks) chunks missing")
                
                // Mark file chunks as incomplete for resume
                await MainActor.run {
                    for chunkIndex in fileChunks[fileIndex].chunks.indices {
                        if !fileChunks[fileIndex].chunks[chunkIndex].isCompleted {
                            fileChunks[fileIndex].chunks[chunkIndex].isPaused = true
                        }
                    }
                }
                
                // Remove partial file
                try? FileManager.default.removeItem(at: outputURL)
                
                throw DownloadError.downloadIncomplete("Missing \(missingChunks) chunks")
            } else {
                print("✅ [ZERO-RAM] Successfully merged file: \(file.fileName)")
            }
            
            // ZERO-RAM: No chunk data stored in memory - nothing to cleanup
            print("🧹 [ZERO-RAM] No memory cleanup needed for \(file.fileName) - zero RAM architecture")
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to merge chunks for \(file.fileName): \(error.localizedDescription)"
            }
        }
    }
    
    private func updateProgress() {
        let totalBytes = fileChunks.reduce(0) { $0 + $1.totalSize }
        let downloadedBytes = fileChunks.reduce(0) { result, fileChunk in
            result + fileChunk.chunks.reduce(0) { $0 + $1.downloadedBytes }
        }
        
        // ALWAYS update progress - no throttling for UI responsiveness
        overallProgress = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 0.0
        
        // Calculate download speed
        if let startTime = downloadStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 1.0 { // Only calculate after at least 1 second
                downloadSpeed = Double(downloadedBytes) / elapsed
                
                let remainingBytes = totalBytes - downloadedBytes
                estimatedTimeRemaining = downloadSpeed > 0 ? Double(remainingBytes) / downloadSpeed : 0
            }
        }
        
        totalBytesDownloaded = max(totalBytesDownloaded, downloadedBytes)
        
        // 실시간 진행률 로그 (매 청크마다)
        let progressPercent = overallProgress * 100
        print("📊 [PROGRESS] \(String(format: "%.1f", progressPercent))% (\(ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file))/\(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))) Speed: \(ByteCountFormatter.string(fromByteCount: Int64(downloadSpeed), countStyle: .file))/s")
    }
}

// MARK: - Zero-RAM Streaming Download Delegate
private class StreamingDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let fileHandle: FileHandle?
    private var continuation: CheckedContinuation<Void, Error>?
    private(set) var bytesWritten: Int64 = 0
    private(set) var response: URLResponse?
    private(set) var error: Error?
    
    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
        super.init()
    }
    
    
    func waitForCompletion() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let fileHandle = fileHandle else {
            self.error = DownloadError.unknown("File handle not set")
            continuation?.resume(throwing: self.error!)
            return
        }
        
        do {
            fileHandle.write(data)
            bytesWritten += Int64(data.count)
        } catch {
            self.error = error
            continuation?.resume(throwing: error)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.error = error
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }
}

// MARK: - Advanced ChunkDownloader Implementation
actor ChunkDownloader {
    private var activeTasks: [String: URLSessionDataTask] = [:]
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120  // 2분으로 증가
        config.timeoutIntervalForResource = 1200 // 20분으로 증가
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        config.networkServiceType = .background
        self.session = URLSession(configuration: config)
        
        // Clean up any leftover temporary files from previous sessions
        Task {
            await cleanupOldTemporaryFiles()
        }
    }
    
    private func cleanupOldTemporaryFiles() async {
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey])
            let chunkFiles = tempFiles.filter { $0.pathExtension == "tmp" && $0.lastPathComponent.contains("_chunk_") }
            
            let oneHourAgo = Date().addingTimeInterval(-3600) // 1 hour ago
            
            for chunkFile in chunkFiles {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: chunkFile.path)
                    if let creationDate = attributes[.creationDate] as? Date,
                       creationDate < oneHourAgo {
                        try FileManager.default.removeItem(at: chunkFile)
                        print("🧹 [CLEANUP] Removed old temp chunk: \(chunkFile.lastPathComponent)")
                    }
                } catch {
                    // If we can't get attributes, just remove it
                    try? FileManager.default.removeItem(at: chunkFile)
                }
            }
            
            if chunkFiles.isEmpty {
                print("✅ [CLEANUP] No old temporary files found")
            } else {
                print("🧹 [CLEANUP] Checked \(chunkFiles.count) temporary chunk files")
            }
        } catch {
            print("⚠️ [CLEANUP] Failed to cleanup old temp files: \(error)")
        }
    }
    
    func downloadChunk(from url: URL, startByte: Int64, endByte: Int64, chunkId: String) async throws -> (Int64, Bool) {
        print("📥 [CHUNK] Downloading \(chunkId): bytes \(startByte)-\(endByte)")
        
        var request = URLRequest(url: url)
        request.setValue("bytes=\(startByte)-\(endByte)", forHTTPHeaderField: "Range")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 120
        
        let startTime = Date()
        
        // Set up file output path
        let tempDir = FileManager.default.temporaryDirectory
        let chunkFileName = "\(chunkId).tmp"
        let chunkFileURL = tempDir.appendingPathComponent(chunkFileName)
        
        // Create or truncate the file
        if !FileManager.default.createFile(atPath: chunkFileURL.path, contents: nil, attributes: nil) {
            throw DownloadError.unknown("Cannot create chunk file")
        }
        
        let fileHandle = try FileHandle(forWritingTo: chunkFileURL)
        
        // Create URLSessionDataDelegate for streaming
        let delegate = StreamingDownloadDelegate(fileHandle: fileHandle)
        let session = URLSession(configuration: self.session.configuration, delegate: delegate, delegateQueue: nil)
        
        defer {
            fileHandle.closeFile()
        }
        
        // Start download task
        let task = session.dataTask(with: request)
        activeTasks[chunkId] = task
        
        defer {
            activeTasks.removeValue(forKey: chunkId)
            session.invalidateAndCancel()
        }
        
        // Start the task and wait for completion
        task.resume()
        try await delegate.waitForCompletion()
        
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = delegate.response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }
        
        guard httpResponse.statusCode == 206 || httpResponse.statusCode == 200 else {
            print("❌ [CHUNK] HTTP \(httpResponse.statusCode) for \(chunkId)")
            throw DownloadError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }
        
        let actualSize = delegate.bytesWritten
        let expectedSize = endByte - startByte + 1
        
        // HTTP 200 means we got the full file (not a range)
        let isFullFile = httpResponse.statusCode == 200
        
        print("✅ [ZERO-RAM] Completed \(chunkId): \(ByteCountFormatter.string(fromByteCount: actualSize, countStyle: .file)) in \(String(format: "%.2f", duration))s (HTTP \(httpResponse.statusCode))")
        
        // Only show size mismatch warning for HTTP 206 (partial content)
        if !isFullFile && actualSize < Int64(Double(expectedSize) * 0.9) {
            print("⚠️ [CHUNK] Size mismatch for \(chunkId): expected ~\(expectedSize), got \(actualSize)")
        }
        
        if let error = delegate.error {
            throw error
        }
        
        return (actualSize, isFullFile)
    }
    
    func cancelAllDownloads() {
        print("🛑 [CHUNK] Canceling all active downloads...")
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        print("✅ [CHUNK] All downloads cancelled")
    }
}