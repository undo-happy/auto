import XCTest
@testable import OfflineChatbot
@testable import MLModel

final class ModelInferenceServiceTests: XCTestCase {
    var inferenceService: ModelInferenceService!
    var mockGemmaModel: MockGemmaModel!
    
    override func setUp() {
        super.setUp()
        mockGemmaModel = MockGemmaModel()
        inferenceService = ModelInferenceService(gemmaModel: mockGemmaModel)
    }
    
    override func tearDown() {
        inferenceService = nil
        mockGemmaModel = nil
        super.tearDown()
    }
    
    // MARK: - Input Validation Tests
    
    func testValidateInput_ValidInput_Success() throws {
        let validInput = "안녕하세요, 어떻게 지내세요?"
        XCTAssertNoThrow(try inferenceService.validateInput(validInput))
    }
    
    func testValidateInput_EmptyInput_ThrowsError() {
        XCTAssertThrowsError(try inferenceService.validateInput("")) { error in
            guard case ModelInferenceService.InferenceError.invalidInput(let reason) = error else {
                XCTFail("Expected invalidInput error")
                return
            }
            XCTAssertTrue(reason.contains("비어있습니다"))
        }
    }
    
    func testValidateInput_WhitespaceOnlyInput_ThrowsError() {
        XCTAssertThrowsError(try inferenceService.validateInput("   \n\t   ")) { error in
            guard case ModelInferenceService.InferenceError.invalidInput = error else {
                XCTFail("Expected invalidInput error")
                return
            }
        }
    }
    
    func testValidateInput_TooLongInput_ThrowsError() {
        let longInput = String(repeating: "가", count: 2049)
        XCTAssertThrowsError(try inferenceService.validateInput(longInput)) { error in
            guard case ModelInferenceService.InferenceError.invalidInput(let reason) = error else {
                XCTFail("Expected invalidInput error")
                return
            }
            XCTAssertTrue(reason.contains("너무 깁니다"))
        }
    }
    
    func testValidateInput_ControlCharacters_ThrowsError() {
        let inputWithControlChar = "안녕하세요\u{0007}어떻게 지내세요?"
        XCTAssertThrowsError(try inferenceService.validateInput(inputWithControlChar)) { error in
            guard case ModelInferenceService.InferenceError.invalidInput(let reason) = error else {
                XCTFail("Expected invalidInput error")
                return
            }
            XCTAssertTrue(reason.contains("허용되지 않는 문자"))
        }
    }
    
    // MARK: - Preprocessing Tests
    
    func testPreprocessInput_NormalInput_ReturnsProcessed() {
        let input = "  안녕하세요   어떻게   지내세요?  "
        let processed = inferenceService.preprocessInput(input)
        XCTAssertEqual(processed, "안녕하세요 어떻게 지내세요?")
    }
    
    func testPreprocessInput_TooLongInput_ReturnsTruncated() {
        let longInput = String(repeating: "가", count: 2050)
        let processed = inferenceService.preprocessInput(longInput)
        XCTAssertEqual(processed.count, 2048)
    }
    
    func testPreprocessInput_MultipleSpaces_NormalizesSpaces() {
        let input = "안녕하세요     어떻게     지내세요?"
        let processed = inferenceService.preprocessInput(input)
        XCTAssertEqual(processed, "안녕하세요 어떻게 지내세요?")
    }
    
    // MARK: - Postprocessing Tests
    
    func testPostprocessResponse_NormalResponse_ReturnsProcessed() {
        let response = "안녕하세요! 저는 잘 지내고 있습니다."
        let processed = inferenceService.postprocessResponse(response)
        XCTAssertEqual(processed, response)
    }
    
    func testPostprocessResponse_EmptyResponse_ReturnsDefaultMessage() {
        let response = ""
        let processed = inferenceService.postprocessResponse(response)
        XCTAssertEqual(processed, "죄송합니다. 응답을 생성할 수 없습니다.")
    }
    
    func testPostprocessResponse_WhitespaceOnlyResponse_ReturnsDefaultMessage() {
        let response = "   \n\t   "
        let processed = inferenceService.postprocessResponse(response)
        XCTAssertEqual(processed, "죄송합니다. 응답을 생성할 수 없습니다.")
    }
    
    func testPostprocessResponse_TooLongResponse_ReturnsTruncated() {
        let longResponse = String(repeating: "가", count: 1001)
        let processed = inferenceService.postprocessResponse(longResponse)
        XCTAssertTrue(processed.hasSuffix("..."))
        XCTAssertEqual(processed.count, 1003) // 1000 + "..."
    }
    
    func testPostprocessResponse_ExcessiveNewlines_CleansNewlines() {
        let response = "첫 번째 줄\n\n\n\n\n두 번째 줄"
        let processed = inferenceService.postprocessResponse(response)
        XCTAssertEqual(processed, "첫 번째 줄\n\n두 번째 줄")
    }
    
