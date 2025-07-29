import Foundation

@MainActor
public class ModelDownloader: ObservableObject {
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var isModelReady: Bool = false
    @Published public var errorMessage: String?
    
    public init() {}
    
    public func downloadModel() async {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadProgress = 0.0
        errorMessage = nil
        
        do {
            // 다운로드 시뮬레이션 (10초 동안)
            for i in 1...10 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기
                downloadProgress = Double(i) / 10.0
            }
            
            isModelReady = true
            isDownloading = false
            
        } catch {
            isDownloading = false
            downloadProgress = 0.0
            errorMessage = "다운로드 실패: \(error.localizedDescription)"
        }
    }
}