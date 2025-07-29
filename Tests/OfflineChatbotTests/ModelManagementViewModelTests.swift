import XCTest
import Foundation
import Combine
@testable import OfflineChatbot

final class ModelManagementViewModelTests: XCTestCase {
    
    var viewModel: ModelManagementViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        viewModel = ModelManagementViewModel()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialState() {
        // Given & When
        let vm = ModelManagementViewModel()
        
        // Then
        XCTAssertFalse(vm.isDownloading)
        XCTAssertEqual(vm.downloadProgress, 0.0)
        XCTAssertFalse(vm.showingError)
        XCTAssertFalse(vm.showingDeleteConfirmation)
        XCTAssertFalse(vm.isRetrying)
        XCTAssertEqual(vm.retryAttempt, 0)
        XCTAssertNil(vm.retryReason)
        XCTAssertNil(vm.errorMessage)
        XCTAssertNil(vm.modelToDelete)
    }
    
    func testAvailableModelsLoading() {
        // Given & When
        let models = viewModel.availableModels
        
        // Then
        XCTAssertEqual(models.count, 3, "3개의 모델(고/중/저사양)이 있어야 합니다")
        
        let tiers = models.map { $0.tier }
        XCTAssertTrue(tiers.contains(.high))
        XCTAssertTrue(tiers.contains(.medium))
        XCTAssertTrue(tiers.contains(.low))
    }
    
    func testModelInfoStructure() {
        // Given
        let models = viewModel.availableModels
        let highModel = models.first { $0.tier == .high }!
        let mediumModel = models.first { $0.tier == .medium }!
        let lowModel = models.first { $0.tier == .low }!
        
        // Then
        XCTAssertEqual(highModel.name, "Gemma 3n (고사양)")
        XCTAssertEqual(mediumModel.name, "Gemma 3n (중사양)")
        XCTAssertEqual(lowModel.name, "Gemma 3n (저사양)")
        
        XCTAssertTrue(highModel.downloadURL.contains("huggingface.co"))
        XCTAssertTrue(mediumModel.downloadURL.contains("huggingface.co"))
        XCTAssertTrue(lowModel.downloadURL.contains("huggingface.co"))
        
        XCTAssertGreaterThan(highModel.estimatedSize, mediumModel.estimatedSize)
        XCTAssertGreaterThan(mediumModel.estimatedSize, lowModel.estimatedSize)
    }
    
    func testGetRecommendedModel() {
        // Given & When
        let recommendedModel = viewModel.getRecommendedModel()
        
        // Then
        XCTAssertNotNil(recommendedModel)
        XCTAssertTrue([.high, .medium, .low].contains(recommendedModel?.tier))
    }
    
    func testToggleModelState() {
        // Given
        let model = viewModel.availableModels.first!
        let originalIsEnabled = model.isEnabled
        
        // When
        viewModel.toggleModel(model)
        
        // Then
        // Note: 실제 토글 동작은 모델이 다운로드된 경우에만 작동
        if model.isDownloaded {
            let updatedModel = viewModel.availableModels.first { $0.id == model.id }!
            XCTAssertEqual(updatedModel.isEnabled, !originalIsEnabled)
        }
    }
    
    func testDeleteModelConfirmation() {
        // Given
        let model = viewModel.availableModels.first!
        
        // When
        viewModel.deleteModel(model)
        
        // Then
        XCTAssertTrue(viewModel.showingDeleteConfirmation)
        XCTAssertNotNil(viewModel.modelToDelete)
        XCTAssertEqual(viewModel.modelToDelete?.id, model.id)
    }
    
    func testCancelDelete() {
        // Given
        let model = viewModel.availableModels.first!
        viewModel.deleteModel(model)
        
        // When
        viewModel.cancelDelete()
        
        // Then
        XCTAssertFalse(viewModel.showingDeleteConfirmation)
        XCTAssertNil(viewModel.modelToDelete)
    }
    
    func testShowError() {
        // Given
        let errorMessage = "Test error message"
        
        // When
        viewModel.showError(errorMessage)
        
        // Then
        XCTAssertTrue(viewModel.showingError)
        XCTAssertEqual(viewModel.errorMessage, errorMessage)
    }
    
    func testClearError() {
        // Given
        viewModel.showError("Test error")
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertFalse(viewModel.showingError)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testRefreshModelStates() {
        // Given & When
        XCTAssertNoThrow(viewModel.refreshModelStates())
        
        // Then
        // 실제 파일 시스템에 의존하므로 예외가 발생하지 않는지만 확인
    }
    
    func testModelInfoFileSize() {
        // Given
        let models = viewModel.availableModels
        
        // Then
        for model in models {
            XCTAssertFalse(model.sizeDescription.isEmpty, "파일 크기 설명이 비어있으면 안됩니다")
            XCTAssertGreaterThan(model.estimatedSize, 0, "예상 크기는 0보다 커야 합니다")
        }
    }
    
    func testModelTierConsistency() {
        // Given
        let models = viewModel.availableModels
        let highModel = models.first { $0.tier == .high }!
        let mediumModel = models.first { $0.tier == .medium }!
        let lowModel = models.first { $0.tier == .low }!
        
        // Then
        XCTAssertEqual(highModel.estimatedSize, 4_000_000_000)
        XCTAssertEqual(mediumModel.estimatedSize, 2_000_000_000)
        XCTAssertEqual(lowModel.estimatedSize, 1_000_000_000)
    }
    
    // MARK: - Private Methods Test Helper
    private extension ModelManagementViewModelTests {
        func simulateDownloadCompletion() {
            // Helper method for simulating download completion in tests
            viewModel.refreshModelStates()
        }
    }
}