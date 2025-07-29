import SwiftUI
import Combine
import Foundation
import Network
import SystemConfiguration
import CryptoKit
import UIKit
import Darwin

enum ModelTier: String, CaseIterable, Sendable {
    case low = "저사양"
    case medium = "중사양" 
    case high = "고사양"
    
    var repoId: String {
        switch self {
        case .high:
            return "mlx-community/gemma-3n-E4B-it-bf16"
        case .medium:
            return "mlx-community/gemma-3n-E2B-it-bf16"
        case .low:
            return "mlx-community/gemma-3n-E2B-it-4bit"
        }
    }
    
    var mainFileUrl: String {
        switch self {
        case .high:
            return "https://huggingface.co/mlx-community/gemma-3n-E4B-it-bf16/resolve/main/model.safetensors"
        case .medium:
            return "https://huggingface.co/mlx-community/gemma-3n-E2B-it-bf16/resolve/main/model.safetensors"
        case .low:
            return "https://huggingface.co/mlx-community/gemma-3n-E2B-it-4bit/resolve/main/model.safetensors"
        }
    }
    
    var configFileUrl: String {
        switch self {
        case .high:
            return "https://huggingface.co/mlx-community/gemma-3n-E4B-it-bf16/resolve/main/config.json"
        case .medium:
            return "https://huggingface.co/mlx-community/gemma-3n-E2B-it-bf16/resolve/main/config.json"
        case .low:
            return "https://huggingface.co/mlx-community/gemma-3n-E2B-it-4bit/resolve/main/config.json"
        }
    }
    
    var tokenizerFileUrl: String {
        switch self {
        case .high:
            return "https://huggingface.co/mlx-community/gemma-3n-E4B-it-bf16/resolve/main/tokenizer.json"
        case .medium:
            return "https://huggingface.co/mlx-community/gemma-3n-E2B-it-bf16/resolve/main/tokenizer.json"
        case .low:
            return "https://huggingface.co/mlx-community/gemma-3n-E2B-it-4bit/resolve/main/tokenizer.json"
        }
    }
    
    var description: String {
        switch self {
        case .high:
            return "고성능 기기용 (8GB+ RAM)"
        case .medium:
            return "중급 기기용 (4-8GB RAM)"
        case .low:
            return "저사양 기기용 (4GB 이하 RAM)"
        }
    }
    
    var folderName: String {
        return repoId.replacingOccurrences(of: "/", with: "_")
    }
}

// MARK: - Network Monitor
@MainActor
class NetworkMonitor: ObservableObject {
    @Published var isConnected = false
    @Published var isWiFi = false
    @Published var isCellular = false
    @Published var isExpensive = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                self.isConnected = path.status == .satisfied
                self.isWiFi = path.usesInterfaceType(.wifi)
                self.isCellular = path.usesInterfaceType(.cellular)
                self.isExpensive = path.isExpensive
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
        print("NetworkMonitor deinit - 메모리 해제 완료")
    }
}

// MARK: - App Bundle Storage Manager
class AppBundleStorageManager {
    static func getModelsDirectory() -> URL? {
        // 앱 Documents 폴더 하위에 AppModels 폴더 생성 (앱 트리처럼 구조화) - 안전성 강화
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Documents directory not found")
            return nil
        }
        
        // Documents 디렉토리 접근 가능성 확인
        guard FileManager.default.fileExists(atPath: documentsPath.path) else {
            print("❌ Documents directory does not exist: \(documentsPath.path)")
            return nil
        }
        
        let modelsPath = documentsPath.appendingPathComponent("AppModels")
        
        // Create models directory if it doesn't exist - 개선된 에러 처리
        do {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: modelsPath.path, isDirectory: &isDirectory)
            
            if exists {
                // 파일이 존재하지만 디렉토리가 아닌 경우
                if !isDirectory.boolValue {
                    print("⚠️ Models path exists but is not a directory, removing: \(modelsPath.path)")
                    try FileManager.default.removeItem(at: modelsPath)
                    try FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true, attributes: nil)
                    print("✅ Recreated app models directory at: \(modelsPath.path)")
                }
            } else {
                try FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created app models directory at: \(modelsPath.path)")
            }
            
            // 디렉토리 쓰기 권한 확인
            guard FileManager.default.isWritableFile(atPath: modelsPath.path) else {
                print("❌ Models directory is not writable: \(modelsPath.path)")
                return nil
            }
            
            return modelsPath
        } catch {
            print("❌ Failed to create app models directory: \(error)")
            return nil
        }
    }
    
    static func getAvailableSpace() -> Int64? {
        guard let modelsPath = getModelsDirectory() else {
            print("❌ Cannot get models directory for space check")
            return nil
        }
        
        do {
            // 여러 방법으로 사용 가능한 공간 확인
            let resourceValues = try modelsPath.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
                .volumeTotalCapacityKey
            ])
            
            // 우선순위: ImportantUsage > Available > 계산된 값
            if let importantUsageCapacity = resourceValues.volumeAvailableCapacityForImportantUsage {
                return max(0, Int64(importantUsageCapacity))
            } else if let availableCapacity = resourceValues.volumeAvailableCapacity {
                return max(0, Int64(availableCapacity))
            } else if let totalCapacity = resourceValues.volumeTotalCapacity {
                // 최대 80%를 사용 가능한 것으로 가정
                return max(0, Int64(totalCapacity) * 8 / 10)
            }
            
            print("⚠️ No capacity information available")
            return nil
        } catch {
            print("❌ Available space check failed: \(error)")
            return nil
        }
    }
    
    static func hasEnoughSpace(requiredBytes: Int64) -> Bool {
        guard requiredBytes > 0 else { return true } // 0 바이트는 항상 가능
        
        guard let availableSpace = getAvailableSpace() else { 
            print("⚠️ Cannot determine available space, assuming insufficient")
            return false 
        }
        
        // 20% 마진을 두고 계산 (기존 10%에서 증가)
        let requiredWithMargin = requiredBytes + (requiredBytes / 5) // 20% 추가
        let hasSpace = availableSpace > requiredWithMargin
        
        print("💾 Space check: Required=\(formatBytesStatic(requiredBytes)), Available=\(formatBytesStatic(availableSpace)), WithMargin=\(formatBytesStatic(requiredWithMargin)), HasSpace=\(hasSpace)")
        
        return hasSpace
    }
    
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // nonisolated 버전
    nonisolated static func formatBytesStatic(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Timeout Helper
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw DownloadError.timeoutError
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - File Size Checker (Completely Rewritten for Hugging Face)
@MainActor
class FileSizeChecker {
    
    /// 단일 파일의 실제 크기를 가져오는 메서드 - Hugging Face 최적화
    static func getActualFileSize(from url: String) async throws -> Int64 {
        guard let fileURL = URL(string: url) else {
            throw DownloadError.invalidURL(url)
        }
        
        // Production-ready URLRequest 설정
        var request = URLRequest(url: fileURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 30.0  // 합리적인 타임아웃
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Hugging Face 서버 호환 헤더 설정
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        print("🔍 [FileSizeChecker] HEAD 요청 시작: \(url)")
        print("📋 [FileSizeChecker] Request Headers:")
        request.allHTTPHeaderFields?.forEach { key, value in
            print("  - \(key): \(value)")
        }
        
        // URLSession 설정 최적화
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = false  // 무한 대기 방지
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [FileSizeChecker] Invalid response type")
                throw DownloadError.invalidResponse
            }
            
            print("📊 [FileSizeChecker] Response Status: \(httpResponse.statusCode)")
            print("📋 [FileSizeChecker] Response Headers (Total: \(httpResponse.allHeaderFields.count)):")
            
            // 모든 응답 헤더 출력 (디버깅용)
            for (key, value) in httpResponse.allHeaderFields {
                print("  - \(key): \(value)")
            }
            
            // HTTP 상태 코드 검증 - 200, 302, 301 모두 허용
            guard [200, 301, 302].contains(httpResponse.statusCode) else {
                print("❌ [FileSizeChecker] HTTP Error: \(httpResponse.statusCode)")
                throw DownloadError.httpError(httpResponse.statusCode)
            }
            
            // Hugging Face 특화 헤더 파싱 (여러 변형 지원)
            let fileSize = try parseFileSizeFromHeaders(httpResponse.allHeaderFields, url: url)
            
            print("✅ [FileSizeChecker] 파일 크기 확인 성공: \(AppBundleStorageManager.formatBytes(fileSize))")
            return fileSize
            
        } catch let error as DownloadError {
            print("❌ [FileSizeChecker] DownloadError: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ [FileSizeChecker] Unexpected error: \(error)")
            throw DownloadError.invalidResponse
        }
    }
    
    /// HTTP 응답 헤더에서 파일 크기를 파싱하는 메서드 - 안전성 개선
    private static func parseFileSizeFromHeaders(_ headers: [AnyHashable: Any], url: String) throws -> Int64 {
        
        // 1. Hugging Face의 x-linked-size 헤더 확인 (모든 대소문자 변형)
        let linkedSizeKeys = ["x-linked-size", "X-Linked-Size", "X-LINKED-SIZE", "x-Linked-Size"]
        for key in linkedSizeKeys {
            if let sizeString = headers[key] as? String {
                let trimmedString = sizeString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedString.isEmpty, let fileSize = Int64(trimmedString), fileSize > 0 else {
                    print("⚠️ [FileSizeChecker] Invalid size in \(key): '\(sizeString)'")
                    continue
                }
                print("✅ [FileSizeChecker] Found file size via \(key): \(fileSize)")
                return fileSize
            }
        }
        
        // 2. 표준 Content-Length 헤더 확인 (모든 대소문자 변형)
        let contentLengthKeys = ["Content-Length", "content-length", "CONTENT-LENGTH", "Content-length"]
        for key in contentLengthKeys {
            if let sizeString = headers[key] as? String {
                let trimmedString = sizeString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedString.isEmpty, let fileSize = Int64(trimmedString), fileSize > 0 else {
                    print("⚠️ [FileSizeChecker] Invalid size in \(key): '\(sizeString)'")
                    continue
                }
                print("✅ [FileSizeChecker] Found file size via \(key): \(fileSize)")
                return fileSize
            }
        }
        
        // 3. Accept-Ranges 헤더 확인 (일부 서버에서 사용)
        if let acceptRanges = headers["Accept-Ranges"] as? String {
            print("📋 [FileSizeChecker] Accept-Ranges: \(acceptRanges)")
        }
        
        // 4. Content-Range 헤더 확인 (일부 경우에 포함될 수 있음)
        if let contentRange = headers["Content-Range"] as? String {
            print("📋 [FileSizeChecker] Content-Range: \(contentRange)")
            // Content-Range: bytes 0-1023/4096 형식에서 전체 크기 추출
            let components = contentRange.split(separator: "/")
            if components.count >= 2,
               let totalSizeString = components.last,
               let totalSize = Int64(String(totalSizeString)), totalSize > 0 {
                print("✅ [FileSizeChecker] Found file size via Content-Range: \(totalSize)")
                return totalSize
            } else {
                print("⚠️ [FileSizeChecker] Invalid Content-Range format: \(contentRange)")
            }
        }
        
        // 5. ETag에서 크기 정보 추출 시도 (일부 CDN에서 사용)
        if let etag = headers["ETag"] as? String {
            print("📋 [FileSizeChecker] ETag: \(etag)")
        }
        
        // 6. Last-Modified 정보 확인
        if let lastModified = headers["Last-Modified"] as? String {
            print("📋 [FileSizeChecker] Last-Modified: \(lastModified)")
        }
        
        // 7. 리다이렉트 정보 확인
        if let location = headers["Location"] as? String {
            print("📋 [FileSizeChecker] Redirect Location: \(location)")
        }
        
        // 모든 방법이 실패한 경우 상세한 에러 정보 제공
        print("❌ [FileSizeChecker] 파일 크기를 찾을 수 없음")
        print("📋 [FileSizeChecker] 확인한 헤더 키들:")
        for (key, value) in headers {
            print("  - \(key) (\(type(of: key))): \(value) (\(type(of: value)))")
        }
        
        throw DownloadError.fileSizeNotAvailable
    }
    
    /// 여러 파일의 크기를 병렬로 가져오는 메서드
    static func getFileSizesBatch(urls: [String]) async throws -> [String: Int64] {
        guard !urls.isEmpty else {
            return [:]
        }
        
        print("🔄 [FileSizeChecker] Batch size check started for \(urls.count) files")
        
        var results: [String: Int64] = [:]
        var errors: [String: Error] = [:]
        
        // 병렬 처리로 성능 최적화 - 타임아웃 추가
        await withTaskGroup(of: (String, Result<Int64, Error>).self) { group in
            for url in urls {
                group.addTask {
                    do {
                        // 개별 작업에 타임아웃 적용
                        let size = try await withTimeout(seconds: 45) {
                            try await getActualFileSize(from: url)
                        }
                        return (url, .success(size))
                    } catch {
                        return (url, .failure(error))
                    }
                }
            }
            
            // 결과 수집
            for await (url, result) in group {
                switch result {
                case .success(let size):
                    results[url] = size
                    print("✅ [FileSizeChecker] Success for \(URL(string: url)?.lastPathComponent ?? url): \(AppBundleStorageManager.formatBytes(size))")
                case .failure(let error):
                    errors[url] = error
                    print("❌ [FileSizeChecker] Failed for \(URL(string: url)?.lastPathComponent ?? url): \(error.localizedDescription)")
                }
            }
        }
        
        // 결과 요약
        print("📊 [FileSizeChecker] Batch results: \(results.count) success, \(errors.count) failed")
        
        // 일부 파일이라도 성공했으면 결과 반환
        if !results.isEmpty {
            // 실패한 파일들에 대한 경고만 출력
            if !errors.isEmpty {
                print("⚠️ [FileSizeChecker] Some files failed:")
                for (url, error) in errors {
                    print("  - \(URL(string: url)?.lastPathComponent ?? url): \(error.localizedDescription)")
                }
            }
            return results
        }
        
        // 모든 파일이 실패한 경우 첫 번째 에러를 던짐
        if let firstError = errors.values.first {
            throw firstError
        }
        
        throw DownloadError.fileSizeNotAvailable
    }
    
    /// 특정 URL에 대한 자세한 연결 진단
    static func diagnoseConnection(url: String) async {
        print("🔍 [FileSizeChecker] Connection diagnosis for: \(url)")
        
        guard let fileURL = URL(string: url) else {
            print("❌ [FileSizeChecker] Invalid URL")
            return
        }
        
        // 기본 연결 테스트
        do {
            var request = URLRequest(url: fileURL)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 30.0
            
            let start = Date()
            let (_, response) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(start)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ [FileSizeChecker] Connection successful")
                print("📊 [FileSizeChecker] Status: \(httpResponse.statusCode)")
                print("⏱️ [FileSizeChecker] Duration: \(String(format: "%.2f", duration))s")
                print("📋 [FileSizeChecker] Headers count: \(httpResponse.allHeaderFields.count)")
            }
        } catch {
            print("❌ [FileSizeChecker] Connection failed: \(error)")
        }
    }
}

