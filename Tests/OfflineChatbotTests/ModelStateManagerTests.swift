import XCTest
import Foundation
@testable import OfflineChatbot

final class ModelStateManagerTests: XCTestCase {
    
    var modelStateManager: ModelStateManager!
    
    override func setUp() {
        super.setUp()
        modelStateManager = ModelStateManager.shared
    }
    
    override func tearDown() {
        modelStateManager.resetModelState()
        super.tearDown()
    }
    
    func testInitialState() {
        // Given & When
        let manager = ModelStateManager.shared
        
        // Then
        XCTAssertNotNil(manager.isModelReady)
        XCTAssertNotNil(manager.modelLoadingStatus)
    }
    
    func testUpdateModelStatusToReady() {
        // Given
        let expectation = XCTestExpectation(description: "Model status updated to ready")
        
        // When
        modelStateManager.updateModelStatus(.ready)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.modelStateManager.isModelReady)
            XCTAssertEqual(self.modelStateManager.modelLoadingStatus, .ready)
            XCTAssertNil(self.modelStateManager.lastLoadingError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateModelStatusToFailed() {
        // Given
        let expectation = XCTestExpectation(description: "Model status updated to failed")
        let testError = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        modelStateManager.setModelFailed(with: testError)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.modelStateManager.isModelReady)
            XCTAssertEqual(self.modelStateManager.modelLoadingStatus, .failed)
            XCTAssertNotNil(self.modelStateManager.lastLoadingError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSetModelReadyWithMetadata() {
        // Given
        let expectation = XCTestExpectation(description: "Model ready with metadata")
        let testURL = URL(fileURLWithPath: "/test/path")
        let metadata = ModelMetadata(
            modelName: "Test Model",
            modelURL: testURL,
            fileSize: 1000,
            specTier: .medium,
            downloadDate: Date(),
            isReady: true
        )
        
        // When
        modelStateManager.setModelReady(with: metadata)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.modelStateManager.isModelReady)
            XCTAssertEqual(self.modelStateManager.modelLoadingStatus, .ready)
            XCTAssertNotNil(self.modelStateManager.currentModelMetadata)
            XCTAssertEqual(self.modelStateManager.currentModelMetadata?.modelName, "Test Model")
            XCTAssertNil(self.modelStateManager.lastLoadingError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testResetModelState() {
        // Given
        modelStateManager.updateModelStatus(.ready)
        let expectation = XCTestExpectation(description: "Model state reset")
        
        // When
        modelStateManager.resetModelState()
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.modelStateManager.isModelReady)
            XCTAssertEqual(self.modelStateManager.modelLoadingStatus, .notLoaded)
            XCTAssertNil(self.modelStateManager.currentModelMetadata)
            XCTAssertNil(self.modelStateManager.lastLoadingError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testModelLoadingStatusTransitions() {
        // Given
        let expectation = XCTestExpectation(description: "Status transitions")
        
        // When & Then
        modelStateManager.updateModelStatus(.downloading)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.modelStateManager.modelLoadingStatus, .downloading)
            XCTAssertFalse(self.modelStateManager.isModelReady)
            
            self.modelStateManager.updateModelStatus(.loading)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(self.modelStateManager.modelLoadingStatus, .loading)
                XCTAssertFalse(self.modelStateManager.isModelReady)
                
                self.modelStateManager.updateModelStatus(.ready)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    XCTAssertEqual(self.modelStateManager.modelLoadingStatus, .ready)
                    XCTAssertTrue(self.modelStateManager.isModelReady)
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testNotificationHandling() {
        // Given
        let expectation = XCTestExpectation(description: "Notification handled")
        
        // When
        NotificationCenter.default.post(name: .modelDownloadStarted, object: nil)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(self.modelStateManager.modelLoadingStatus, .downloading)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRefreshModelState() {
        // Given
        // 실제 파일 시스템에 의존하므로, 메서드 호출만 검증
        
        // When & Then
        XCTAssertNoThrow(modelStateManager.refreshModelState())
    }
}