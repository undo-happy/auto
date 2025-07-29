import Foundation
import CryptoKit
import Combine

// MARK: - Notification Names
extension NSNotification.Name {
    static let modelDownloadStarted = NSNotification.Name("modelDownloadStarted")
    static let modelDownloadCompleted = NSNotification.Name("modelDownloadCompleted")
    static let modelDownloadFailed = NSNotification.Name("modelDownloadFailed")
}

public struct ModelMetadata: Codable {
    let modelName: String
    let modelURL: URL
    let fileSize: Int64
    let specTier: DeviceSpecService.SpecTier
    let downloadDate: Date
    let isReady: Bool
}

public final class ModelDownloader: NSObject, ObservableObject, @unchecked Sendable {
    @Published public var downloadProgress: Double = 0.0
    @Published public var isDownloading = false
    @Published public var downloadStatus: DownloadStatus = .notStarted
    @Published public var errorMessage: String?
    @Published public var deviceCapability: DeviceSpecService.DeviceCapability?
    @Published public var selectedModelTier: DeviceSpecService.SpecTier?
    @Published public var downloadSpeedMBps: Double = 0.0
    @Published public var estimatedTimeRemaining: TimeInterval = 0.0
    @Published public var totalBytesDownloaded: Int64 = 0
    @Published public var totalBytesExpected: Int64 = 0
    @Published public var isRetrying: Bool = false
    @Published public var retryAttempt: Int = 0
    @Published public var retryReason: String?

    private let networkManager = NetworkManager()
    private var cancellables = Set<AnyCancellable>()

    private var chunkTasks: [URLSessionDataTask] = []
    private var downloadedChunkPaths: [Int: URL] = [:]
    private var totalChunks: Int = 0
    private let chunkDownloadQueue = DispatchQueue(label: "com.chatbot.chunkDownloadQueue", attributes: .concurrent)
    private var allChunksCompleted: (() -> Void)?
    private var completedChunkIndices: Set<Int> = []
    
    private var downloadTask: URLSessionDownloadTask?
    private var downloadStartTime: Date?
    private var lastProgressUpdate: Date?
    private var lastBytesDownloaded: Int64 = 0
    private let retryManager = DownloadRetryManager()
    private var currentRetryAttempt = 0
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        config.allowsCellularAccess = true
        config.waitsForConnectivity = false
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    public enum DownloadStatus {
        case notStarted
        case downloading
        case completed
        case failed
        case cancelled
    }
    
    public override init() {
        super.init()
        self.deviceCapability = DeviceSpecService.shared.getDeviceCapability()
        self.selectedModelTier = deviceCapability?.specTier
        setupRetryManagerBindings()
        setupNetworkMonitoring()
    }
    
    private func setupRetryManagerBindings() {
        retryManager.$isRetrying
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRetrying)
        
        retryManager.$retryAttempt
            .receive(on: DispatchQueue.main)
            .assign(to: &$retryAttempt)
        