// MARK: - File Integrity Checker
@MainActor
class FileIntegrityChecker {
    struct FileInfo {
        let path: URL
        let expectedSize: Int64
        let actualSize: Int64
        let checksum: String?
        let isValid: Bool
    }
    
    static func checkFileIntegrity(at path: URL, expectedSize: Int64) -> FileInfo {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return FileInfo(path: path, expectedSize: expectedSize, actualSize: 0, checksum: nil, isValid: false)
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            let actualSize = attributes[.size] as? Int64 ?? 0
            
            // 파일 크기 검증
            let sizeValid = actualSize == expectedSize
            
            // SHA256 체크섬 계산 (선택적)
            let checksum = calculateSHA256(for: path)
            
            return FileInfo(
                path: path,
                expectedSize: expectedSize,
                actualSize: actualSize,
                checksum: checksum,
                isValid: sizeValid
            )
        } catch {
            print("파일 검증 오류: \(error)")
            return FileInfo(path: path, expectedSize: expectedSize, actualSize: 0, checksum: nil, isValid: false)
        }
    }
    
    private static func calculateSHA256(for fileURL: URL) -> String? {
        do {
            let data = try Data(contentsOf: fileURL)
            let hashed = SHA256.hash(data: data)
            return hashed.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            print("체크섬 계산 실패: \(error)")
            return nil
        }
    }
    
    static func validateAllFiles(in directory: URL, expectedFiles: [String: Int64]) -> [String: FileInfo] {
        var results: [String: FileInfo] = [:]
        
        for (fileName, expectedSize) in expectedFiles {
            let filePath = directory.appendingPathComponent(fileName)
            results[fileName] = checkFileIntegrity(at: filePath, expectedSize: expectedSize)
        }
        
        return results
    }
}

// MARK: - Download State Manager (Core Data 스타일 영구 저장)
@MainActor
class DownloadStateManager {
    private static let stateFileName = "download_state.json"
    
    struct DownloadState: Codable {
        var modelTier: String
        var downloadedFiles: [String: FileDownloadState]
        var totalSize: Int64
        var completedSize: Int64
        var lastUpdateTime: Date
        var isCompleted: Bool
        
        struct FileDownloadState: Codable {
            var fileName: String
            var url: String
            var expectedSize: Int64
            var actualSize: Int64
            var isCompleted: Bool
            var checksum: String?
            var lastModified: Date
        }
    }
    
    private static func getStateFileURL() -> URL? {
        guard let modelsDir = AppBundleStorageManager.getModelsDirectory() else { return nil }
        return modelsDir.appendingPathComponent(stateFileName)
    }
    
    static func saveState(_ state: DownloadState) {
        guard let stateFileURL = getStateFileURL() else {
            print("상태 파일 경로를 가져올 수 없습니다")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: stateFileURL)
            print("다운로드 상태 저장 완료: \(stateFileURL.path)")
        } catch {
            print("다운로드 상태 저장 실패: \(error)")
        }
    }
    
    static func loadState() -> DownloadState? {
        guard let stateFileURL = getStateFileURL(),
              FileManager.default.fileExists(atPath: stateFileURL.path) else {
            print("저장된 다운로드 상태가 없습니다")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: stateFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(DownloadState.self, from: data)
            print("다운로드 상태 로드 완료")
            return state
        } catch {
            print("다운로드 상태 로드 실패: \(error)")
            return nil
        }
    }
    
    static func clearState() {
        guard let stateFileURL = getStateFileURL(),
              FileManager.default.fileExists(atPath: stateFileURL.path) else {
            return
        }
        
        do {
            try FileManager.default.removeItem(at: stateFileURL)
            print("다운로드 상태 삭제 완료")
        } catch {
            print("다운로드 상태 삭제 실패: \(error)")
        }
    }
}

// MARK: - Download Errors (Production Ready)
enum DownloadError: LocalizedError, Equatable {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case fileSizeNotAvailable
    case fileIntegrityCheckFailed(String)
    case insufficientStorage(required: Int64, available: Int64)
    case duplicateDownload(String)
    case networkUnavailable
    case timeoutError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "잘못된 URL: \(url)"
        case .invalidResponse:
            return "서버 응답이 유효하지 않습니다"
        case .httpError(let code):
            return "HTTP 오류 (코드: \(code))"
        case .fileSizeNotAvailable:
            return "파일 크기 정보를 가져올 수 없습니다"
        case .fileIntegrityCheckFailed(let fileName):
            return "파일 무결성 검증 실패: \(fileName)"
        case .insufficientStorage(let required, let available):
            return "저장 공간 부족 (필요: \(AppBundleStorageManager.formatBytesStatic(required)), 사용 가능: \(AppBundleStorageManager.formatBytesStatic(available)))"
        case .duplicateDownload(let fileName):
            return "이미 다운로드된 파일: \(fileName)"
        case .networkUnavailable:
            return "네트워크에 연결되지 않았습니다"
        case .timeoutError:
            return "요청 시간이 초과되었습니다"
        }
    }
    
    // Recovery suggestions for production apps
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "WiFi 연결을 확인하고 다시 시도해주세요."
        case .insufficientStorage:
            return "기기의 저장 공간을 확보한 후 다시 시도해주세요."
        case .httpError(let code) where code >= 500:
            return "서버 문제입니다. 잠시 후 다시 시도해주세요."
        case .httpError(let code) where code == 404:
            return "요청한 파일을 찾을 수 없습니다. 앱을 업데이트해주세요."
        default:
            return "다시 시도하거나 앱을 재시작해주세요."
        }
    }
}

// MARK: - Download Status
enum DownloadFileStatus: Equatable {
    case pending
    case downloading(progress: Double)
    case completed
    case failed(error: String)
    case paused
}

// MARK: - Chunk-Based Download System

struct ChunkInfo: Equatable, Codable {
    let id: String
    let fileUrl: String
    let fileName: String
    let startByte: Int64
    let endByte: Int64
    var isCompleted: Bool = false
    var downloadedBytes: Int64 = 0
    var data: Data?
    var retryCount: Int = 0
    var lastError: String?
    var startTime: Date?
    var completionTime: Date?
    
    // Codable을 위한 커스텀 구현 - Data는 포함하지 않음
    enum CodingKeys: String, CodingKey {
        case id, fileUrl, fileName, startByte, endByte
        case isCompleted, downloadedBytes, retryCount
        case lastError, startTime, completionTime
    }
    
    var size: Int64 {
        return endByte - startByte + 1
    }
    
    var progress: Double {
        guard size > 0 else { return 0.0 }
        return Double(downloadedBytes) / Double(size)
    }
    
    var isInProgress: Bool {
        return downloadedBytes > 0 && !isCompleted
    }
    
