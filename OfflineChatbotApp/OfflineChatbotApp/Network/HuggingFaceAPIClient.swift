import Foundation

struct RepoFile: Codable {
    let rfilename: String
}

protocol HuggingFaceAPIClientProtocol: Sendable {
    func fetchRepoFiles(for tier: ModelTier) async throws -> [String]
}

class HuggingFaceAPIClient: HuggingFaceAPIClientProtocol, @unchecked Sendable {
    
    struct RepoInfo: Codable {
        let siblings: [RepoFile]
    }
    
    private let session: URLSession
    private let baseURL = "https://huggingface.co/api/models"
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchRepoFiles(for tier: ModelTier) async throws -> [String] {
        let urlString = "\(baseURL)/\(tier.repoId)"
        print("🌐 [API] Requesting: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [API] Invalid URL: \(urlString)")
            throw DownloadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        do {
            print("🔄 [API] Making HTTP request...")
            let (data, response) = try await session.data(for: request)
            print("✅ [API] Received response")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DownloadError.networkUnavailable
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    throw DownloadError.fileNotFound
                }
                throw DownloadError.downloadFailed("HTTP \(httpResponse.statusCode)")
            }
            
            let repoInfo = try JSONDecoder().decode(RepoInfo.self, from: data)
            return repoInfo.siblings.map { $0.rfilename }
            
        } catch {
            print("❌ [API] Request failed: \(error.localizedDescription)")
            throw error
        }
    }
}