        retryManager.$retryReason
            .receive(on: DispatchQueue.main)
            .assign(to: &$retryReason)
    }

    private func setupNetworkMonitoring() {
        networkManager.$isNetworkAvailable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAvailable in
                if !isAvailable {
                    self?.downloadStatus = .failed
                    self?.errorMessage = "네트워크 연결을 확인해주세요."
                }
            }
            .store(in: &cancellables)
    }
    
    public func downloadGemmaModel() async throws {
        guard networkManager.isNetworkAvailable else {
            await handleFailure(error: DownloadError.networkUnavailable)
            return
        }
        currentRetryAttempt = 0
        await startChunkedDownload()
    }
    
    
    
    private func startChunkedDownload() async {
        await MainActor.run {
            isDownloading = true
            downloadStatus = .downloading
            downloadProgress = 0.0
            errorMessage = nil
            downloadSpeedMBps = 0.0
            estimatedTimeRemaining = 0.0
            totalBytesDownloaded = 0
            totalBytesExpected = 0
            downloadedChunkPaths.removeAll()
            chunkTasks.removeAll()
        }

        NotificationCenter.default.post(name: .modelDownloadStarted, object: nil)
        downloadStartTime = Date()

        guard let deviceCapability = deviceCapability,
              let modelURL = URL(string: deviceCapability.recommendedModelURL) else {
            await handleFailure(error: DownloadError.invalidURL)
            return
        }

        do {
            let totalSize = try await getFileSize(for: modelURL)
            await MainActor.run {
                self.totalBytesExpected = totalSize
            }

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let modelName = "gemma-\(selectedModelTier?.description ?? "default")"
            let modelPath = documentsPath.appendingPathComponent("Models/\(modelName)")
            try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)
            
            let destinationURL = modelPath.appendingPathComponent("\(modelName).npz")

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                do {
                    if try await verifyModelIntegrity(at: destinationURL) {
                        await MainActor.run {
                            self.downloadStatus = .completed
                            self.isDownloading = false
                            self.totalBytesDownloaded = self.totalBytesExpected
                            self.downloadProgress = 1.0
                        }
                        NotificationCenter.default.post(name: .modelDownloadCompleted, object: destinationURL)
                        return
                    }
                } catch {
                    // Verification failed, proceed with download
                    try? FileManager.default.removeItem(at: destinationURL)
                }
            }

            try await checkAvailableSpace(for: destinationURL)

            let chunkSize = 25 * 1024 * 1024 // 25MB
            totalChunks = Int(ceil(Double(totalSize) / Double(chunkSize)))
            
            for i in 0..<totalChunks {
                let rangeStart = i * chunkSize
                let rangeEnd = min((i + 1) * chunkSize - 1, Int(totalSize) - 1)
                downloadChunk(url: modelURL, chunkIndex: i, range: "bytes=\(rangeStart)-\(rangeEnd)")
            }

            allChunksCompleted = {
                Task {
                    await self.mergeChunks()
                }
            }

        } catch {
            await handleFailure(error: error)
        }
    }

    private func getFileSize(for url: URL) async throws -> Int64 {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              let contentLength = httpResponse.allHeaderFields["Content-Length"] as? String,
              let size = Int64(contentLength) else {
            throw DownloadError.storageCheckFailed // Or a more specific error
        }
        return size
    }

    private func downloadChunk(url: URL, chunkIndex: Int, range: String) {
        var request = URLRequest(url: url)
        request.setValue(range, forHTTPHeaderField: "Range")
        let task = urlSession.dataTask(with: request)
        task.taskDescription = "\(chunkIndex)"
        chunkTasks.append(task)
        task.resume()
    }

    private func handleFailure(error: Error) async {
        chunkTasks.forEach { $0.cancel() }
        cleanupTempFiles()
        await MainActor.run {
            self.downloadStatus = .failed
            self.isDownloading = false
            self.errorMessage = error.localizedDescription
        }
        NotificationCenter.default.post(name: .modelDownloadFailed, object: error)
    }

    private func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        for i in 0..<totalChunks {
            let chunkURL = tempDir.appendingPathComponent("chunk_\(i).part")
            if FileManager.default.fileExists(atPath: chunkURL.path) {
                try? FileManager.default.removeItem(at: chunkURL)
            }
        }
    }

    private func mergeChunks() async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelName = "gemma-\(selectedModelTier?.description ?? "default")"
        let modelPath = documentsPath.appendingPathComponent("Models/\(modelName)")
        let destinationURL = modelPath.appendingPathComponent("\(modelName).npz")

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            FileManager.default.createFile(atPath: destinationURL.path, contents: nil, attributes: nil)
            let fileHandle = try FileHandle(forWritingTo: destinationURL)

            for i in 0..<totalChunks {
                guard let chunkURL = downloadedChunkPaths[i] else {
                    // Handle missing chunk error
                    throw DownloadError.downloadInterrupted
                }
                let chunkData = try Data(contentsOf: chunkURL)
                fileHandle.write(chunkData)
                try FileManager.default.removeItem(at: chunkURL)
            }

            fileHandle.closeFile()

            // Finalize download
            await MainActor.run {
                self.downloadStatus = .completed
                self.isDownloading = false
            }
            NotificationCenter.default.post(name: .modelDownloadCompleted, object: destinationURL)
            await saveModelMetadata(for: destinationURL)

        } catch {
            await handleFailure(error: error)
        }
    }

    private var downloadCompletionHandler: ((Result<URL, Error>) -> Void)?
    
    private func handleDownloadFailure(error: Error, destinationURL: URL) async throws {
        let retryReason = retryManager.classifyError(error)
        
        // 실패한 다운로드 정리
        DownloadRecoveryService.cleanupFailedDownload(at: destinationURL)
        
        // 재시도 가능한지 확인
        if retryManager.shouldRetry(for: retryReason, attempt: currentRetryAttempt) {
            // 재시도 스케줄링
            await scheduleRetry(reason: retryReason)
        } else {
            // 최대 재시도 횟수 초과 - 최종 실패
            await MainActor.run {
                self.downloadStatus = .failed
                self.isDownloading = false
                self.errorMessage = "다운로드 실패: \(retryReason.description) (최대 재시도 횟수 초과)"
            }
            
            NotificationCenter.default.post(name: .modelDownloadFailed, object: error)
            throw error
        }
    }
    
    private func scheduleRetry(reason: DownloadRetryManager.RetryReason) async {
        await MainActor.run {
            self.downloadStatus = .failed
            self.isDownloading = false
        }
        
        return await withCheckedContinuation { continuation in
            retryManager.scheduleRetry(for: reason, attempt: currentRetryAttempt) {
                Task {
                    self.currentRetryAttempt += 1
                    do {
                        try await self.performDownloadWithRetry()
                        continuation.resume()
                    } catch {
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    public func getDownloadedModelMetadata() -> ModelMetadata? {
        guard deviceCapability != nil,
              let tier = selectedModelTier else { return nil }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelName = "gemma-\(tier.description)"
        let modelFileName = "\(modelName).npz"
        let modelURL = documentsPath.appendingPathComponent("Models/\(modelName)/\(modelFileName)")
        
        guard FileManager.default.fileExists(atPath: modelURL.path) else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: modelURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let creationDate = attributes[.creationDate] as? Date ?? Date()
            
            return ModelMetadata(
                modelName: "Gemma-\(tier.description)",
                modelURL: modelURL,
                fileSize: fileSize,
                specTier: tier,
                downloadDate: creationDate,
                isReady: true
            )
        } catch {
            return nil
        }
    }
    
    private func saveModelMetadata(for modelURL: URL) async {
        guard let tier = selectedModelTier else { return }
        
        let metadata = ModelMetadata(
            modelName: "Gemma-\(tier.description)",
            modelURL: modelURL,
            fileSize: deviceCapability?.estimatedModelSize ?? 0,
            specTier: tier,
            downloadDate: Date(),
            isReady: true
        )
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelName = "gemma-\(tier.description)"
        let metadataURL = documentsPath.appendingPathComponent("Models/\(modelName)/model_metadata.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)
            try data.write(to: metadataURL)
        } catch {
            print("Failed to save model metadata: \(error)")
        }
    }
    
    public func isModelReadyForLoading() -> Bool {
        return getDownloadedModelMetadata()?.isReady ?? false
    }
    
    public func getModelPath() -> URL? {
        return getDownloadedModelMetadata()?.modelURL
    }
    
    public func cancelDownload() {
        chunkDownloadQueue.async(flags: .barrier) {
            self.chunkTasks.forEach { $0.cancel() }
            self.chunkTasks.removeAll()
        }
        retryManager.cancelRetry()
        cleanupTempFiles()
        DispatchQueue.main.async {
            self.downloadStatus = .cancelled
            self.isDownloading = false
        }
    }
    
    private func checkAvailableSpace(for url: URL) async throws {
        let resourceValues = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let availableCapacity = resourceValues.volumeAvailableCapacityForImportantUsage else {
            throw DownloadError.storageCheckFailed
        }
        
        let requiredSpace = deviceCapability?.estimatedModelSize ?? 2_000_000_000
        if availableCapacity < requiredSpace {
            throw DownloadError.insufficientStorage
        }
    }
    
    private func verifyModelIntegrity(at url: URL) async throws -> Bool {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // 실제 환경에서는 서버에서 제공하는 체크섬과 비교
        // let expectedHash = "expected_model_hash_here"
        // return hashString == expectedHash
        return true
    }
}

extension ModelDownloader: URLSessionDataDelegate {
    
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let taskDescription = dataTask.taskDescription, let chunkIndex = Int(taskDescription) else { return }

        let receivedDataCount = Int64(data.count)

        chunkDownloadQueue.async(flags: .barrier) {
            let tempDir = FileManager.default.temporaryDirectory
            let chunkURL = tempDir.appendingPathComponent("chunk_\(chunkIndex).part")
            
            do {
                if FileManager.default.fileExists(atPath: chunkURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: chunkURL)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } else {
                    try data.write(to: chunkURL)
                }
                // Only add the path if the write was successful
                self.downloadedChunkPaths[chunkIndex] = chunkURL
            } catch {
                Task { await self.handleFailure(error: error) }
            }
        }
        
        DispatchQueue.main.async {
            self.totalBytesDownloaded += receivedDataCount
            self.downloadProgress = self.totalBytesExpected > 0 ? Double(self.totalBytesDownloaded) / Double(self.totalBytesExpected) : 0

            let now = Date()
            if let lastUpdate = self.lastProgressUpdate, let startTime = self.downloadStartTime {
                let timeInterval = now.timeIntervalSince(lastUpdate)
                if timeInterval > 0.5 { // Update every 0.5 seconds
                    let bytesInInterval = self.totalBytesDownloaded - self.lastBytesDownloaded
                    let speedBytesPerSecond = Double(bytesInInterval) / timeInterval
                    self.downloadSpeedMBps = speedBytesPerSecond / (1024 * 1024)
                    
                    let remainingBytes = self.totalBytesExpected - self.totalBytesDownloaded
                    self.estimatedTimeRemaining = speedBytesPerSecond > 0 ? TimeInterval(Double(remainingBytes) / speedBytesPerSecond) : .infinity
                    
                    self.lastBytesDownloaded = self.totalBytesDownloaded
                    self.lastProgressUpdate = now
                }
            } else {
                self.lastProgressUpdate = now
                self.downloadStartTime = now
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskDescription = task.taskDescription, let chunkIndex = Int(taskDescription) else { return }

        if let error = error {
            // Don't treat cancellation as a failure
            guard (error as NSError).code != NSURLErrorCancelled else { return }

            let retryReason = retryManager.classifyError(error)
            if retryManager.shouldRetry(for: retryReason, attempt: currentRetryAttempt) {
                let delay = retryManager.getDelay(for: retryReason, attempt: currentRetryAttempt)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.currentRetryAttempt += 1
                    guard let url = task.originalRequest?.url, let range = task.originalRequest?.value(forHTTPHeaderField: "Range") else { return }
                    self.downloadChunk(url: url, chunkIndex: chunkIndex, range: range)
                }
            } else {
                Task { await self.handleFailure(error: error) }
            }
            return
        }

        chunkDownloadQueue.async(flags: .barrier) {
            self.completedChunkIndices.insert(chunkIndex)
            if self.completedChunkIndices.count == self.totalChunks {
                self.allChunksCompleted?()
            }
        }
    }
}

public enum DownloadError: LocalizedError {
    case invalidURL
    case insufficientStorage
    case storageCheckFailed
    case integrityCheckFailed
    case networkUnavailable
    case downloadInterrupted
    case unsupportedDevice
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "유효하지 않은 모델 URL입니다."
        case .insufficientStorage:
            return "저장 공간이 부족합니다. 최소 2GB가 필요합니다."
        case .storageCheckFailed:
            return "저장 공간 확인에 실패했습니다."
        case .integrityCheckFailed:
            return "다운로드된 모델 파일의 무결성 검증에 실패했습니다."
        case .networkUnavailable:
            return "네트워크 연결을 확인해주세요."
        case .downloadInterrupted:
            return "다운로드가 중단되었습니다. 다시 시도해주세요."
        case .unsupportedDevice:
            return "현재 디바이스에서 지원되지 않는 모델입니다."
        }
    }
}