    // Equatable 구현
    static func == (lhs: ChunkInfo, rhs: ChunkInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

struct FileChunkInfo: Equatable, Codable {
    let url: String
    let fileName: String
    let totalSize: Int64
    var chunks: [ChunkInfo] = []
    var isCompleted: Bool = false
    var mergedFilePath: String?
    var retryCount: Int = 0
    
    var completedChunks: Int {
        return chunks.filter { $0.isCompleted }.count
    }
    
    var totalChunks: Int {
        return chunks.count
    }
    
    var downloadedBytes: Int64 {
        return chunks.reduce(0) { $0 + $1.downloadedBytes }
    }
    
    var progress: Double {
        guard totalSize > 0 else { return 0.0 }
        return Double(downloadedBytes) / Double(totalSize)
    }
    
    var isAllChunksCompleted: Bool {
        return !chunks.isEmpty && chunks.allSatisfy { $0.isCompleted }
    }
    
    // Equatable 구현
    static func == (lhs: FileChunkInfo, rhs: FileChunkInfo) -> Bool {
        return lhs.url == rhs.url
    }
}

struct DownloadFileInfo: Equatable {
    let url: String
    let fileName: String
    var status: DownloadFileStatus = .pending
    var downloadedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var resumeData: Data?
    var retryCount: Int = 0
    var actualFileSize: Int64 = 0 // HEAD 요청으로 확인한 실제 파일 크기
    var weight: Double = 0.0 // 전체 다운로드에서 이 파일이 차지하는 가중치
    var startTime: Date?
    var lastUpdateTime: Date?
    
    var progress: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }
    
    var isCompleted: Bool {
        return status == .completed
    }
    
    var isFailed: Bool {
        if case .failed = status {
            return true
        }
        return false
    }
    
    // Equatable 구현
    static func == (lhs: DownloadFileInfo, rhs: DownloadFileInfo) -> Bool {
        return lhs.url == rhs.url && lhs.fileName == rhs.fileName
    }
}

// MARK: - Chunk Manager
class ChunkManager {
    static let defaultChunkSize: Int64 = 10 * 1024 * 1024 // 10MB
    static let maxConcurrentChunks = 4
    
    static func createChunks(for fileUrl: String, fileName: String, totalSize: Int64, chunkSize: Int64 = defaultChunkSize) -> [ChunkInfo] {
        var chunks: [ChunkInfo] = []
        var currentPosition: Int64 = 0
        var chunkIndex = 0
        
        while currentPosition < totalSize {
            let endPosition = min(currentPosition + chunkSize - 1, totalSize - 1)
            let chunkId = "\(fileName)_chunk_\(chunkIndex)"
            
            let chunk = ChunkInfo(
                id: chunkId,
                fileUrl: fileUrl,
                fileName: fileName,
                startByte: currentPosition,
                endByte: endPosition
            )
            
            chunks.append(chunk)
            currentPosition = endPosition + 1
            chunkIndex += 1
        }
        
        print("Created \(chunks.count) chunks for \(fileName) (total size: \(AppBundleStorageManager.formatBytes(totalSize)))")
        return chunks
    }
    
    static func getOptimalChunkSize(for fileSize: Int64) -> Int64 {
        switch fileSize {
        case 0..<(50 * 1024 * 1024): // < 50MB
            return 5 * 1024 * 1024 // 5MB chunks
        case (50 * 1024 * 1024)..<(500 * 1024 * 1024): // 50MB - 500MB
            return 10 * 1024 * 1024 // 10MB chunks
        case (500 * 1024 * 1024)..<(2 * 1024 * 1024 * 1024): // 500MB - 2GB
            return 25 * 1024 * 1024 // 25MB chunks
        default: // > 2GB
            return 50 * 1024 * 1024 // 50MB chunks
        }
    }
}

// MARK: - Chunk Downloader
class ChunkDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    typealias ChunkCompletionHandler = (Result<ChunkInfo, Error>) -> Void
    typealias ChunkProgressHandler = (ChunkInfo, Double) -> Void
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 600.0
        config.httpMaximumConnectionsPerHost = ChunkManager.maxConcurrentChunks
        config.allowsCellularAccess = true  // 셀룰러 허용으로 변경
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    private var activeDownloads: [String: (task: URLSessionDataTask, chunk: ChunkInfo, data: NSMutableData, completion: ChunkCompletionHandler)] = [:]
    private let maxRetryCount = 3
    
    override init() {
        super.init()
    }
    