    // MARK: - Integration Tests
    
    func testGenerateTextResponse_ValidInput_Success() async throws {
        mockGemmaModel.mockResponse = "테스트 응답입니다."
        mockGemmaModel.isModelLoadedResult = true
        
        let input = "안녕하세요"
        let response = try await inferenceService.generateTextResponse(for: input)
        
        XCTAssertEqual(response, "테스트 응답입니다.")
        XCTAssertFalse(inferenceService.isProcessing)
        XCTAssertEqual(inferenceService.processingProgress, 1.0)
    }
    
    func testGenerateTextResponse_ModelNotReady_ThrowsError() async {
        mockGemmaModel.isModelLoadedResult = false
        
        let input = "안녕하세요"
        
        do {
            _ = try await inferenceService.generateTextResponse(for: input)
            XCTFail("Expected modelNotReady error")
        } catch ModelInferenceService.InferenceError.modelNotReady {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testGenerateTextResponse_InvalidInput_ThrowsError() async {
        let input = ""
        
        do {
            _ = try await inferenceService.generateTextResponse(for: input)
            XCTFail("Expected invalidInput error")
        } catch ModelInferenceService.InferenceError.invalidInput {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testGenerateTextResponse_PerformanceTracking() async throws {
        mockGemmaModel.mockResponse = "테스트 응답"
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.responseDelay = 1.0 // 1초 지연
        
        let input = "성능 테스트"
        let startTime = CFAbsoluteTimeGetCurrent()
        
        _ = try await inferenceService.generateTextResponse(for: input)
        
        let actualTime = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertGreaterThan(inferenceService.lastProcessingTime, 0.9)
        XCTAssertLessThan(inferenceService.lastProcessingTime, 1.5)
        XCTAssertGreaterThan(actualTime, 0.9)
    }
    
    func testGenerateTextResponse_Timeout() async {
        mockGemmaModel.mockResponse = "테스트 응답"
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.responseDelay = 15.0 // 15초 지연 (타임아웃 초과)
        
        let input = "타임아웃 테스트"
        
        do {
            _ = try await inferenceService.generateTextResponse(for: input)
            XCTFail("Expected timeout error")
        } catch ModelInferenceService.InferenceError.inferenceTimeout {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Metrics Tests
    
    func testGetPerformanceMetrics_ReturnsValidMetrics() {
        let metrics = inferenceService.getPerformanceMetrics()
        
        XCTAssertEqual(metrics.lastProcessingTime, 0.0)
        XCTAssertFalse(metrics.isProcessing)
        XCTAssertNotNil(metrics.modelInfo)
    }
    
    func testPerformanceStatus_ExcellentPerformance() {
        let metrics = InferenceMetrics(
            lastProcessingTime: 1.5,
            isProcessing: false,
            modelInfo: ModelInfo(isLoaded: true, memoryUsage: 0, lastInferenceTime: 1.5, status: .loaded)
        )
        
        XCTAssertEqual(metrics.performanceStatus, .excellent)
        XCTAssertEqual(metrics.performanceStatus.description, "우수한 성능")
    }
    
    func testPerformanceStatus_GoodPerformance() {
        let metrics = InferenceMetrics(
            lastProcessingTime: 3.0,
            isProcessing: false,
            modelInfo: ModelInfo(isLoaded: true, memoryUsage: 0, lastInferenceTime: 3.0, status: .loaded)
        )
        
        XCTAssertEqual(metrics.performanceStatus, .good)
        XCTAssertEqual(metrics.performanceStatus.description, "양호한 성능")
    }
    
    func testPerformanceStatus_NeedsImprovement() {
        let metrics = InferenceMetrics(
            lastProcessingTime: 7.0,
            isProcessing: false,
            modelInfo: ModelInfo(isLoaded: true, memoryUsage: 0, lastInferenceTime: 7.0, status: .loaded)
        )
        
        XCTAssertEqual(metrics.performanceStatus, .needsImprovement)
        XCTAssertEqual(metrics.performanceStatus.description, "성능 개선 필요")
    }
}

// MARK: - Mock GemmaModel

class MockGemmaModel: GemmaModel {
    var mockResponse: String = "Mock response"
    var isModelLoadedResult: Bool = true
    var responseDelay: TimeInterval = 0.1
    
    override func isModelLoaded() -> Bool {
        return isModelLoadedResult
    }
    
    override func generateResponse(for input: String) async throws -> String {
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        return mockResponse
    }
    
    override func getModelInfo() -> ModelInfo {
        return ModelInfo(
            isLoaded: isModelLoadedResult,
            memoryUsage: 1024 * 1024 * 1024, // 1GB
            lastInferenceTime: responseDelay,
            status: isModelLoadedResult ? .loaded : .notLoaded
        )
    }
}