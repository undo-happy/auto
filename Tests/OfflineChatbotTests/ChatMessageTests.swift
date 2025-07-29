import XCTest
@testable import OfflineChatbot

final class ChatMessageTests: XCTestCase {
    
    func testChatMessageInitialization() {
        let message = ChatMessage(content: "테스트 메시지", sender: .user)
        
        XCTAssertFalse(message.id.uuidString.isEmpty)
        XCTAssertEqual(message.content, "테스트 메시지")
        XCTAssertEqual(message.sender, .user)
        XCTAssertEqual(message.messageType, .text)
        XCTAssertEqual(message.status, .sent)
        XCTAssertNil(message.metadata)
    }
    
    func testMessageSenderProperties() {
        XCTAssertEqual(MessageSender.user.displayName, "사용자")
        XCTAssertEqual(MessageSender.assistant.displayName, "AI")
        XCTAssertEqual(MessageSender.system.displayName, "시스템")
        
        XCTAssertTrue(MessageSender.user.isFromUser)
        XCTAssertFalse(MessageSender.assistant.isFromUser)
        XCTAssertFalse(MessageSender.system.isFromUser)
    }
    
    func testMessageTypeIcons() {
        XCTAssertEqual(MessageType.text.icon, "text.bubble")
        XCTAssertEqual(MessageType.image.icon, "photo")
        XCTAssertEqual(MessageType.audio.icon, "mic")
        XCTAssertEqual(MessageType.system.icon, "info.circle")
        XCTAssertEqual(MessageType.error.icon, "exclamationmark.triangle")
    }
    
    func testMessageStatusDescriptions() {
        XCTAssertEqual(MessageStatus.sending.description, "전송 중")
        XCTAssertEqual(MessageStatus.sent.description, "전송됨")
        XCTAssertEqual(MessageStatus.delivered.description, "전달됨")
        XCTAssertEqual(MessageStatus.failed.description, "실패")
        XCTAssertEqual(MessageStatus.generating.description, "생성 중")
    }
    
    func testMessageMetadata() {
        let metadata = MessageMetadata(
            inferenceTime: 1.5,
            modelUsed: "Gemma 3n",
            tokenCount: 50,
            isOffline: true
        )
        
        XCTAssertEqual(metadata.inferenceTime, 1.5)
        XCTAssertEqual(metadata.modelUsed, "Gemma 3n")
        XCTAssertEqual(metadata.tokenCount, 50)
        XCTAssertTrue(metadata.isOffline)
        XCTAssertNil(metadata.errorDetails)
    }
    
    func testChatSessionInitialization() {
        let session = ChatSession()
        
        XCTAssertFalse(session.id.uuidString.isEmpty)
        XCTAssertEqual(session.title, "새 대화")
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertTrue(session.tags.isEmpty)
        XCTAssertTrue(session.isOfflineSession)
        XCTAssertEqual(session.messageCount, 0)
        XCTAssertNil(session.lastMessage)
    }
    
    func testChatSessionAddMessage() {
        var session = ChatSession()
        let message = ChatMessage(content: "첫 번째 메시지", sender: .user)
        
        session.addMessage(message)
        
        XCTAssertEqual(session.messageCount, 1)
        XCTAssertEqual(session.lastMessage?.content, "첫 번째 메시지")
        XCTAssertEqual(session.title, "첫 번째 메시지")
    }
    
    func testChatSessionUpdateMessage() {
        var session = ChatSession()
        let originalMessage = ChatMessage(content: "원본 메시지", sender: .user)
        session.addMessage(originalMessage)
        
        let updatedMessage = ChatMessage(
            id: originalMessage.id,
            content: "업데이트된 메시지",
            sender: .user,
            timestamp: originalMessage.timestamp
        )
        
        session.updateMessage(updatedMessage)
        
        XCTAssertEqual(session.messages.first?.content, "업데이트된 메시지")
    }
    
    func testChatSessionDeleteMessage() {
        var session = ChatSession()
        let message1 = ChatMessage(content: "메시지 1", sender: .user)
        let message2 = ChatMessage(content: "메시지 2", sender: .user)
        
        session.addMessage(message1)
        session.addMessage(message2)
        
        XCTAssertEqual(session.messageCount, 2)
        
        session.deleteMessage(withId: message1.id)
        
        XCTAssertEqual(session.messageCount, 1)
        XCTAssertEqual(session.messages.first?.content, "메시지 2")
    }
    
    func testChatSessionGetContext() {
        var session = ChatSession()
        
        // 시스템 메시지와 사용자/AI 메시지 추가
        session.addMessage(ChatMessage(content: "시스템 메시지", sender: .system, messageType: .system))
        session.addMessage(ChatMessage(content: "사용자 메시지 1", sender: .user))
        session.addMessage(ChatMessage(content: "AI 응답 1", sender: .assistant))
        session.addMessage(ChatMessage(content: "사용자 메시지 2", sender: .user))
        
        let context = session.getContext(maxMessages: 3)
        
        // 시스템 메시지는 제외되고 최근 3개만 반환되어야 함
        XCTAssertEqual(context.count, 3)
        XCTAssertEqual(context[0].content, "사용자 메시지 1")
        XCTAssertEqual(context[1].content, "AI 응답 1")
        XCTAssertEqual(context[2].content, "사용자 메시지 2")
    }
    
    func testChatSessionTitleGeneration() {
        var session = ChatSession()
        let longMessage = String(repeating: "가", count: 50)
        let message = ChatMessage(content: longMessage, sender: .user)
        
        session.addMessage(message)
        
        // 제목은 30자로 제한되어야 함
        XCTAssertEqual(session.title.count, 30)
        XCTAssertTrue(session.title.hasPrefix("가가가"))
    }
}