    func downloadChunk(_ chunk: ChunkInfo, 
                      progressHandler: ChunkProgressHandler? = nil,
                      completion: @escaping ChunkCompletionHandler) {
        
        guard let url = URL(string: chunk.fileUrl) else {
            completion(.failure(NSError(domain: "ChunkDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("bytes=\(chunk.startByte)-\(chunk.endByte)", forHTTPHeaderField: "Range")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let dataTask = urlSession.dataTask(with: request)
        
        // Store download info
        activeDownloads[chunk.id] = (
            task: dataTask,
            chunk: chunk,
            data: NSMutableData(),
            completion: completion
        )
        
        print("Starting chunk download: \(chunk.id) (\(chunk.startByte)-\(chunk.endByte))")
        dataTask.resume()
    }
    
    func cancelChunk(_ chunkId: String) {
        if let downloadInfo = activeDownloads[chunkId] {
            downloadInfo.task.cancel()
            activeDownloads.removeValue(forKey: chunkId)
            print("Cancelled chunk download: \(chunkId)")
        }
    }
    
    func cancelAllDownloads() {
        for (chunkId, downloadInfo) in activeDownloads {
            downloadInfo.task.cancel()
            print("Cancelled chunk download: \(chunkId)")
        }
        activeDownloads.removeAll()
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunkId = findChunkId(for: dataTask),
              var downloadInfo = activeDownloads[chunkId] else {
            print("⚠️ Received data for unknown chunk")
            return
        }
        
        downloadInfo.data.append(data)
        
        var updatedChunk = downloadInfo.chunk
        updatedChunk.downloadedBytes = Int64(downloadInfo.data.length)
        updatedChunk.data = downloadInfo.data as Data
        
        // Update stored chunk - 스레드 안전성 보장
        activeDownloads[chunkId] = (
            task: downloadInfo.task,
            chunk: updatedChunk,
            data: downloadInfo.data,
            completion: downloadInfo.completion
        )
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didCompleteWithError error: Error?) {
        guard let chunkId = findChunkId(for: dataTask),
              let downloadInfo = activeDownloads[chunkId] else {
            print("⚠️ Completed unknown chunk")
            return
        }
        
        defer {
            activeDownloads.removeValue(forKey: chunkId)
        }
        
        if let error = error {
            print("Chunk download failed: \(chunkId) - \(error.localizedDescription)")
            
            var failedChunk = downloadInfo.chunk
            failedChunk.lastError = error.localizedDescription
            failedChunk.retryCount += 1
            
            downloadInfo.completion(.failure(error))
        } else {
            print("Chunk download completed: \(chunkId) - \(downloadInfo.data.length) bytes")
            
            var completedChunk = downloadInfo.chunk
            completedChunk.isCompleted = true
            completedChunk.downloadedBytes = Int64(downloadInfo.data.length)
            completedChunk.data = downloadInfo.data as Data
            completedChunk.completionTime = Date()
            
            downloadInfo.completion(.success(completedChunk))
        }
    }
    
    private func findChunkId(for task: URLSessionDataTask) -> String? {
        for (chunkId, downloadInfo) in activeDownloads {
            if downloadInfo.task == task {
                return chunkId
            }
        }
        return nil
    }
}

// MARK: - Parallel Chunk Download Manager
@MainActor
class ParallelChunkDownloadManager: ObservableObject {
    @Published var fileChunks: [FileChunkInfo] = []
    @Published var overallProgress: Double = 0.0
    @Published var downloadSpeed: Double = 0.0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var isDownloading: Bool = false
    @Published var errorMessage: String?
    
    private let chunkDownloader = ChunkDownloader()
    private var downloadStartTime: Date?
    private var totalBytesDownloaded: Int64 = 0
    private var lastProgressUpdate: Date = Date()
    private var progressUpdateInterval: TimeInterval = 0.5
    private let maxConcurrentChunks = ChunkManager.maxConcurrentChunks
    private var activeChunkCount = 0
    private let downloadQueue = DispatchQueue(label: "chunk.download.queue", qos: .userInitiated)
    
    // Temporary chunk storage
    private var tempDirectory: URL = FileManager.default.temporaryDirectory
    
    init() {
        // Create temporary directory for chunks
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chunks_\(UUID().uuidString)")
        do {
            // 기존 디렉토리가 있다면 삭제
            if FileManager.default.fileExists(atPath: tempDir.path) {
                try FileManager.default.removeItem(at: tempDir)
                print("🗑️ Removed existing temp directory: \(tempDir.path)")
            }
            
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            self.tempDirectory = tempDir
            print("✅ Created temp directory: \(tempDir.path)")
        } catch {
            print("❌ Failed to create temp directory: \(error), using fallback")
            // 폴백: 시스템 임시 디렉토리 사용
            self.tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("fallback_chunks")
            
            // 폴백 디렉토리 생성 시도
            do {
                try FileManager.default.createDirectory(at: self.tempDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created fallback temp directory: \(self.tempDirectory.path)")
            } catch {
                print("❌ Failed to create fallback temp directory: \(error)")
                // 최종 폴백: 시스템 임시 디렉토리 직접 사용
                self.tempDirectory = FileManager.default.temporaryDirectory
            }
        }
    }
    
    deinit {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    func startDownload(files: [(url: String, fileName: String, totalSize: Int64)], to destinationDirectory: URL) async {
        isDownloading = true
        errorMessage = nil
        downloadStartTime = Date()
        totalBytesDownloaded = 0
        
        // Create file chunk info for each file
        fileChunks = files.map { fileInfo in
            let chunkSize = ChunkManager.getOptimalChunkSize(for: fileInfo.totalSize)
            let chunks = ChunkManager.createChunks(
                for: fileInfo.url,
                fileName: fileInfo.fileName,
                totalSize: fileInfo.totalSize,
                chunkSize: chunkSize
            )
            
            return FileChunkInfo(
                url: fileInfo.url,
                fileName: fileInfo.fileName,
                totalSize: fileInfo.totalSize,
                chunks: chunks
            )
        }
        
        print("Starting parallel chunk download for \(files.count) files")
        
        // Start downloading chunks for all files in parallel
        await withTaskGroup(of: Void.self) { group in
            for fileIndex in fileChunks.indices {
                group.addTask {
                    await self.downloadFileChunks(fileIndex: fileIndex, destinationDirectory: destinationDirectory)
                }
            }
        }
        
        isDownloading = false
        print("All files download completed")
    }
    
    private func downloadFileChunks(fileIndex: Int, destinationDirectory: URL) async {
        guard fileIndex < fileChunks.count else { 
            print("⚠️ Invalid file index: \(fileIndex) >= \(fileChunks.count)")
            return 
        }
        
        let fileChunk = fileChunks[fileIndex]
        guard !fileChunk.chunks.isEmpty else {
            print("⚠️ No chunks available for file: \(fileChunk.fileName)")
            return
        }
        
        print("🚀 Starting chunk download for file: \(fileChunk.fileName) (\(fileChunk.chunks.count) chunks)")
        
        // Download chunks with concurrency control - 안전성 강화
        await withTaskGroup(of: Void.self) { group in
            let maxConcurrency = min(maxConcurrentChunks, fileChunk.chunks.count)
            var activeDownloads = 0
            
            for chunkIndex in fileChunk.chunks.indices {
                // 동시 실행 수 제한
                while activeDownloads >= maxConcurrency {
                    await group.next() // 완료되기를 기다림
                    activeDownloads -= 1
                }
                
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    await self.downloadSingleChunk(fileIndex: fileIndex, chunkIndex: chunkIndex)
                }
                activeDownloads += 1
            }
        }
        
        // Merge chunks once all are completed
        await mergeChunks(fileIndex: fileIndex, destinationDirectory: destinationDirectory)
    }
    
    private func downloadSingleChunk(fileIndex: Int, chunkIndex: Int) async {
        guard fileIndex < fileChunks.count,
              chunkIndex < fileChunks[fileIndex].chunks.count else { 
            print("Invalid chunk indices: fileIndex=\(fileIndex), chunkIndex=\(chunkIndex)")
            return 
        }
        
        let chunk = fileChunks[fileIndex].chunks[chunkIndex]
        
        await withCheckedContinuation { continuation in
            chunkDownloader.downloadChunk(chunk) { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { 
                        continuation.resume()
                        return 
                    }
                    
                    switch result {
                    case .success(let completedChunk):
                        // Update chunk in the array - 배열 바운드 체크
                        guard fileIndex < self.fileChunks.count && chunkIndex < self.fileChunks[fileIndex].chunks.count else {
                            print("❌ Invalid chunk indices during update: fileIndex=\(fileIndex), chunkIndex=\(chunkIndex)")
                            continuation.resume()
                            return
                        }
                        self.fileChunks[fileIndex].chunks[chunkIndex] = completedChunk
                        
                        // Save chunk data to temporary file
                        if let data = completedChunk.data {
                            self.saveChunkToTemp(data: data, fileIndex: fileIndex, chunkIndex: chunkIndex)
                        }
                        
                        self.updateProgress()
                        print("Chunk completed: \(completedChunk.id)")
                        
                    case .failure(let error):
                        print("Chunk download failed: \(chunk.id) - \(error.localizedDescription)")
                        
                        // Retry logic
                        var failedChunk = chunk
                        failedChunk.retryCount += 1
                        failedChunk.lastError = error.localizedDescription
                        
                        if failedChunk.retryCount < 3 {
                            print("Retrying chunk: \(chunk.id) (attempt \(failedChunk.retryCount + 1))")
                            self.fileChunks[fileIndex].chunks[chunkIndex] = failedChunk
                            
                            // Retry after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(failedChunk.retryCount)) {
                                Task {
                                    await self.downloadSingleChunk(fileIndex: fileIndex, chunkIndex: chunkIndex)
                                }
                            }
                        } else {
                            self.errorMessage = "Chunk download failed after retries: \(chunk.id)"
                        }
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func saveChunkToTemp(data: Data, fileIndex: Int, chunkIndex: Int) {
        let fileName = "file_\(fileIndex)_chunk_\(chunkIndex).tmp"
        let chunkFile = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: chunkFile)
        } catch {
            print("Failed to save chunk to temp: \(error)")
        }
    }
    
    private func mergeChunks(fileIndex: Int, destinationDirectory: URL) async {
        guard fileIndex < fileChunks.count else { return }
        
        let fileChunk = fileChunks[fileIndex]
        
        // Check if all chunks are completed
        guard fileChunk.isAllChunksCompleted else {
            print("Not all chunks completed for file: \(fileChunk.fileName)")
            return
        }
        
        print("Merging chunks for file: \(fileChunk.fileName)")
        
        let destinationFile = destinationDirectory.appendingPathComponent(fileChunk.fileName)
        
        do {
            // Create destination directory if needed
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationFile.path) {
                try FileManager.default.removeItem(at: destinationFile)
            }
            
            // Create empty destination file
            FileManager.default.createFile(atPath: destinationFile.path, contents: nil, attributes: nil)
            
            let fileHandle = try FileHandle(forWritingTo: destinationFile)
            defer { 
                do {
                    try fileHandle.close()
                } catch {
                    print("Warning: Failed to close file handle: \(error)")
                }
            }
            
            // Write chunks in order
            for chunkIndex in 0..<fileChunk.chunks.count {
                let chunkFileName = "file_\(fileIndex)_chunk_\(chunkIndex).tmp"
                let chunkFile = tempDirectory.appendingPathComponent(chunkFileName)
                
                if FileManager.default.fileExists(atPath: chunkFile.path) {
                    let chunkData = try Data(contentsOf: chunkFile)
                    fileHandle.write(chunkData)
                    
                    // Clean up chunk file
                    try FileManager.default.removeItem(at: chunkFile)
                } else {
                    print("Warning: Chunk file not found: \(chunkFileName)")
                }
            }
            
            // Mark file as completed
            fileChunks[fileIndex].isCompleted = true
            fileChunks[fileIndex].mergedFilePath = destinationFile.path
            
            print("File merge completed: \(fileChunk.fileName)")
            
        } catch {
            print("Failed to merge chunks for \(fileChunk.fileName): \(error)")
            errorMessage = "Failed to merge file: \(fileChunk.fileName)"
        }
    }
    
    private func updateProgress() {
        let now = Date()
        guard now.timeIntervalSince(lastProgressUpdate) >= progressUpdateInterval else { return }
        lastProgressUpdate = now
        
        // 동시성 안전성을 위한 스냅샷 사용
        let fileChunksSnapshot = fileChunks
        guard !fileChunksSnapshot.isEmpty else {
            overallProgress = 0.0
            return
        }
        
        let totalBytes = fileChunksSnapshot.reduce(Int64(0)) { result, chunk in
            let newTotal = result + chunk.totalSize
            return newTotal >= result ? newTotal : result // 오버플로우 방지
        }
        
        let downloadedBytes = fileChunksSnapshot.reduce(Int64(0)) { result, chunk in
            let newTotal = result + chunk.downloadedBytes
            return newTotal >= result ? newTotal : result // 오버플로우 방지
        }
        
        overallProgress = totalBytes > 0 ? min(1.0, Double(downloadedBytes) / Double(totalBytes)) : 0.0
        
        // Calculate download speed - 안전성 개선
        if let startTime = downloadStartTime {
            let elapsed = now.timeIntervalSince(startTime)
            if elapsed > 0.1 { // 최소 시간 제한
                let bytesDelta = max(0, downloadedBytes - totalBytesDownloaded)
                let bytesPerSecond = Double(bytesDelta) / elapsed
                downloadSpeed = max(0, bytesPerSecond) // 음수 방지
                
                // Estimate remaining time
                let remainingBytes = max(0, totalBytes - downloadedBytes)
                if bytesPerSecond > 0 && remainingBytes > 0 {
                    let estimatedTime = Double(remainingBytes) / bytesPerSecond
                    // 비현실적인 예상 시간 제한 (24시간)
                    estimatedTimeRemaining = min(estimatedTime, 24 * 3600)
                } else {
                    estimatedTimeRemaining = 0
                }
            }
        }
        
        totalBytesDownloaded = max(totalBytesDownloaded, downloadedBytes) // 역행 방지
    }
    
    func cancelDownload() {
        isDownloading = false
        chunkDownloader.cancelAllDownloads()
        
        // Clean up temp files - 안전하게 정리
        do {
            if FileManager.default.fileExists(atPath: tempDirectory.path) {
                let tempContents = try FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)
                print("🗑️ Cleaning up \(tempContents.count) temporary files")
                
                // 각 파일을 개별적으로 삭제
                for fileName in tempContents {
                    let filePath = tempDirectory.appendingPathComponent(fileName)
                    try FileManager.default.removeItem(at: filePath)
                }
                
                // 빈 디렉토리 삭제
                try FileManager.default.removeItem(at: tempDirectory)
                print("✅ Temporary directory cleaned up: \(tempDirectory.path)")
            }
        } catch {
            print("⚠️ Failed to clean up temp directory: \(error.localizedDescription)")
            // 임시 파일 정리 실패는 심각한 문제가 아님
        }
        
        print("✅ Download cancellation completed")
    }
    
    func pauseDownload() {
        isDownloading = false
        chunkDownloader.cancelAllDownloads()
        print("Download paused - chunks can be resumed")
    }
}

// MARK: - Chunk File Integrity System
class ChunkFileIntegrityVerifier {
    struct VerificationResult {
        let isValid: Bool
        let expectedSize: Int64
        let actualSize: Int64
        let errorMessage: String?
    }
    
    static func verifyMergedFile(at filePath: URL, expectedSize: Int64) -> VerificationResult {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return VerificationResult(
                isValid: false,
                expectedSize: expectedSize,
                actualSize: 0,
                errorMessage: "File does not exist"
            )
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath.path)
            let actualSize = attributes[.size] as? Int64 ?? 0
            
            let isValid = actualSize == expectedSize
            
            return VerificationResult(
                isValid: isValid,
                expectedSize: expectedSize,
                actualSize: actualSize,
                errorMessage: isValid ? nil : "Size mismatch: expected \(expectedSize), got \(actualSize)"
            )
        } catch {
            return VerificationResult(
                isValid: false,
                expectedSize: expectedSize,
                actualSize: 0,
                errorMessage: "Failed to read file attributes: \(error.localizedDescription)"
            )
        }
    }
    
    static func verifyChunkData(_ chunk: ChunkInfo) -> Bool {
        guard let data = chunk.data else { return false }
        return Int64(data.count) == chunk.size
    }
    
    static func calculateChecksum(for filePath: URL) -> String? {
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Chunk State Persistence
class ChunkStatePersistence {
    private static let stateFileName = "chunk_download_state.json"
    
    private static var stateFileURL: URL? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDir.appendingPathComponent(stateFileName)
    }
    
    struct ChunkDownloadState: Codable {
        let modelTier: String
        let files: [FileChunkInfo]
        let totalSize: Int64
        let downloadedSize: Int64
        let lastUpdateTime: Date
        let isCompleted: Bool
    }
    
    static func saveState(_ state: ChunkDownloadState) {
        guard let stateURL = stateFileURL else {
            print("Cannot save chunk state: no state file URL")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateURL)
            print("Chunk download state saved successfully")
        } catch {
            print("Failed to save chunk download state: \(error)")
        }
    }
    
    static func loadState() -> ChunkDownloadState? {
        guard let stateURL = stateFileURL,
              FileManager.default.fileExists(atPath: stateURL.path) else {
            print("No chunk download state file found")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: stateURL)
            let state = try JSONDecoder().decode(ChunkDownloadState.self, from: data)
            print("Chunk download state loaded successfully")
            return state
        } catch {
            print("Failed to load chunk download state: \(error)")
            return nil
        }
    }
    
    static func clearState() {
        guard let stateURL = stateFileURL else { return }
        
        try? FileManager.default.removeItem(at: stateURL)
        print("Chunk download state cleared")
    }
}

// MARK: - Network Resilience and Retry Logic
class NetworkResilienceManager: @unchecked Sendable {
    static let shared = NetworkResilienceManager()
    
