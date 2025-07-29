import XCTest
import Foundation
import Network
@testable import MLModel

final class DownloadRetryManagerTests: XCTestCase {
    
    var retryManager: DownloadRetryManager!
    
    override func setUp() {
        super.setUp()
        retryManager = DownloadRetryManager()
    }
    
    override func tearDown() {
        retryManager.cancelRetry()
        retryManager = nil
        super.tearDown()
    }
    
    func testClassifyNetworkErrors() {
        // Given
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let serverError = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: nil)
        
        // When
        let networkReason = retryManager.classifyError(networkError)
        let timeoutReason = retryManager.classifyError(timeoutError)
        let serverReason = retryManager.classifyError(serverError)
        
        // Then
        XCTAssertEqual(networkReason, .networkError)
        XCTAssertEqual(timeoutReason, .timeout)
        XCTAssertEqual(serverReason, .serverError)
    }
    
    func testClassifyDiskErrors() {
        // Given
        let diskError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError, userInfo: nil)
        let corruptError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError, userInfo: nil)
        
        // When
        let diskReason = retryManager.classifyError(diskError)
        let corruptReason = retryManager.classifyError(corruptError)
        
        // Then
        XCTAssertEqual(diskReason, .diskError)
        XCTAssertEqual(corruptReason, .corruptedFile)
    }
    
    func testShouldRetryLogic() {
        // Given
        let networkReason = DownloadRetryManager.RetryReason.networkError
        let diskReason = DownloadRetryManager.RetryReason.diskError
        let timeoutReason = DownloadRetryManager.RetryReason.timeout
        
        // When & Then
        XCTAssertTrue(retryManager.shouldRetry(for: networkReason, attempt: 0))
        XCTAssertTrue(retryManager.shouldRetry(for: networkReason, attempt: 3))
        XCTAssertFalse(retryManager.shouldRetry(for: networkReason, attempt: 5))
        
        XCTAssertTrue(retryManager.shouldRetry(for: diskReason, attempt: 0))
        XCTAssertTrue(retryManager.shouldRetry(for: diskReason, attempt: 1))
        XCTAssertFalse(retryManager.shouldRetry(for: diskReason, attempt: 2))
        
        XCTAssertTrue(retryManager.shouldRetry(for: timeoutReason, attempt: 0))
        XCTAssertTrue(retryManager.shouldRetry(for: timeoutReason, attempt: 4))
        XCTAssertFalse(retryManager.shouldRetry(for: timeoutReason, attempt: 5))
    }
    
    func testCalculateBackoffDelay() {
        // Given & When
        let delay0 = retryManager.calculateBackoffDelay(attempt: 0)
        let delay1 = retryManager.calculateBackoffDelay(attempt: 1)
        let delay2 = retryManager.calculateBackoffDelay(attempt: 2)
        let delay3 = retryManager.calculateBackoffDelay(attempt: 3)
        
        // Then
        XCTAssertGreaterThanOrEqual(delay0, 2.0) // Base delay
        XCTAssertLessThanOrEqual(delay0, 3.0) // Base + jitter
        
        XCTAssertGreaterThanOrEqual(delay1, 4.0) // 2 * 2^1
        XCTAssertLessThanOrEqual(delay1, 5.0) // + jitter
        
        XCTAssertGreaterThanOrEqual(delay2, 8.0) // 2 * 2^2
        XCTAssertLessThanOrEqual(delay2, 9.0) // + jitter
        
        XCTAssertGreaterThanOrEqual(delay3, 16.0) // 2 * 2^3
        XCTAssertLessThanOrEqual(delay3, 17.0) // + jitter
    }
    
    func testBackoffDelayMaximum() {
        // Given
        let highAttempt = 10
        
        // When
        let delay = retryManager.calculateBackoffDelay(attempt: highAttempt)
        
        // Then
        XCTAssertLessThanOrEqual(delay, 60.0, "최대 지연시간은 60초를 넘지 않아야 합니다")
    }
    
    func testRetryReasonDescription() {
        // Given
        let reasons: [DownloadRetryManager.RetryReason] = [
            .networkError, .serverError, .diskError, .corruptedFile, .timeout, .unknown
        ]
        
        // Then
        for reason in reasons {
            XCTAssertFalse(reason.description.isEmpty, "\(reason) 설명이 비어있으면 안됩니다")
        }
    }
    
    func testScheduleRetryUpdatesState() {
        // Given
        let expectation = XCTestExpectation(description: "Retry state updated")
        let reason = DownloadRetryManager.RetryReason.networkError
        
        // When
        retryManager.scheduleRetry(for: reason, attempt: 0) {
            // Retry action
        }
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.retryManager.isRetrying)
            XCTAssertEqual(self.retryManager.retryAttempt, 1)
            XCTAssertEqual(self.retryManager.retryReason, reason.description)
            XCTAssertNotNil(self.retryManager.nextRetryTime)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCancelRetryResetsState() {
        // Given
        let reason = DownloadRetryManager.RetryReason.networkError
        retryManager.scheduleRetry(for: reason, attempt: 0) {}
        
        // When
        retryManager.cancelRetry()
        
        // Then
        let expectation = XCTestExpectation(description: "Cancel retry state reset")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.retryManager.isRetrying)
            XCTAssertEqual(self.retryManager.retryAttempt, 0)
            XCTAssertNil(self.retryManager.retryReason)
            XCTAssertNil(self.retryManager.nextRetryTime)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}