import Foundation
import CryptoKit
import SystemConfiguration // for mach_task_basic_info

// MARK: - Timeout Helper
func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
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
    
    /// HTTP 응답 헤더에서 파일 크기를 파싱하는 메서드 - 압축 처리 개선
    static func getActualFileSize(from url: String) async throws -> Int64 {
        guard let fileURL = URL(string: url) else {
            throw DownloadError.invalidURL
        }

        var request = URLRequest(url: fileURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 30.0

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }

        return try parseFileSizeFromHeaders(httpResponse.allHeaderFields, url: url)
    }

    private static func parseFileSizeFromHeaders(_ headers: [AnyHashable: Any], url: String) throws -> Int64 {
        
        print("🔍 [FileSizeChecker] 헤더 분석 시작: \(url)")
        print("📋 [FileSizeChecker] 응답 헤더 (총 \(headers.count)개):")
        for (key, value) in headers {
            print("  - \(key): \(value)")
        }

        // Content-Encoding 확인하여 압축 여부 판단
        var isCompressed = false
        let encodingKeys = ["Content-Encoding", "content-encoding", "CONTENT-ENCODING"]
        for key in encodingKeys {
            if let encoding = headers[key] as? String {
                print("📦 [FileSizeChecker] Content-Encoding: \(encoding)")
                if !encoding.isEmpty && encoding.lowercased() != "identity" {
                    isCompressed = true
                    print("⚠️ [FileSizeChecker] 압축된 응답 감지: \(encoding)")
                }
                break
            }
        }

        // 1. Hugging Face의 x-linked-size 헤더 확인 (실제 파일 크기)
        let linkedSizeKeys = ["x-linked-size", "X-Linked-Size", "X-LINKED-SIZE", "x-Linked-Size"]
        for key in linkedSizeKeys {
            if let sizeString = headers[key] as? String {
                let trimmedString = sizeString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedString.isEmpty, let fileSize = Int64(trimmedString), fileSize > 0 else {
                    print("⚠️ [FileSizeChecker] Invalid size in \(key): '\(sizeString)'")
                    continue
                }
                print("✅ [FileSizeChecker] Found actual file size via \(key): \(AppBundleStorageManager.formatBytes(fileSize))")
                return fileSize
            }
        }

        // 2. 표준 Content-Length 헤더 확인
        let contentLengthKeys = ["Content-Length", "content-length", "CONTENT-LENGTH", "Content-length"]
        for key in contentLengthKeys {
            if let sizeString = headers[key] as? String {
                let trimmedString = sizeString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedString.isEmpty, let fileSize = Int64(trimmedString), fileSize > 0 else {
                    print("⚠️ [FileSizeChecker] Invalid size in \(key): '\(sizeString)'")
                    continue
                }
                
                if isCompressed {
                    print("⚠️ [FileSizeChecker] Content-Length shows compressed size (\(AppBundleStorageManager.formatBytes(fileSize))) - 압축으로 인해 실제 크기와 다를 수 있음")
                    // 압축된 경우에는 이 값을 신뢰하지 않고 다른 방법 시도
                    break
                } else {
                    print("✅ [FileSizeChecker] Found file size via \(key): \(AppBundleStorageManager.formatBytes(fileSize))")
                    return fileSize
                }
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
        print("🚨🚨🚨 [FileSizeChecker] getFileSizesBatch 호출됨!!! - \(urls.count)개 URL")
        NSLog("🚨 FileSizeChecker.getFileSizesBatch called with %d URLs", urls.count)
        
        guard !urls.isEmpty else {
            print("⚠️ [FileSizeChecker] 빈 URL 배열")
            return [:]
        }
        
        for (index, url) in urls.enumerated() {
            print("📎 [FileSizeChecker] URL \(index + 1): \(url)")
            NSLog("URL %d: %@", index + 1, url)
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