    private init() {}
    
    func shouldRetryChunk(_ chunk: ChunkInfo, error: Error) -> Bool {
        // Don't retry if already exceeded max retries
        guard chunk.retryCount < 3 else { return false }
        
        // Check if error is retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            case .badServerResponse, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        
        return true
    }
    
    func getRetryDelay(for retryCount: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s
        return pow(2.0, Double(retryCount))
    }
    
    func adaptChunkSize(basedOnNetworkCondition currentChunkSize: Int64, downloadSpeed: Double) -> Int64 {
        // Adapt chunk size based on network performance
        switch downloadSpeed {
        case 0..<(100 * 1024): // < 100 KB/s
            return max(1 * 1024 * 1024, currentChunkSize / 2) // Smaller chunks for slow connections
        case (100 * 1024)..<(1024 * 1024): // 100KB/s - 1MB/s
            return min(10 * 1024 * 1024, currentChunkSize)
        case (1024 * 1024)..<(10 * 1024 * 1024): // 1MB/s - 10MB/s
            return min(25 * 1024 * 1024, currentChunkSize * 2)
        default: // > 10MB/s
            return min(50 * 1024 * 1024, currentChunkSize * 2) // Larger chunks for fast connections
        }
    }
}

// MARK: - Chunk-Based Download Manager (Production Ready)
@MainActor
class ModelDownloadManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var selectedTier: ModelTier?
    @Published var errorMessage: String?
    @Published var isModelDownloaded = false
    @Published var canResume = false
    @Published var currentFileName = ""
    @Published var downloadSpeed: Double = 0.0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var showCellularAlert = false
    @Published var networkStatusMessage = ""
    @Published var downloadFiles: [DownloadFileInfo] = []
    @Published var totalDownloadSize: Int64 = 0
    @Published var completedDownloadSize: Int64 = 0
    
    // MARK: - Chunk-based Properties
    @Published var activeChunks: [ChunkInfo] = []
    @Published var completedChunksCount: Int = 0
    @Published var totalChunksCount: Int = 0
    
    // MARK: - Computed Properties for UI (스레드 안전성 보장)
    var downloadedBytes: Int64 {
        return completedDownloadSize
    }
    
    var totalBytes: Int64 {
        return totalDownloadSize
    }
    
    // MARK: - Private Properties
    private let chunkDownloadManager = ParallelChunkDownloadManager()
    private var modelDirectory: URL?
    var currentFileIndex = 0 // ContentView에서 접근하도록 internal로 변경
    private var downloadStartTime: Date?
    let networkMonitor = NetworkMonitor()
    private var userApprovedCellular = false
    
