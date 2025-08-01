import Foundation
import Network

enum NetworkConnectionType: String, Sendable {
    case wifi = "WiFi"
    case cellular = "Cellular" 
    case ethernet = "Ethernet"
    case none = "No Connection"
}

protocol NetworkResilienceManagerProtocol: Sendable {
    var isConnected: Bool { get async }
    var connectionType: NetworkConnectionType { get async }
    func checkConnectivity() async -> Bool
    func retryOperation<T>(_ operation: @escaping @Sendable () async throws -> T, maxRetries: Int) async throws -> T where T: Sendable
}

@MainActor
class NetworkResilienceManager: NetworkResilienceManagerProtocol, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published private var _isConnected = false
    @Published private var _connectionType: NetworkConnectionType = .none
    private var currentPath: NWPath?
    
    var isConnected: Bool {
        _isConnected
    }
    
    var connectionType: NetworkConnectionType {
        get async { _connectionType }
    }
    
    init() {
        startMonitoring()
    }
    
    private nonisolated func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                self.currentPath = path
                self._isConnected = path.status == .satisfied
                self._connectionType = self.getConnectionType(from: path)
                
                print("🔄 [NETWORK] Path updated - Connected: \(self._isConnected), Type: \(self._connectionType.rawValue)")
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(from path: NWPath) -> NetworkConnectionType {
        if path.status != .satisfied {
            return .none
        }
        
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .none
        }
    }
    
    func checkConnectivity() async -> Bool {
        print("🔍 [NETWORK] Starting simplified connectivity check...")

        // Get current connection type from path monitor
        let currentType = await connectionType
        
        if currentType != .none {
            print("✅ [NETWORK] Path monitor reports connection available: \(currentType.rawValue)")
            _isConnected = true
            return true
        } else {
            print("❌ [NETWORK] No network connection detected")
            _isConnected = false
            return false
        }
    }
    
    func retryOperation<T>(_ operation: @escaping @Sendable () async throws -> T, maxRetries: Int = 3) async throws -> T where T: Sendable {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    let delay = min(pow(2.0, Double(attempt)), 10.0) // Exponential backoff, max 10 seconds
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? DownloadError.unknown("Retry failed")
    }

    public func setConnectionType(_ type: NetworkConnectionType) {
        _connectionType = type
    }
    
    deinit {
        monitor.cancel()
    }
}