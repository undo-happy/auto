import XCTest
@testable import MLModel

final class MLModelTests: XCTestCase {
    var gemmaModel: GemmaModel!
    
    override func setUp() {
        super.setUp()
        gemmaModel = GemmaModel()
    }
    
    override func tearDown() {
        gemmaModel = nil
        super.tearDown()
    }
    
    func testGemmaModelInitialization() throws {
        XCTAssertFalse(gemmaModel.isModelLoaded())
        XCTAssertEqual(gemmaModel.modelStatus, .notLoaded)
        XCTAssertFalse(gemmaModel.isLoading)
        XCTAssertEqual(gemmaModel.loadingProgress, 0.0)
    }
    
    func testModelInfo() throws {
        let modelInfo = gemmaModel.getModelInfo()
        XCTAssertFalse(modelInfo.isLoaded)
        XCTAssertEqual(modelInfo.memoryUsage, 0)
        XCTAssertEqual(modelInfo.lastInferenceTime, 0.0)
    }
    
    func testUnloadModel() throws {
        gemmaModel.unloadModel()
        XCTAssertFalse(gemmaModel.isModelLoaded())
        XCTAssertEqual(gemmaModel.modelStatus, .notLoaded)
    }
    
    func testModelErrors() throws {
        let fileNotFoundError = GemmaModel.ModelError.modelFileNotFound
        XCTAssertEqual(fileNotFoundError.errorDescription, "모델 파일을 찾을 수 없습니다.")
        
        let loadingFailedError = GemmaModel.ModelError.modelLoadingFailed("테스트 오류")
        XCTAssertEqual(loadingFailedError.errorDescription, "모델 로딩 실패: 테스트 오류")
        
        let memoryError = GemmaModel.ModelError.memoryInsufficicient
        XCTAssertEqual(memoryError.errorDescription, "메모리가 부족합니다.")
        
        let timeoutError = GemmaModel.ModelError.inferenceTimeout
        XCTAssertEqual(timeoutError.errorDescription, "추론 시간이 초과되었습니다.")
        
        let invalidInputError = GemmaModel.ModelError.invalidInput
        XCTAssertEqual(invalidInputError.errorDescription, "유효하지 않은 입력입니다.")
    }
    
    func testGenerateResponseWithoutModel() async throws {
        do {
            _ = try await gemmaModel.generateResponse(for: "안녕하세요")
            XCTFail("모델이 로드되지 않았는데 응답을 생성했습니다.")
        } catch GemmaModel.ModelError.modelFileNotFound {
            // 예상된 오류
        } catch {
            XCTFail("예상치 못한 오류: \(error)")
        }
    }
    
    func testGenerateResponseWithEmptyInput() async throws {
        // 실제 테스트에서는 모델을 먼저 로드해야 함
        // 여기서는 빈 입력에 대한 오류 처리만 테스트
        do {
            _ = try await gemmaModel.generateResponse(for: "")
            XCTFail("빈 입력으로 응답을 생성했습니다.")
        } catch GemmaModel.ModelError.invalidInput {
            // 예상된 오류 (모델이 로드되지 않았으므로 modelFileNotFound가 먼저 발생할 수 있음)
        } catch GemmaModel.ModelError.modelFileNotFound {
            // 모델이 로드되지 않은 경우의 예상된 오류
        } catch {
            XCTFail("예상치 못한 오류: \(error)")
        }
    }
    
    func testMemoryUsageFormatting() throws {
        let modelInfo = ModelInfo(
            isLoaded: true,
            memoryUsage: 1024 * 1024 * 1024, // 1GB
            lastInferenceTime: 1.5,
            status: .loaded
        )
        
        let formattedMemory = modelInfo.memoryUsageString
        XCTAssertTrue(formattedMemory.contains("GB") || formattedMemory.contains("MB"))
    }
}