    // 청크 기반 다운로드 시스템
    private var filesToDownload: [(url: String, fileName: String)] = []
    private var actualFileSizes: [String: Int64] = [:] // URL -> 실제 파일 크기
    private var chunkDownloadState: ChunkStatePersistence.ChunkDownloadState?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNetworkMonitoring()
        loadPreviousChunkDownloadState()
        checkExistingModels()
        setupChunkManagerObservers()
    }
    
    deinit {
        // 메모리 해제 시 리소스 정리
        let manager = self.chunkDownloadManager
        Task { @MainActor in
            manager.cancelDownload()
        }
        print("ModelDownloadManager deinit - 메모리 해제 완료")
    }
    
    // MARK: - Setup Methods
    private func setupNetworkMonitoring() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if self.networkMonitor.isConnected {
                if self.networkMonitor.isWiFi {
                    self.networkStatusMessage = "WiFi 연결됨"
                } else if self.networkMonitor.isCellular {
                    self.networkStatusMessage = self.networkMonitor.isExpensive ? "셀룰러 연결됨 (제한된 데이터)" : "셀룰러 연결됨"
                } else {
                    self.networkStatusMessage = "인터넷 연결됨"
                }
            } else {
                self.networkStatusMessage = "인터넷 연결 없음"
            }
        }
    }
    
    private func loadPreviousChunkDownloadState() {
        chunkDownloadState = ChunkStatePersistence.loadState()
        guard let state = chunkDownloadState else {
            print("이전 청크 다운로드 상태 없음")
            return
        }
            print("이전 청크 다운로드 상태 로드: \(state.modelTier), 진행률: \(state.downloadedSize)/\(state.totalSize)")
            
        // 상태 복원 - nil 안전성 보장
        guard let tier = ModelTier.allCases.first(where: { $0.rawValue == state.modelTier }) else {
            print("알 수 없는 모델 tier: \(state.modelTier)")
            ChunkStatePersistence.clearState() // 잘못된 상태 파일 제거
            return
        }
        
        selectedTier = tier
        totalDownloadSize = max(0, state.totalSize) // 음수 방지
        completedDownloadSize = max(0, min(state.downloadedSize, state.totalSize)) // 범위 검증
                
                if state.isCompleted {
                    isModelDownloaded = true
                    downloadProgress = 1.0
                } else {
                    // 부분 다운로드 상태 표시
                    downloadProgress = Double(state.downloadedSize) / Double(state.totalSize)
                    canResume = true
                    
                    // 청크 상태 복원
                    totalChunksCount = state.files.reduce(0) { $0 + $1.chunks.count }
                    completedChunksCount = state.files.reduce(0) { $0 + $1.completedChunks }
                }
    }
    
    private func setupChunkManagerObservers() {
        chunkDownloadManager.$overallProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.downloadProgress = progress
            }
            .store(in: &cancellables)

        chunkDownloadManager.$isDownloading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDownloading in
                self?.isDownloading = isDownloading
            }
            .store(in: &cancellables)

        chunkDownloadManager.$downloadSpeed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speed in
                self?.downloadSpeed = speed
            }
            .store(in: &cancellables)

        chunkDownloadManager.$estimatedTimeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.estimatedTimeRemaining = time
            }
            .store(in: &cancellables)

        chunkDownloadManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)

        chunkDownloadManager.$fileChunks
            .receive(on: DispatchQueue.main)
            .map { $0.flatMap { $0.chunks.filter { $0.isInProgress } } }
            .sink { [weak self] activeChunks in
                self?.activeChunks = activeChunks
            }
            .store(in: &cancellables)

        chunkDownloadManager.$fileChunks
            .receive(on: DispatchQueue.main)
            .map { $0.reduce(0) { $0 + $1.completedChunks } }
            .sink { [weak self] count in
                self?.completedChunksCount = count
            }
            .store(in: &cancellables)

        chunkDownloadManager.$fileChunks
            .receive(on: DispatchQueue.main)
            .map { $0.reduce(0) { $0 + $1.totalChunks } }
            .sink { [weak self] count in
                self?.totalChunksCount = count
            }
            .store(in: &cancellables)

        chunkDownloadManager.$fileChunks
            .receive(on: DispatchQueue.main)
            .map { $0.reduce(0) { $0 + $1.downloadedBytes } }
            .sink { [weak self] bytes in
                self?.completedDownloadSize = bytes
            }
            .store(in: &cancellables)
    }
    
    private func checkExistingModels() {
        guard let modelsPath = AppBundleStorageManager.getModelsDirectory() else { 
            print("Cannot access app models directory")
            return 
        }
        
        // 기존 청크 다운로드 상태가 있고 완료되어 있다면 먼저 확인
        if let state = chunkDownloadState, state.isCompleted,
           let tier = ModelTier.allCases.first(where: { $0.rawValue == state.modelTier }) {
            
            let modelPath = modelsPath.appendingPathComponent(tier.folderName)
            let expectedFiles = ["model.safetensors": tier.mainFileUrl, 
                               "config.json": tier.configFileUrl, 
                               "tokenizer.json": tier.tokenizerFileUrl]
            
            // 파일 무결성 검증
            var allValid = true
            for (fileName, url) in expectedFiles {
                let filePath = modelPath.appendingPathComponent(fileName)
                if let fileInfo = state.files.first(where: { $0.url == url }) {
                    let verificationResult = ChunkFileIntegrityVerifier.verifyMergedFile(
                        at: filePath, 
                        expectedSize: fileInfo.totalSize
                    )
                    if !verificationResult.isValid {
                        allValid = false
                        print("파일 검증 실패: \(fileName) - \(verificationResult.errorMessage ?? "Unknown error")")
                        break
                    }
                } else {
                    allValid = false
                    break
                }
            }
            
            if allValid {
                self.isModelDownloaded = true
                self.selectedTier = tier
                self.downloadProgress = 1.0
                print("검증된 기존 모델 발견: \(tier.rawValue) at \(modelPath.path)")
                return
            } else {
                print("기존 모델 파일 손상 감지, 재다운로드 필요")
                ChunkStatePersistence.clearState()
                chunkDownloadState = nil
            }
        }
        
        // 수동으로 모든 티어 확인 (백업)
        for tier in ModelTier.allCases {
            let modelPath = modelsPath.appendingPathComponent(tier.folderName)
            let requiredFiles = ["model.safetensors", "config.json", "tokenizer.json"]
            let allFilesExist = requiredFiles.allSatisfy { fileName in
                let filePath = modelPath.appendingPathComponent(fileName)
                return FileManager.default.fileExists(atPath: filePath.path)
            }
            
            if allFilesExist {
                self.isModelDownloaded = true
                self.selectedTier = tier
                self.downloadProgress = 1.0
                print("수동 검증으로 기존 모델 발견: \(tier.rawValue)")
                break
            }
        }
    }
    
    // MARK: - Chunk-Based Download Method (Production Ready)
    func downloadModel(tier: ModelTier) {
        // 메인 스레드에서 실행 확인
        assert(Thread.isMainThread, "downloadModel must be called on main thread")
        
        print("[CHUNK SYSTEM] 청크 기반 다운로드 시작: \(tier.rawValue)")
        
        // 네트워크 연결 확인
        guard networkMonitor.isConnected else {
            errorMessage = DownloadError.networkUnavailable.localizedDescription
            return
        }
        
        // 이전 다운로드 취소 및 상태 초기화
        cancelDownload()
        resetDownloadState()
        
        // UI 상태 업데이트
        selectedTier = tier
        errorMessage = nil
        canResume = false
        currentFileIndex = 0
        downloadStartTime = Date()
        currentFileName = "파일 크기 확인 중..."
        
        // 모델 디렉토리 설정
        guard let modelsPath = AppBundleStorageManager.getModelsDirectory() else {
            errorMessage = "앱 모델 디렉토리에 접근할 수 없습니다"
            return
        }
        
        modelDirectory = modelsPath.appendingPathComponent(tier.folderName)
        
        guard let modelDir = modelDirectory else {
            errorMessage = "모델 디렉토리 경로를 설정할 수 없습니다"
            return
        }
        
        // 다운로드할 파일 목록 구성
        filesToDownload = [
            (tier.mainFileUrl, "model.safetensors"),
            (tier.configFileUrl, "config.json"),
            (tier.tokenizerFileUrl, "tokenizer.json")
        ]
        
        // 청크 기반 다운로드 시작
        Task {
            await startChunkBasedDownload(tier: tier, modelDir: modelDir)
        }
    }
    
    // MARK: - Chunk-Based Download Implementation
    private func startChunkBasedDownload(tier: ModelTier, modelDir: URL) async {
        do {
            // 1. 실제 파일 크기 확인 (HEAD 요청) - 에러 핸들링 개선
            await MainActor.run { currentFileName = "파일 크기 확인 중..." }
            
            let urls = filesToDownload.map { $0.url }
            guard !urls.isEmpty else {
                throw DownloadError.invalidURL("빈 URL 목록")
            }
            
            actualFileSizes = try await FileSizeChecker.getFileSizesBatch(urls: urls)
            
            // 파일 크기 유효성 검증
            for (url, size) in actualFileSizes {
                guard size > 0 else {
                    throw DownloadError.fileSizeNotAvailable
                }
            }
            
            print("실제 파일 크기 확인 완료:")
            for (url, size) in actualFileSizes {
                let fileName = URL(string: url)?.lastPathComponent ?? "unknown"
                print("  - \(fileName): \(AppBundleStorageManager.formatBytes(size))")
            }
            
            // 2. 전체 다운로드 크기 계산 - 오버플로우 방지
            let calculatedTotalSize = actualFileSizes.values.reduce(Int64(0)) { result, size in
                let newTotal = result + size
                guard newTotal >= result else { // 오버플로우 방지
                    return result
                }
                return newTotal
            }
            
            guard calculatedTotalSize > 0 else {
                throw DownloadError.fileSizeNotAvailable
            }
            
            totalDownloadSize = calculatedTotalSize
            await MainActor.run {
                self.totalDownloadSize = totalDownloadSize
                print("전체 다운로드 크기: \(AppBundleStorageManager.formatBytes(totalDownloadSize))")
            }
            
            // 3. 저장 공간 확인
            guard AppBundleStorageManager.hasEnoughSpace(requiredBytes: totalDownloadSize) else {
                let available = AppBundleStorageManager.getAvailableSpace() ?? 0
                throw DownloadError.insufficientStorage(required: totalDownloadSize, available: available)
            }
            
            // 4. 기존 파일 검증 및 스킵 처리
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true, attributes: nil)
            
            // 파일 이름 중복 및 nil 안전성 검증
            var expectedFiles: [String: Int64] = [:]
            for fileInfo in filesToDownload {
                guard !fileInfo.fileName.isEmpty else {
                    print("⚠️ 빈 파일 이름 건너뛰기")
                    continue
                }
                
                if let size = actualFileSizes[fileInfo.url], size > 0 {
                    if expectedFiles[fileInfo.fileName] != nil {
                        print("⚠️ 중복된 파일 이름: \(fileInfo.fileName)")
                    }
                    expectedFiles[fileInfo.fileName] = size
                } else {
                    print("⚠️ 파일 크기를 찾을 수 없음: \(fileInfo.fileName)")
                }
            }
            
            guard !expectedFiles.isEmpty else {
                throw DownloadError.fileSizeNotAvailable
            }
            
            let validationResults = FileIntegrityChecker.validateAllFiles(in: modelDir, expectedFiles: expectedFiles)
            
            // 5. 이미 모든 파일이 올바르게 존재하는 경우
            let allFilesValid = validationResults.values.allSatisfy { $0.isValid }
            if allFilesValid {
                print("모든 파일이 이미 올바르게 다운로드되어 있습니다. 중복 다운로드 방지.")
                await completeDownloadImmediately(tier: tier)
                return
            }
            
            // 6. 다운로드할 파일들만 필터링 - 안전성 개선
            var filesToActuallyDownload: [(url: String, fileName: String, totalSize: Int64)] = []
            var alreadyDownloadedSize: Int64 = 0
            
            for fileInfo in filesToDownload {
                guard !fileInfo.fileName.isEmpty, !fileInfo.url.isEmpty else {
                    print("⚠️ 잘못된 파일 정보 건너뛰기: \(fileInfo)")
                    continue
                }
                
                let validation = validationResults[fileInfo.fileName]
                if validation?.isValid == true {
                    print("파일 스킵 (이미 존재): \(fileInfo.fileName)")
                    alreadyDownloadedSize += actualFileSizes[fileInfo.url] ?? Int64(0)
                } else {
                    guard let fileSize = actualFileSizes[fileInfo.url], fileSize > 0 else {
                        print("⚠️ 잘못된 파일 크기: \(fileInfo.fileName)")
                        continue
                    }
                    filesToActuallyDownload.append((fileInfo.url, fileInfo.fileName, fileSize))
                    print("다운로드 필요: \(fileInfo.fileName)")
                }
            }
            
            await MainActor.run {
                self.completedDownloadSize = alreadyDownloadedSize
            }
            
            // 7. 청크 기반 다운로드 시작
            if filesToActuallyDownload.isEmpty {
                await completeDownloadImmediately(tier: tier)
            } else {
                await startChunkDownload(files: filesToActuallyDownload, destinationDirectory: modelDir, tier: tier)
            }
            
        } catch {
            await MainActor.run {
                if let downloadError = error as? DownloadError {
                    errorMessage = downloadError.localizedDescription
                } else {
                    errorMessage = "다운로드 준비 중 오류 발생: \(error.localizedDescription)"
                }
                isDownloading = false
                print("청크 다운로드 준비 실패: \(error)")
            }
        }
    }
    
    private func startChunkDownload(files: [(url: String, fileName: String, totalSize: Int64)], destinationDirectory: URL, tier: ModelTier) async {
        guard !files.isEmpty else {
            print("⚠️ 다운로드할 파일이 없음")
            await MainActor.run {
                errorMessage = "다운로드할 파일이 없음"
                isDownloading = false
            }
            return
        }
        
        print("청크 기반 다운로드 시작 - \(files.count) 파일")
        
        // 디렉토리 액세스 가능성 확인
        guard FileManager.default.isWritableFile(atPath: destinationDirectory.path) || 
              (try? FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)) != nil else {
            await MainActor.run {
                errorMessage = "목적지 디렉토리에 쓸 수 없음: \(destinationDirectory.path)"
                isDownloading = false
            }
            return
        }
        
        do {
            // 청크 다운로드 시작
            await chunkDownloadManager.startDownload(files: files, to: destinationDirectory)
            
            // 다운로드 완료 처리
            await handleChunkDownloadCompletion(tier: tier)
        } catch {
            await MainActor.run {
                errorMessage = "청크 다운로드 실패: \(error.localizedDescription)"
                isDownloading = false
                print("❌ 청크 다운로드 오류: \(error)")
            }
        }
    }
    
    private func handleChunkDownloadCompletion(tier: ModelTier) async {
        await MainActor.run {
            let allFilesCompleted = chunkDownloadManager.fileChunks.allSatisfy { $0.isCompleted }
            
            if allFilesCompleted && chunkDownloadManager.errorMessage == nil {
                // 성공적으로 완료
                isModelDownloaded = true
                canResume = false
                currentFileName = ""
                
                // 다운로드된 파일들 검증
                validateChunkDownloadedFiles()
                
                // 상태 저장
                saveChunkDownloadState(tier: tier, isCompleted: true)
                
                print("[SUCCESS] 청크 기반 다운로드 완료 - 전체 크기: \(AppBundleStorageManager.formatBytes(totalDownloadSize))")
            } else {
                // 실패 또는 부분 완료
                canResume = true
                
                if let error = chunkDownloadManager.errorMessage {
                    errorMessage = error
                }
                
                // 부분 완료 상태 저장
                saveChunkDownloadState(tier: tier, isCompleted: false)
                
                print("청크 다운로드 부분 완료 또는 실패")
            }
        }
    }
    
    private func validateChunkDownloadedFiles() {
        guard let modelDir = modelDirectory else { 
            errorMessage = "모델 디렉토리가 설정되지 않음"
            print("❌ 모델 디렉토리 경로 없음")
            return 
        }
        
        // 디렉토리 존재 확인
        guard FileManager.default.fileExists(atPath: modelDir.path) else {
            errorMessage = "모델 디렉토리가 존재하지 않음: \(modelDir.path)"
            print("❌ 모델 디렉토리 없음: \(modelDir.path)")
            return
        }
        
        let requiredFiles = ["model.safetensors", "config.json", "tokenizer.json"]
        var validationErrors: [String] = []
        
        // 각 파일의 무결성 검증 - 안전성 개선
        for fileName in requiredFiles {
            guard !fileName.isEmpty else {
                validationErrors.append("빈 파일 이름 건너뛰기")
                continue
            }
            
            let filePath = modelDir.appendingPathComponent(fileName)
            
            // 파일 존재 확인
            guard FileManager.default.fileExists(atPath: filePath.path) else {
                validationErrors.append("파일 없음: \(fileName)")
                continue
            }
            
            if let fileChunk = chunkDownloadManager.fileChunks.first(where: { $0.fileName == fileName && $0.totalSize > 0 }) {
                let verificationResult = ChunkFileIntegrityVerifier.verifyMergedFile(
                    at: filePath, 
                    expectedSize: fileChunk.totalSize
                )
                
                if !verificationResult.isValid {
                    let errorMsg = verificationResult.errorMessage ?? "Unknown error"
                    validationErrors.append("파일 검증 실패: \(fileName) - \(errorMsg)")
                    print("❌ 검증 실패: \(fileName) - \(errorMsg)")
                } else {
                    print("✅ 검증 완료: \(fileName) - \(AppBundleStorageManager.formatBytes(verificationResult.actualSize))")
                }
            } else {
                validationErrors.append("파일 청크 정보 없음: \(fileName)")
                print("⚠️ 청크 정보 없음: \(fileName)")
            }
        }
        
        // 검증 결과 처리 - 에러 처리 개선
        if !validationErrors.isEmpty {
            let joinedErrors = validationErrors.prefix(3).joined(separator: "; ") // 너무 긴 에러 메시지 방지
            errorMessage = "파일 검증 실패: \(joinedErrors)\(validationErrors.count > 3 ? " 및 \(validationErrors.count - 3)개 추가 오류" : "")"
            isModelDownloaded = false
            print("❌ [오류] 파일 검증 실패 (\(validationErrors.count)개): \(validationErrors)")
        } else {
            print("✅ [성공] 모든 파일 검증 완료")
        }
    }
    
    private func saveChunkDownloadState(tier: ModelTier, isCompleted: Bool) {
        let chunkDownloadState = ChunkStatePersistence.ChunkDownloadState(
            modelTier: tier.rawValue,
            files: chunkDownloadManager.fileChunks,
            totalSize: totalDownloadSize,
            downloadedSize: isCompleted ? totalDownloadSize : completedDownloadSize,
            lastUpdateTime: Date(),
            isCompleted: isCompleted
        )
        
        ChunkStatePersistence.saveState(chunkDownloadState)
        self.chunkDownloadState = chunkDownloadState
    }
    
    private func completeDownloadImmediately(tier: ModelTier) async {
        await MainActor.run {
            isDownloading = false
            isModelDownloaded = true
            downloadProgress = 1.0
            canResume = false
            currentFileName = ""
            
            // 상태 저장
            saveChunkDownloadState(tier: tier, isCompleted: true)
            
            print("중복 다운로드 방지로 즉시 완료")
        }
    }
    
    
    
    // MARK: - Chunk-Based Download Control
    func pauseDownload() {
        // 메인 스레드에서 실행 확인
        assert(Thread.isMainThread, "pauseDownload must be called on main thread")
        
        print("[CHUNK PAUSE] 청크 다운로드 일시정지")
        chunkDownloadManager.pauseDownload()
        canResume = true
        
        // 현재 상태 저장
        if let tier = selectedTier {
            saveChunkDownloadState(tier: tier, isCompleted: false)
        }
    }
    
    func cancelDownload() {
        // 메인 스레드에서 실행 확인
        assert(Thread.isMainThread, "cancelDownload must be called on main thread")
        
        print("[CHUNK CANCEL] 청크 다운로드 취소 (완료된 청크는 보존)")
        chunkDownloadManager.cancelDownload()
        isDownloading = false
        canResume = true
        currentFileName = ""
        
        // 부분 완료 상태 저장
        if let tier = selectedTier {
            saveChunkDownloadState(tier: tier, isCompleted: false)
        }
    }
    
    func resumeDownload() {
        // 메인 스레드에서 실행 확인
        assert(Thread.isMainThread, "resumeDownload must be called on main thread")
        
        guard let tier = selectedTier else {
            errorMessage = "재시작할 모델 정보가 없습니다"
            return
        }
        
        // 청크 기반 다운로드 재시작
        print("[CHUNK RESUME] 청크 다운로드 재시작")
        downloadModel(tier: tier)
    }
    
    func resetDownload() {
        // 메인 스레드에서 실행 확인
        assert(Thread.isMainThread, "resetDownload must be called on main thread")
        
        cancelDownload()
        
        // Documents 폴더 내 다운로드된 파일 안전하게 삭제
        if let modelDir = modelDirectory {
            do {
                if FileManager.default.fileExists(atPath: modelDir.path) {
                    // Documents 폴더 내 모델 파일 삭제
                    let requiredFiles = ["model.safetensors", "config.json", "tokenizer.json"]
                    for fileName in requiredFiles {
                        let filePath = modelDir.appendingPathComponent(fileName)
                        if FileManager.default.fileExists(atPath: filePath.path) {
                            try FileManager.default.removeItem(at: filePath)
                            print("삭제 완료: \(filePath.path)")
                        }
                    }
                    
                    // 빈 디렉토리인 경우 디렉토리도 삭제
                    let contents = try FileManager.default.contentsOfDirectory(atPath: modelDir.path)
                    if contents.isEmpty {
                        try FileManager.default.removeItem(at: modelDir)
                        print("빈 모델 디렉토리 삭제: \(modelDir.path)")
                    }
                }
            } catch {
                print("모델 파일 삭제 실패: \(error.localizedDescription)")
                // 삭제 실패해도 리셋은 계속 진행
            }
        }
        
        // [CHUNK SYSTEM] 완전한 상태 초기화
        isDownloading = false
        downloadProgress = 0.0
        selectedTier = nil
        errorMessage = nil
        isModelDownloaded = false
        canResume = false
        currentFileName = ""
        currentFileIndex = 0
        filesToDownload = []
        modelDirectory = nil
        downloadFiles = []
        actualFileSizes = [:]
        totalDownloadSize = 0
        completedDownloadSize = 0
        downloadStartTime = nil
        downloadSpeed = 0.0
        estimatedTimeRemaining = 0
        
        // 청크 관련 상태 초기화
        activeChunks = []
        completedChunksCount = 0
        totalChunksCount = 0
        
        // 영구 저장된 상태도 삭제
        ChunkStatePersistence.clearState()
        chunkDownloadState = nil
        
        print("[CHUNK SYSTEM] 다운로드 상태 완전 초기화 완료")
    }
    
    private func resetDownloadState() {
        downloadFiles.removeAll()
        actualFileSizes.removeAll()
        totalDownloadSize = 0
        completedDownloadSize = 0
        currentFileIndex = 0
        activeChunks.removeAll()
        completedChunksCount = 0
        totalChunksCount = 0
    }
    
    // MARK: - Helper Methods
    
    func formatSpeed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond >= 0 else { return "0.0 MB/s" } // 음수 방지
        
        let mbPerSecond = bytesPerSecond / (1024 * 1024)
        if mbPerSecond < 0.1 {
            let kbPerSecond = bytesPerSecond / 1024
            return String(format: "%.1f KB/s", kbPerSecond)
        } else {
            return String(format: "%.1f MB/s", mbPerSecond)
        }
    }
    
    func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        guard timeInterval >= 0 && timeInterval.isFinite else { return "--:--" } // 잘못된 값 처리
        
        let totalSeconds = max(0, Int(timeInterval))
        
        if totalSeconds >= 3600 { // 1시간 이상
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            return String(format: "%d:%02d:00", hours, minutes)
        } else {
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func resumeSpecificFile(fileName: String) {
        // 청크 기반 다운로드에서는 파일 단위 재시작 지원
        print("Resuming specific file with chunk system: \(fileName)")
        resumeDownload()
    }
    
    func denyCellularDownload() {
        showCellularAlert = false
        userApprovedCellular = false
        cancelDownload()
    }
    
    func approveCellularDownload() {
        showCellularAlert = false
        userApprovedCellular = true
        // 청크 다운로드 매니저는 자체적으로 네트워크 설정을 관리
        // 다운로드 재시작
        if let tier = selectedTier {
            downloadModel(tier: tier)
        }
    }
    
    private func getDetailedErrorMessage(_ error: Error) -> String {
        // 오류 메시지 길이 제한 및 안전성 개선 
        let nsError = error as NSError
        
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            return "인터넷에 연결되지 않았습니다. 네트워크 연결을 확인해주세요."
        case NSURLErrorTimedOut:
            return "다운로드 시간이 초과되었습니다. 네트워크 상태를 확인해주세요."
        case NSURLErrorCannotFindHost:
            return "서버를 찾을 수 없습니다. URL을 확인해주세요."
        case NSURLErrorCannotConnectToHost:
            return "서버에 연결할 수 없습니다."
        case NSURLErrorNetworkConnectionLost:
            return "네트워크 연결이 끊어졌습니다."
        case NSURLErrorFileDoesNotExist:
            return "요청한 파일이 서버에 존재하지 않습니다."
        case NSURLErrorHTTPTooManyRedirects:
            return "너무 많은 리다이렉트가 발생했습니다."
        case NSURLErrorResourceUnavailable:
            return "서버 리소스를 사용할 수 없습니다."
        default:
            let errorDescription = error.localizedDescription.prefix(100) // 긴 에러 메시지 제한
            return "다운로드 실패: \(errorDescription) (코드: \(nsError.code))"
        }
    }
}

