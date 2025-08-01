import Foundation

enum DownloadError: LocalizedError, Equatable, Sendable {
    case networkUnavailable
    case invalidURL
    case fileNotFound
    case insufficientStorage
    case downloadFailed(String)
    case integrityCheckFailed
    case unknown(String)
    case timeoutError
    case invalidResponse
    case fileSizeNotAvailable
    case downloadIncomplete(String)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "네트워크에 연결할 수 없습니다. 인터넷 연결을 확인해주세요."
        case .invalidURL:
            return "잘못된 다운로드 URL입니다."
        case .fileNotFound:
            return "다운로드할 파일을 찾을 수 없습니다."
        case .insufficientStorage:
            return "저장 공간이 부족합니다."
        case .downloadFailed(let reason):
            return "다운로드 실패: \(reason)"
        case .integrityCheckFailed:
            return "파일 무결성 검증에 실패했습니다."
        case .unknown(let reason):
            return "알 수 없는 오류: \(reason)"
        case .timeoutError:
            return "시간 초과"
        case .invalidResponse:
            return "잘못된 서버 응답"
        case .fileSizeNotAvailable:
            return "파일 크기를 확인할 수 없습니다"
        case .downloadIncomplete(let reason):
            return "다운로드 미완료: \(reason)"
        }
    }
}