import Foundation
import Network

public final class NetworkManager: ObservableObject, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published public var isConnected = false
    @Published public var connectionType: NWInterface.InterfaceType?
    @Published public var isExpensiveConnection = false
    
    public init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                self?.isExpensiveConnection = path.isExpensive
            }
        }
        monitor.start(queue: queue)
    }
    
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    public func checkConnectivity() async -> Bool {
        return await withCheckedContinuation { continuation in
            let testURL = URL(string: "https://httpbin.org/get")!
            let task = URLSession.shared.dataTask(with: testURL) { _, response, error in
                if let httpResponse = response as? HTTPURLResponse {
                    continuation.resume(returning: httpResponse.statusCode == 200)
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