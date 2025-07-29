import XCTest
@testable import OfflineChatbot
@testable import MLModel
@testable import NetworkManager

final class ChatViewModelInferenceTests: XCTestCase {
    var chatViewModel: ChatViewModel!
    var mockGemmaModel: MockGemmaModel!
    var mockNetworkManager: MockNetworkManager!
    
    override func setUp() {
        super.setUp()
        mockGemmaModel = MockGemmaModel()
        mockNetworkManager = MockNetworkManager()
        chatViewModel = ChatViewModel(
            gemmaModel: mockGemmaModel,
            networkManager: mockNetworkManager,
            apiKey: nil
        )
    }
    
    override func tearDown() {
        chatViewModel = nil
        mockGemmaModel = nil
        mockNetworkManager = nil
        super.tearDown()
    }
    
    // MARK: - Text Input Pipeline Tests
    
    func testSendMessage_ValidInput_CreatesUserMessage() {
        chatViewModel.currentInput = "안녕하세요"
        
        chatViewModel.sendMessage()
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        XCTAssertEqual(chatViewModel.currentSession.messages.first?.content, "안녕하세요")
        XCTAssertEqual(chatViewModel.currentSession.messages.first?.sender, .user)
        XCTAssertEqual(chatViewModel.currentInput, "")
    }
    
