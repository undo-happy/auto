import XCTest
@testable import MLModel

final class ModelDownloaderTests: XCTestCase {
    var downloader: ModelDownloader!
    
    override func setUp() {
        super.setUp()
        downloader = ModelDownloader()
    }
    
    override func tearDown() {
        downloader = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(downloader.downloadProgress, 0.0)
        XCTAssertFalse(downloader.isDownloading)
        XCTAssertEqual(downloader.downloadStatus, .notStarted)
        XCTAssertNil(downloader.errorMessage)
    }
    
    func testCancelDownload() {
        downloader.cancelDownload()
        XCTAssertEqual(downloader.downloadStatus, .cancelled)
        XCTAssertFalse(downloader.isDownloading)
    }
    
    func testDownloadErrorTypes() {
        let invalidURLError = DownloadError.invalidURL
        XCTAssertEqual(invalidURLError.errorDescription, "유효하지 않은 모델 URL입니다.")
        
        let insufficientStorageError = DownloadError.insufficientStorage
        XCTAssertEqual(insufficientStorageError.errorDescription, "저장 공간이 부족합니다. 최소 2GB가 필요합니다.")
        
        let storageCheckError = DownloadError.storageCheckFailed
        XCTAssertEqual(storageCheckError.errorDescription, "저장 공간 확인에 실패했습니다.")
        
        let integrityError = DownloadError.integrityCheckFailed
        XCTAssertEqual(integrityError.errorDescription, "다운로드된 모델 파일의 무결성 검증에 실패했습니다.")
    }
}