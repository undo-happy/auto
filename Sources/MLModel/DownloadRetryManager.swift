import Foundation
import Network

public final class DownloadRetryManager: ObservableObject, @unchecked Sendable {
    @Published public var isRetrying: Bool = false
    @Published public var retryAttempt: Int = 0
    @Published public var nextRetryTime: Date?
    @Published public var retryReason: String?
    
    private let maxRetryAttempts = 5
    private let baseRetryInterval: TimeInterval = 2.0 // 2초
    private let maxRetryInterval: TimeInterval = 60.0 // 60초
    
    private var retryTimer: Timer?
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = true
    
    public enum RetryReason: Sendable {
        case networkError
        case serverError
        case diskError
        case corruptedFile
        case timeout
        case unknown
        
        var description: String {
            switch self {
            case .networkError:
                return "네트워크 연결 오류"
            case .serverError:
                return "서버 오류"
            case .diskError:
                return "저장 공간 오류"
            case .corruptedFile:
                return "파일 손상"
            case .timeout:
                return "다운로드 시간 초과"
            case .unknown:
                return "알 수 없는 오류"
            }
        }
    }
    
    public init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { [weak self] in
                self?.isNetworkAvailable = (path.status == .satisfied)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    public func classifyError(_ error: Error) -> RetryReason {
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed:
                return .networkError
                
            case NSURLErrorTimedOut:
                return .timeout
                
            case NSURLErrorBadServerResponse,
                 500...599:
                return .serverError
                
            default:
                return .unknown
            }
            
        case NSCocoaErrorDomain:
            switch nsError.code {
            case NSFileWriteOutOfSpaceError,
                 NSFileWriteVolumeReadOnlyError:
                return .diskError
                
            case NSFileReadCorruptFileError,
                 NSFileReadNoSuchFileError:
                return .corruptedFile
                
            default:
                return .unknown
            }
            
        default:
            return .unknown
        }
    }
    
    public func shouldRetry(for reason: RetryReason, attempt: Int) -> Bool {
        guard attempt < maxRetryAttempts else { return false }
        
        switch reason {
        case .networkError:
            return isNetworkAvailable
        case .serverError, .timeout:
            return true
        case .diskError, .corruptedFile:
            return attempt < 2 // 디스크/파일 오류는 2회만 재시도
        case .unknown:
            return attempt < 3
        }
    }
    
    public func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        let exponentialDelay = baseRetryInterval * pow(2.0, Double(attempt))
        let jitteredDelay = exponentialDelay + Double.random(in: 0...1.0) // 지터 추가
        return min(jitteredDelay, maxRetryInterval)
    }
    
    public func scheduleRetry(
        for reason: RetryReason,
        attempt: Int,
        retryAction: @escaping @Sendable () -> Void
    ) {
        guard shouldRetry(for: reason, attempt: attempt) else {
            DispatchQueue.main.async {
                self.isRetrying = false
                self.retryAttempt = 0
                self.nextRetryTime = nil
                self.retryReason = nil
            }
            return
        }
        
        let delay = calculateBackoffDelay(attempt: attempt)
        let nextRetryDate = Date().addingTimeInterval(delay)
        
        DispatchQueue.main.async {
            self.isRetrying = true
            self.retryAttempt = attempt + 1
            self.nextRetryTime = nextRetryDate
            self.retryReason = reason.description
        }
        
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.retryTimer = nil
                retryAction()
            }
        }
    }
    
    public func cancelRetry() {
        retryTimer?.invalidate()
        retryTimer = nil
        
        DispatchQueue.main.async {
            self.isRetrying = false
            self.retryAttempt = 0
            self.nextRetryTime = nil
            self.retryReason = nil
        }
    }
    
    public func getTimeUntilNextRetry() -> TimeInterval? {
        guard let nextRetryTime = nextRetryTime else { return nil }
        let remaining = nextRetryTime.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }
    
    deinit {
        networkMonitor.cancel()
        retryTimer?.invalidate()
    }
}

// 다운로드 실패 복구 유틸리티
public class DownloadRecoveryService {
    
    public static func cleanupFailedDownload(at url: URL) {
        do {
            // 부분 다운로드 파일 삭제
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            
            // 임시 파일 삭제
            let tempURL = url.appendingPathExtension("tmp")
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            
            // 메타데이터 파일 삭제
            let metadataURL = url.deletingLastPathComponent().appendingPathComponent("model_metadata.json")
            if FileManager.default.fileExists(atPath: metadataURL.path) {
                try FileManager.default.removeItem(at: metadataURL)
            }
            
        } catch {
            print("Failed to cleanup failed download: \(error)")
        }
    }
    
    public static func validateDownloadedFile(at url: URL, expectedSize: Int64? = nil) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // 파일 크기 검증
            if let expectedSize = expectedSize, fileSize != expectedSize {
                return false
            }
            
            // 최소 크기 검증 (100KB)
            if fileSize < 100_000 {
                return false
            }
            
            // 파일 읽기 테스트
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return data.count > 0
            
        } catch {
            return false
        }
    }
}