    func testSendMessage_EmptyInput_DoesNotCreateMessage() {
        chatViewModel.currentInput = ""
        
        chatViewModel.sendMessage()
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 0)
    }
    
    func testSendMessage_WhitespaceOnlyInput_DoesNotCreateMessage() {
        chatViewModel.currentInput = "   \n\t   "
        
        chatViewModel.sendMessage()
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 0)
    }
    
    // MARK: - Offline Inference Tests
    
    func testGenerateResponse_OfflineMode_UsesGemmaModel() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.mockResponse = "오프라인 응답입니다"
        
        await chatViewModel.generateResponse(for: "테스트 입력")
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        let assistantMessage = chatViewModel.currentSession.messages.first
        XCTAssertEqual(assistantMessage?.content, "오프라인 응답입니다")
        XCTAssertEqual(assistantMessage?.sender, .assistant)
        XCTAssertEqual(assistantMessage?.metadata?.modelUsed, "Gemma 3n (Local)")
        XCTAssertEqual(assistantMessage?.metadata?.isOffline, true)
    }
    
    func testGenerateResponse_ModelNotLoaded_ShowsError() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = false
        
        await chatViewModel.generateResponse(for: "테스트 입력")
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        let errorMessage = chatViewModel.currentSession.messages.first
        XCTAssertEqual(errorMessage?.messageType, .error)
        XCTAssertEqual(errorMessage?.status, .failed)
        XCTAssertTrue(chatViewModel.showingError)
    }
    
    // MARK: - Input Validation Tests
    
    func testGenerateResponse_InvalidInput_ShowsError() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        
        await chatViewModel.generateResponse(for: "")
        
        XCTAssertTrue(chatViewModel.showingError)
        XCTAssertNotNil(chatViewModel.errorMessage)
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 0)
    }
    
    func testGenerateResponse_TooLongInput_TruncatesInput() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.mockResponse = "긴 입력에 대한 응답"
        
        let longInput = String(repeating: "가", count: 3000)
        await chatViewModel.generateResponse(for: longInput)
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        let assistantMessage = chatViewModel.currentSession.messages.first
        XCTAssertEqual(assistantMessage?.content, "긴 입력에 대한 응답")
        XCTAssertEqual(assistantMessage?.status, .delivered)
    }
    
    // MARK: - Response Processing Tests
    
    func testGenerateResponse_EmptyModelResponse_ShowsDefaultMessage() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.mockResponse = ""
        
        await chatViewModel.generateResponse(for: "테스트 입력")
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        let assistantMessage = chatViewModel.currentSession.messages.first
        XCTAssertEqual(assistantMessage?.content, "죄송합니다. 응답을 생성할 수 없습니다.")
    }
    
    func testGenerateResponse_TooLongModelResponse_TruncatesResponse() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.mockResponse = String(repeating: "가", count: 1200)
        
        await chatViewModel.generateResponse(for: "테스트 입력")
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        let assistantMessage = chatViewModel.currentSession.messages.first
        XCTAssertTrue(assistantMessage?.content.hasSuffix("...") ?? false)
        XCTAssertLessThanOrEqual(assistantMessage?.content.count ?? 0, 1003)
    }
    
    // MARK: - Performance Tests
    
    func testGenerateResponse_OfflinePerformance_MeetsRequirement() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.mockResponse = "빠른 응답"
        mockGemmaModel.responseDelay = 1.5 // 1.5초 (2초 이하 요구사항)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        await chatViewModel.generateResponse(for: "성능 테스트")
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(totalTime, 2.0)
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        let assistantMessage = chatViewModel.currentSession.messages.first
        XCTAssertEqual(assistantMessage?.content, "빠른 응답")
        XCTAssertLessThan(assistantMessage?.metadata?.inferenceTime ?? 0, 2.0)
    }
    
    func testGenerateResponse_SlowOfflineResponse_LogsWarning() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.mockResponse = "느린 응답"
        mockGemmaModel.responseDelay = 3.0 // 3초 (2초 초과)
        
        await chatViewModel.generateResponse(for: "느린 테스트")
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        let assistantMessage = chatViewModel.currentSession.messages.first
        XCTAssertGreaterThan(assistantMessage?.metadata?.inferenceTime ?? 0, 2.0)
    }
    
    // MARK: - Context Building Tests
    
    func testGenerateResponse_WithContext_BuildsProperContext() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.mockResponse = "컨텍스트 응답"
        
        // 이전 대화 추가
        let userMessage1 = ChatMessage(content: "첫 번째 질문", sender: .user)
        let assistantMessage1 = ChatMessage(content: "첫 번째 답변", sender: .assistant)
        chatViewModel.currentSession.addMessage(userMessage1)
        chatViewModel.currentSession.addMessage(assistantMessage1)
        
        await chatViewModel.generateResponse(for: "두 번째 질문")
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 3)
        let lastMessage = chatViewModel.currentSession.messages.last
        XCTAssertEqual(lastMessage?.content, "컨텍스트 응답")
    }
    
    // MARK: - Error Handling Tests
    
    func testGenerateResponse_ModelError_HandlesGracefully() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.shouldThrowError = true
        
        await chatViewModel.generateResponse(for: "에러 테스트")
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        let errorMessage = chatViewModel.currentSession.messages.first
        XCTAssertEqual(errorMessage?.messageType, .error)
        XCTAssertEqual(errorMessage?.status, .failed)
        XCTAssertTrue(chatViewModel.showingError)
        XCTAssertNotNil(chatViewModel.errorMessage)
    }
    
    // MARK: - State Management Tests
    
    func testGenerateResponse_SetsLoadingState() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.mockResponse = "테스트 응답"
        mockGemmaModel.responseDelay = 1.0
        
        let expectation = XCTestExpectation(description: "Loading state set")
        
        Task {
            // 응답 생성 시작 후 즉시 로딩 상태 확인
            await chatViewModel.generateResponse(for: "로딩 테스트")
            expectation.fulfill()
        }
        
        // 짧은 지연 후 로딩 상태 확인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.chatViewModel.isGeneratingResponse)
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertFalse(chatViewModel.isGeneratingResponse)
    }
    
    // MARK: - Token Count Tests
    
    func testGenerateResponse_CountsTokensCorrectly() async {
        mockNetworkManager.isConnectedValue = false
        mockGemmaModel.isModelLoadedResult = true
        mockGemmaModel.mockResponse = "이것은 여섯 개의 토큰입니다"
        
        await chatViewModel.generateResponse(for: "토큰 테스트")
        
        XCTAssertEqual(chatViewModel.currentSession.messages.count, 1)
        let assistantMessage = chatViewModel.currentSession.messages.first
        XCTAssertEqual(assistantMessage?.metadata?.tokenCount, 6)
    }
}

// MARK: - Mock NetworkManager

class MockNetworkManager: NetworkManager {
    var isConnectedValue: Bool = false
    
    override var isConnected: Bool {
        return isConnectedValue
    }
}

// MARK: - Enhanced Mock GemmaModel

extension MockGemmaModel {
    var shouldThrowError: Bool = false
    
    override func generateResponse(for input: String) async throws -> String {
        if shouldThrowError {
            throw GemmaModel.ModelError.inferenceTimeout
        }
        
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        return mockResponse
    }
}