import XCTest
@testable import OfflineChatbot

final class ChatViewModelTests: XCTestCase {
    var viewModel: ChatViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = ChatViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(viewModel.isGeneratingResponse)
        XCTAssertTrue(viewModel.currentInput.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingError)
        XCTAssertTrue(viewModel.currentSession.messages.isEmpty)
    }
    
    func testSendMessageWithEmptyInput() {
        viewModel.currentInput = ""
        let initialMessageCount = viewModel.currentSession.messages.count
        
        viewModel.sendMessage()
        
        XCTAssertEqual(viewModel.currentSession.messages.count, initialMessageCount)
        XCTAssertTrue(viewModel.currentInput.isEmpty)
    }
    
    func testSendMessageWithWhitespaceInput() {
        viewModel.currentInput = "   \n  "
        let initialMessageCount = viewModel.currentSession.messages.count
        
        viewModel.sendMessage()
        
        XCTAssertEqual(viewModel.currentSession.messages.count, initialMessageCount)
    }
    
    func testSendValidMessage() {
        viewModel.currentInput = "안녕하세요"
        
        viewModel.sendMessage()
        
        XCTAssertTrue(viewModel.currentInput.isEmpty)
        XCTAssertEqual(viewModel.currentSession.messages.count, 1)
        XCTAssertEqual(viewModel.currentSession.messages.first?.content, "안녕하세요")
        XCTAssertEqual(viewModel.currentSession.messages.first?.sender, .user)
    }
    
    func testClearChat() {
        viewModel.currentInput = "테스트 메시지"
        viewModel.sendMessage()
        
        XCTAssertFalse(viewModel.currentSession.messages.isEmpty)
        
        viewModel.clearChat()
        
        XCTAssertTrue(viewModel.currentSession.messages.isEmpty)
        XCTAssertEqual(viewModel.currentSession.title, "새 대화")
    }
    
    func testDeleteMessage() {
        let message = ChatMessage(content: "테스트 메시지", sender: .user)
        viewModel.currentSession.addMessage(message)
        
        XCTAssertEqual(viewModel.currentSession.messages.count, 1)
        
        viewModel.deleteMessage(message)
        
        XCTAssertTrue(viewModel.currentSession.messages.isEmpty)
    }
    
    func testCopyMessage() {
        let message = ChatMessage(content: "복사할 메시지", sender: .user)
        
        viewModel.copyMessage(message)
        
        XCTAssertEqual(UIPasteboard.general.string, "복사할 메시지")
    }
    
    func testGetFormattedTime() {
        let message = ChatMessage(content: "테스트", sender: .user, timestamp: Date())
        
        let formattedTime = viewModel.getFormattedTime(for: message)
        
        XCTAssertFalse(formattedTime.isEmpty)
    }
    
    func testGetInferenceTimeString() {
        let metadata = MessageMetadata(inferenceTime: 1.5)
        let message = ChatMessage(content: "테스트", sender: .assistant, metadata: metadata)
        
        let inferenceTimeString = viewModel.getInferenceTimeString(for: message)
        
        XCTAssertEqual(inferenceTimeString, "1.50초")
    }
    
    func testGetInferenceTimeStringWithoutMetadata() {
        let message = ChatMessage(content: "테스트", sender: .assistant)
        
        let inferenceTimeString = viewModel.getInferenceTimeString(for: message)
        
        XCTAssertNil(inferenceTimeString)
    }
    
    func testGetCurrentModelStatusOffline() {
        let status = viewModel.getCurrentModelStatus()
        
        // 네트워크가 연결되지 않은 상태에서는 오프라인 모델 상태를 반환해야 함
        XCTAssertTrue(status.contains("오프라인") || status.contains("로딩 필요"))
    }
}