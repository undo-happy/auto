import Foundation
import Network

public final class NetworkManager: ObservableObject, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published public var isConnected = false
    @Published public var isNetworkAvailable = false // 추가
    @Published public var connectionType: NWInterface.InterfaceType?
    @Published public var isExpensiveConnection = false
    
    public init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                guard let self else { return }
                let isConnected = await self.checkConnectivity()
                DispatchQueue.main.async {
                    self.isConnected = isConnected
                    self.isNetworkAvailable = isConnected
                    self.connectionType = path.availableInterfaces.first?.type
                    self.isExpensiveConnection = path.isExpensive
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    public func checkConnectivity() async -> Bool {
        return await withCheckedContinuation { continuation in
            var request = URLRequest(url: URL(string: "https://www.apple.com/library/test/success.html")!)
            request.timeoutInterval = 5 // 5초 타임아웃

            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error as? URLError, error.code == .notConnectedToInternet {
                    continuation.resume(returning: false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
            task.resume()
        }
    }
}

public class SolarProAPIClient {
    private let baseURL = "https://api.upstage.ai/v1"
    private let apiKey: String
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func generateResponse(for prompt: String) async throws -> String {
        // TODO: Upstage Solar Pro 2 API 호출 구현
        return "Solar Pro 응답: \(prompt)"
    }
}