@MainActor
struct ContentView: View {
    @StateObject private var downloader = ModelDownloadManager()
    @State private var isShowingSettings = false
    
    // UI 상태 추가 - 메모리 안전성
    @State private var lastUpdateTime = Date()
    private let uiUpdateThrottle: TimeInterval = 0.1 // UI 업데이트 제한
    
    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "0 MB" } // 음수 방지
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                titleSection
                
                VStack(spacing: 16) {
                    downloadSection
                    chatNavigationButton
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                bottomSafeArea
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            })
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .alert("셀룰러 데이터 사용", isPresented: $downloader.showCellularAlert) {
            Button("취소", role: .cancel) {
                downloader.denyCellularDownload()
            }
            Button("계속") {
                downloader.approveCellularDownload()
            }
        } message: {
            Text("현재 셀룰러 데이터에 연결되어 있습니다. 대용량 AI 모델을 다운로드하면 데이터 요금이 발생할 수 있습니다. 계속하시겠습니까?")
        }
        .onAppear {
            // 알림 표시 시 UI 업데이트 제한 초기화
            lastUpdateTime = Date()
        }
    }
    
    // MARK: - View Components
    
    private var titleSection: some View {
        Text("오프라인 AI 챗봇")
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding(.top, 20)
            .padding(.horizontal)
    }
    
    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            downloadHeaderView
            downloadContentView
            networkStatusView
            errorMessageView
        }
    }
    
    private var downloadHeaderView: some View {
        HStack {
            Text("AI 모델 다운로드")
                .font(.headline)
            
            Spacer()
            
            if downloader.isModelDownloaded {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("완료")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    @ViewBuilder
    private var downloadContentView: some View {
        if downloader.isDownloading {
            downloadingView
        } else if downloader.isModelDownloaded {
            completedView
        } else {
            modelSelectionView
        }
    }
    
    private var downloadingView: some View {
        VStack(spacing: 12) {
            downloadProgressHeader
            currentFileInfo
            progressBar
            downloadStatistics
            downloadControls
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var downloadProgressHeader: some View {
        HStack {
            Text("다운로드 중...")
                .font(.subheadline)
                .foregroundColor(.blue)
            Spacer()
            Text(downloader.selectedTier?.rawValue ?? "")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    @ViewBuilder
    private var currentFileInfo: some View {
        if !downloader.currentFileName.isEmpty {
            HStack {
                Text("현재 파일: \(downloader.currentFileName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
    
    private var progressBar: some View {
        ProgressView(value: downloader.downloadProgress)
            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
    }
    
    private var downloadStatistics: some View {
        HStack {
            Text("\(Int(downloader.downloadProgress * 100))% 완료")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            downloadSizeAndSpeedInfo
        }
    }
    
    private func calculateCompletedBytes(downloader: ModelDownloadManager) -> Int64 {
        var completedBytes: Int64 = 0
        let maxIndex = min(downloader.currentFileIndex, downloader.downloadFiles.count)
        for i in 0..<maxIndex {
            completedBytes += downloader.downloadFiles[i].actualFileSize
        }
        return completedBytes
    }
    
    private var downloadSizeAndSpeedInfo: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // 전체 다운로드 정보만 표시 (단순화)
            if downloader.totalDownloadSize > 0 {
                // 완료된 파일들의 실제 크기 합계
                let completedBytes = calculateCompletedBytes(downloader: downloader)
                
                // 현재 다운로드 중인 파일의 진행률
                let currentFileDownloadedBytes = downloader.downloadedBytes
                let totalDownloadedBytes = completedBytes + currentFileDownloadedBytes
                
                Text("\(formatBytes(totalDownloadedBytes)) / \(formatBytes(downloader.totalDownloadSize))")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            }
            
            // 속도와 남은 시간
            if downloader.downloadSpeed > 0 {
                HStack(spacing: 6) {
                    Text(downloader.formatSpeed(downloader.downloadSpeed))
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    if downloader.estimatedTimeRemaining > 0 && downloader.estimatedTimeRemaining < 86400 {
                        Text("• \(downloader.formatTimeInterval(downloader.estimatedTimeRemaining)) 남음")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var downloadControls: some View {
        HStack(spacing: 12) {
            if downloader.isDownloading {
                Button("일시정지") {
                    downloader.pauseDownload()
                }
                .font(.caption)
                .foregroundColor(.orange)
                
                Button("취소") {
                    downloader.cancelDownload()
                }
                .font(.caption)
                .foregroundColor(.red)
            } else if downloader.canResume {
                Button("재개") {
                    downloader.resumeDownload()
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("취소") {
                    downloader.cancelDownload()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            
            Spacer()
        }
    }
    
    private var resumeMenu: some View {
        Menu("재시작") {
            Button("전체 재시작") {
                downloader.resumeDownload()
            }
            
            Divider()
            
            ForEach(downloader.downloadFiles.indices, id: \.self) { index in
                let file = downloader.downloadFiles[index]
                if case .failed = file.status {
                    Button("\(file.fileName) 재시작") {
                        downloader.resumeSpecificFile(fileName: file.fileName)
                    }
                } else if file.status == .paused {
                    Button("\(file.fileName) 재시작") {
                        downloader.resumeSpecificFile(fileName: file.fileName)
                    }
                }
            }
        }
        .font(.caption)
        .foregroundColor(.blue)
    }
    
    private var completedView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("모델 다운로드 완료")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(downloader.selectedTier?.rawValue ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("재다운로드") {
                    downloader.resetDownload()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var modelSelectionView: some View {
        VStack(spacing: 12) {
            Text("기기 사양에 맞는 모델을 선택하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(ModelTier.allCases, id: \.self) { tier in
                modelTierButton(tier: tier)
            }
        }
    }
    
    private func modelTierButton(tier: ModelTier) -> some View {
        Button {
            print("버튼 클릭: \(tier.rawValue)")
            downloader.downloadModel(tier: tier)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(tier.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var networkStatusView: some View {
        if !downloader.networkStatusMessage.isEmpty {
            HStack {
                networkStatusIcon
                Text(downloader.networkStatusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(downloader.networkMonitor.isConnected ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private var networkStatusIcon: some View {
        Image(systemName: downloader.networkMonitor.isWiFi ? "wifi" : downloader.networkMonitor.isCellular ? "antenna.radiowaves.left.and.right" : "network")
            .foregroundColor(downloader.networkMonitor.isConnected ? .green : .red)
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = downloader.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                
                fileStatusDetails
            }
            .padding()
            .background(Color.red.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var fileStatusDetails: some View {
        if !downloader.downloadFiles.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("파일별 상태:")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                ForEach(downloader.downloadFiles.indices, id: \.self) { index in
                    fileStatusRow(file: downloader.downloadFiles[index])
                }
            }
        }
    }
    
    private func fileStatusRow(file: DownloadFileInfo) -> some View {
        HStack {
            fileStatusIcon(status: file.status)
            Text(file.fileName)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            fileStatusText(status: file.status)
        }
    }
    
    private func fileStatusIcon(status: DownloadFileStatus) -> some View {
        Image(systemName: status == .completed ? "checkmark.circle.fill" : status == .paused ? "pause.circle" : "xmark.circle")
            .foregroundColor(status == .completed ? .green : .red)
            .font(.caption2)
    }
    
    @ViewBuilder
    private func fileStatusText(status: DownloadFileStatus) -> some View {
        switch status {
        case .downloading(let progress):
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundColor(.blue)
        case .failed:
            Text("실패")
                .font(.caption2)
                .foregroundColor(.red)
        case .completed:
            Text("완료")
                .font(.caption2)
                .foregroundColor(.green)
        default:
            EmptyView()
        }
    }
    
    private var chatNavigationButton: some View {
        NavigationLink("AI와 채팅하기") {
            ChatView(isModelDownloaded: downloader.isModelDownloaded)
        }
        .buttonStyle(.borderedProminent)
        .font(.headline)
        .disabled(!downloader.isModelDownloaded)
    }
    
    private var bottomSafeArea: some View {
        Color.clear.frame(height: max(getSafeAreaInsets().bottom, 8))
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIEdgeInsets.zero
        }
        return window.safeAreaInsets
    }
}

@MainActor
struct ChatView: View {
    @State private var messages: [String] = []
    @State private var inputText = ""
    let isModelDownloaded: Bool
    
    init(isModelDownloaded: Bool = false) {
        self.isModelDownloaded = isModelDownloaded
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !isModelDownloaded {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("AI 모델이 연결되지 않았습니다")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("먼저 AI 모델을 다운로드해주세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            Text(message)
                                .padding()
                                .background(index % 2 == 0 ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                HStack(spacing: 12) {
                    TextField("메시지를 입력하세요...", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button("전송") {
                        sendMessage()
                    }
                    .disabled(inputText.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(.systemBackground))
                .safeAreaInset(edge: .bottom) {
                    // iPhone 16 Pro Max (6.9인치) 등 큰 화면 대응
                    Color.clear.frame(height: max(getSafeAreaInsets().bottom, 8))
                }
            }
        }
        .navigationTitle("AI 채팅")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = "사용자: \(inputText)"
        messages.append(userMessage)
        _ = inputText // 경고 제거를 위한 더미 대입
        inputText = ""
        
        // AI 응답 시뮬레이션 (실제 AI 모델 연동 시 이 부분을 수정)
        if isModelDownloaded {
            Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기
                    let responses = [
                        "안녕하세요! 무엇을 도와드릴까요?",
                        "좋은 질문이네요. 더 자세히 설명해 주시겠어요?",
                        "흥미로운 주제입니다. 다른 관점에서 생각해보면...",
                        "도움이 되었기를 바랍니다. 다른 질문이 있으시면 언제든 말씀해주세요.",
                        "그렇군요. 이에 대해 더 알아보겠습니다."
                    ]
                    let randomResponse = responses.randomElement() ?? "응답을 생성하는 중입니다..."
                    messages.append("AI: \(randomResponse)")
                } catch {
                    messages.append("AI: 응답 생성 중 오류가 발생했습니다.")
                }
            }
        } else {
            messages.append("AI: 죄송합니다. AI 모델이 다운로드되지 않아 응답할 수 없습니다.")
        }
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIEdgeInsets.zero
        }
        return window.safeAreaInsets
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Bundle 정보를 가져오는 computed properties
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Offline Chatbot"
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.unknown.app"
    }
    
    var body: some View {
        NavigationView {
            List {
                // 앱 정보 섹션
                Section("앱 정보") {
                    SettingsRow(
                        icon: "app.fill",
                        iconColor: .blue,
                        title: "앱 이름",
                        value: appName
                    )
                    
                    SettingsRow(
                        icon: "number.circle.fill",
                        iconColor: .green,
                        title: "버전",
                        value: "\(appVersion) (\(buildNumber))"
                    )
                    
                    SettingsRow(
                        icon: "barcode.viewfinder",
                        iconColor: .orange,
                        title: "Bundle ID",
                        value: bundleIdentifier
                    )
                }
                
                // 개발자 정보 섹션
                Section("개발자 정보") {
                    SettingsRow(
                        icon: "person.crop.circle.fill",
                        iconColor: .purple,
                        title: "개발팀",
                        value: "AI Solutions Team"
                    )
                    
                    SettingsRow(
                        icon: "doc.text.fill",
                        iconColor: .indigo,
                        title: "라이선스",
                        value: "MIT License"
                    )
                    
                    SettingsRow(
                        icon: "info.circle.fill",
                        iconColor: .cyan,
                        title: "오픈소스",
                        value: "사용 중"
                    )
                }
                
                // 앱 설정 섹션 (향후 확장 가능)
                Section("앱 설정") {
                    SettingsRow(
                        icon: "gearshape.fill",
                        iconColor: .gray,
                        title: "모델 설정",
                        value: "자동"
                    )
                    
                    SettingsRow(
                        icon: "moon.fill",
                        iconColor: .indigo,
                        title: "다크 모드",
                        value: "시스템 설정 따라감"
                    )
                    
                    SettingsRow(
                        icon: "network",
                        iconColor: .blue,
                        title: "네트워크 사용",
                        value: "Wi-Fi 우선"
                    )
                }
                
                // 시스템 정보 섹션
                Section("시스템 정보") {
                    SettingsRow(
                        icon: "iphone",
                        iconColor: .black,
                        title: "기기 모델",
                        value: UIDevice.current.model
                    )
                    
                    SettingsRow(
                        icon: "gear.circle.fill",
                        iconColor: .gray,
                        title: "iOS 버전",
                        value: UIDevice.current.systemVersion
                    )
                    
                    if let memoryInfo = getMemoryInfo() {
                        SettingsRow(
                            icon: "memorychip.fill",
                            iconColor: .red,
                            title: "메모리 사용량",
                            value: memoryInfo
                        )
                    }
                }
                
                // 저장소 정보 섹션
                Section("저장소 정보") {
                    if let storageInfo = getStorageInfo() {
                        SettingsRow(
                            icon: "internaldrive.fill",
                            iconColor: .orange,
                            title: "사용 가능한 공간",
                            value: storageInfo
                        )
                    }
                    
                    SettingsRow(
                        icon: "folder.fill",
                        iconColor: .blue,
                        title: "앱 데이터 위치",
                        value: "Documents/AppModels"
                    )
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryInfo() -> String? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = info.resident_size
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(usedMemory))
        }
        
        return nil
    }
    
    private func getStorageInfo() -> String? {
        guard let modelsPath = AppBundleStorageManager.getModelsDirectory() else {
            return nil
        }
        
        do {
            let resourceValues = try modelsPath.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableSpace = resourceValues.volumeAvailableCapacityForImportantUsage {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useGB, .useTB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: availableSpace)
            }
        } catch {
            print("Storage info error: \(error)")
        }
        
        return nil
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Mach Task Info (for memory usage)
private struct mach_task_basic_info {
    var virtual_size: mach_vm_size_t = 0
    var resident_size: mach_vm_size_t = 0
    var resident_size_max: mach_vm_size_t = 0
    var user_time: time_value_t = time_value_t()
    var system_time: time_value_t = time_value_t()
    var policy: policy_t = 0
    var suspend_count: integer_t = 0
}

private let MACH_TASK_BASIC_INFO: Int32 = 20
private let KERN_SUCCESS: Int32 = 0

#Preview {
    ContentView()
}

#Preview("Settings") {
    SettingsView()
}