import XCTest
import RealmSwift
@testable import OfflineChatbot

@MainActor
final class ConversationHistoryServiceTests: XCTestCase {
    
    var historyService: ConversationHistoryService!
    var testRealm: Realm!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // 테스트용 인메모리 Realm 설정
        let config = Realm.Configuration(
            inMemoryIdentifier: "ConversationHistoryServiceTests",
            schemaVersion: 1
        )
        
        testRealm = try Realm(configuration: config)
        
        // 테스트용 SecureStorageService 생성
        let mockSecureStorage = MockSecureStorageService()
        historyService = try ConversationHistoryService(secureStorage: mockSecureStorage)
    }
    
    override func tearDownWithError() throws {
        historyService = nil
        testRealm = nil
        super.tearDown()
    }
    
    // MARK: - Session Management Tests
    
    func testCreateSession() async throws {
        // Given
        let title = "테스트 대화"
        let sessionType = SessionType.standard
        
        // When
        let session = try await historyService.createSession(
            title: title,
            sessionType: sessionType
        )
        
        // Then
        XCTAssertNotNil(session)
        XCTAssertEqual(session.title, title)
        XCTAssertEqual(SessionType(rawValue: session.sessionType), sessionType)
        XCTAssertTrue(session.isOfflineSession)
        XCTAssertEqual(session.messageCount, 0)
        XCTAssertTrue(session.messages.isEmpty)
    }
    
    func testCreateDefaultSession() async throws {
        // When
        let session = try await historyService.createSession()
        
        // Then
        XCTAssertEqual(session.title, "새 대화")
        XCTAssertEqual(SessionType(rawValue: session.sessionType), .standard)
        XCTAssertTrue(session.isOfflineSession)
    }
    
    func testDeleteSession() async throws {
        // Given
        let session = try await historyService.createSession(title: "삭제될 대화")
        let sessionId = session.id
        
        // When
        try await historyService.deleteSession(sessionId)
        
        // Then
        let sessions = await historyService.searchSessions(query: "", tags: [])
        XCTAssertFalse(sessions.contains { $0.id == sessionId })
    }
    
    func testDeleteNonExistentSession() async {
        // Given
        let nonExistentSessionId = "non-existent-id"
        
        // When & Then
        do {
            try await historyService.deleteSession(nonExistentSessionId)
            XCTFail("Expected HistoryError.sessionNotFound")
        } catch HistoryError.sessionNotFound {
            // Expected behavior
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Message Management Tests
    
    func testAddMessage() async throws {
        // Given
        let session = try await historyService.createSession(title: "메시지 테스트")
        let chatMessage = ChatMessage(
            content: "안녕하세요!",
            sender: .user,
            messageType: .text
        )
        
        // When
        try await historyService.addMessage(to: session.id, chatMessage: chatMessage)
        
        // Then
        let updatedSessions = await historyService.searchSessions(query: "", tags: [])
        let updatedSession = updatedSessions.first { $0.id == session.id }
        
        XCTAssertNotNil(updatedSession)
        XCTAssertEqual(updatedSession?.messageCount, 1)
        XCTAssertEqual(updatedSession?.messages.first?.content, "안녕하세요!")
    }
    
    func testAddMessageUpdatesSessionTitle() async throws {
        // Given
        let session = try await historyService.createSession() // "새 대화"
        let chatMessage = ChatMessage(
            content: "첫 번째 사용자 메시지",
            sender: .user,
            messageType: .text
        )
        
        // When
        try await historyService.addMessage(to: session.id, chatMessage: chatMessage)
        
        // Then
        let updatedSessions = await historyService.searchSessions(query: "", tags: [])
        let updatedSession = updatedSessions.first { $0.id == session.id }
        
        XCTAssertNotNil(updatedSession)
        XCTAssertEqual(updatedSession?.title, "첫 번째 사용자 메시지")
    }
    
    func testAddMessageToNonExistentSession() async {
        // Given
        let nonExistentSessionId = "non-existent-id"
        let chatMessage = ChatMessage(
            content: "테스트 메시지",
            sender: .user
        )
        
        // When & Then
        do {
            try await historyService.addMessage(to: nonExistentSessionId, chatMessage: chatMessage)
            XCTFail("Expected HistoryError.sessionNotFound")
        } catch HistoryError.sessionNotFound {
            // Expected behavior
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testUpdateMessage() async throws {
        // Given
        let session = try await historyService.createSession(title: "메시지 업데이트 테스트")
        let originalMessage = ChatMessage(
            content: "원본 메시지",
            sender: .user
        )
        
        try await historyService.addMessage(to: session.id, chatMessage: originalMessage)
        
        let updatedMessage = ChatMessage(
            id: originalMessage.id,
            content: "수정된 메시지",
            sender: .user,
            status: .delivered
        )
        
        // When
        try await historyService.updateMessage(
            messageId: originalMessage.id.uuidString,
            chatMessage: updatedMessage
        )
        
        // Then
        let sessions = await historyService.searchSessions(query: "", tags: [])
        let retrievedSession = sessions.first { $0.id == session.id }
        let retrievedMessage = retrievedSession?.messages.first
        
        XCTAssertEqual(retrievedMessage?.content, "수정된 메시지")
        XCTAssertEqual(MessageStatus(rawValue: retrievedMessage?.status ?? ""), .delivered)
    }
    
    func testDeleteMessage() async throws {
        // Given
        let session = try await historyService.createSession(title: "메시지 삭제 테스트")
        let message1 = ChatMessage(content: "첫 번째 메시지", sender: .user)
        let message2 = ChatMessage(content: "두 번째 메시지", sender: .assistant)
        
        try await historyService.addMessage(to: session.id, chatMessage: message1)
        try await historyService.addMessage(to: session.id, chatMessage: message2)
        
        // When
        try await historyService.deleteMessage(message1.id.uuidString)
        
        // Then
        let sessions = await historyService.searchSessions(query: "", tags: [])
        let updatedSession = sessions.first { $0.id == session.id }
        
        XCTAssertEqual(updatedSession?.messageCount, 1)
        XCTAssertEqual(updatedSession?.messages.first?.content, "두 번째 메시지")
    }
    
    // MARK: - Search Tests
    
    func testSearchByQuery() async throws {
        // Given
        let session1 = try await historyService.createSession(title: "파이썬 대화")
        let session2 = try await historyService.createSession(title: "자바 대화")
        
        let message1 = ChatMessage(content: "파이썬으로 웹 개발하기", sender: .user)
        let message2 = ChatMessage(content: "자바 스프링 부트 사용법", sender: .user)
        
        try await historyService.addMessage(to: session1.id, chatMessage: message1)
        try await historyService.addMessage(to: session2.id, chatMessage: message2)
        
        // When
        let pythonSessions = await historyService.searchSessions(query: "파이썬")
        let javaSessions = await historyService.searchSessions(query: "자바")
        let allSessions = await historyService.searchSessions(query: "")
        
        // Then
        XCTAssertEqual(pythonSessions.count, 1)
        XCTAssertEqual(pythonSessions.first?.id, session1.id)
        
        XCTAssertEqual(javaSessions.count, 1)
        XCTAssertEqual(javaSessions.first?.id, session2.id)
        
        XCTAssertEqual(allSessions.count, 2)
    }
    
    func testSearchBySessionType() async throws {
        // Given
        let standardSession = try await historyService.createSession(
            title: "표준 대화",
            sessionType: .standard
        )
        let voiceSession = try await historyService.createSession(
            title: "음성 대화",
            sessionType: .voiceOnly
        )
        
        // When
        let standardSessions = await historyService.searchSessions(
            query: "",
            sessionType: .standard
        )
        let voiceSessions = await historyService.searchSessions(
            query: "",
            sessionType: .voiceOnly
        )
        
        // Then
        XCTAssertEqual(standardSessions.count, 1)
        XCTAssertEqual(standardSessions.first?.id, standardSession.id)
        
        XCTAssertEqual(voiceSessions.count, 1)
        XCTAssertEqual(voiceSessions.first?.id, voiceSession.id)
    }
    
    func testSearchByDateRange() async throws {
        // Given
        let session = try await historyService.createSession(title: "날짜 테스트")
        
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let dateRange = DateInterval(start: yesterday, end: tomorrow)
        
        // When
        let sessionsInRange = await historyService.searchSessions(
            query: "",
            dateRange: dateRange
        )
        
        let pastDateRange = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            end: Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        )
        let sessionsNotInRange = await historyService.searchSessions(
            query: "",
            dateRange: pastDateRange
        )
        
        // Then
        XCTAssertEqual(sessionsInRange.count, 1)
        XCTAssertEqual(sessionsInRange.first?.id, session.id)
        XCTAssertEqual(sessionsNotInRange.count, 0)
    }
    
    // MARK: - Tag Management Tests
    
    func testAddTag() async throws {
        // Given
        let session = try await historyService.createSession(title: "태그 테스트")
        let tag = "개발"
        
        // When
        try await historyService.addTag(to: session.id, tag: tag)
        
        // Then
        let sessions = await historyService.searchSessions(query: "", tags: [tag])
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session.id)
        XCTAssertTrue(sessions.first?.tags.contains(tag) ?? false)
    }
    
    func testRemoveTag() async throws {
        // Given
        let session = try await historyService.createSession(title: "태그 제거 테스트")
        let tag = "임시태그"
        
        try await historyService.addTag(to: session.id, tag: tag)
        
        // When
        try await historyService.removeTag(from: session.id, tag: tag)
        
        // Then
        let sessions = await historyService.searchSessions(query: "", tags: [tag])
        XCTAssertEqual(sessions.count, 0)
    }
    
    func testSearchByTags() async throws {
        // Given
        let session1 = try await historyService.createSession(title: "개발 대화")
        let session2 = try await historyService.createSession(title: "디자인 대화")
        
        try await historyService.addTag(to: session1.id, tag: "개발")
        try await historyService.addTag(to: session1.id, tag: "프로그래밍")
        try await historyService.addTag(to: session2.id, tag: "디자인")
        
        // When
        let devSessions = await historyService.searchSessions(query: "", tags: ["개발"])
        let designSessions = await historyService.searchSessions(query: "", tags: ["디자인"])
        let multipleTags = await historyService.searchSessions(
            query: "",
            tags: ["개발", "프로그래밍"]
        )
        
        // Then
        XCTAssertEqual(devSessions.count, 1)
        XCTAssertEqual(devSessions.first?.id, session1.id)
        
        XCTAssertEqual(designSessions.count, 1)
        XCTAssertEqual(designSessions.first?.id, session2.id)
        
        XCTAssertEqual(multipleTags.count, 1)
        XCTAssertEqual(multipleTags.first?.id, session1.id)
    }
    
    // MARK: - Bookmark Tests
    
    func testToggleBookmark() async throws {
        // Given
        let session = try await historyService.createSession(title: "북마크 테스트")
        
        // When - 북마크 추가
        try await historyService.toggleBookmark(for: session.id)
        
        // Then
        var sessions = await historyService.searchSessions(query: "", tags: [])
        var updatedSession = sessions.first { $0.id == session.id }
        XCTAssertTrue(updatedSession?.isBookmarked ?? false)
        
        // When - 북마크 제거
        try await historyService.toggleBookmark(for: session.id)
        
        // Then
        sessions = await historyService.searchSessions(query: "", tags: [])
        updatedSession = sessions.first { $0.id == session.id }
        XCTAssertFalse(updatedSession?.isBookmarked ?? true)
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics() async throws {
        // Given
        let standardSession = try await historyService.createSession(
            title: "표준 대화",
            sessionType: .standard
        )
        let voiceSession = try await historyService.createSession(
            title: "음성 대화",
            sessionType: .voiceOnly
        )
        
        let message1 = ChatMessage(content: "메시지 1", sender: .user)
        let message2 = ChatMessage(content: "메시지 2", sender: .assistant)
        let message3 = ChatMessage(content: "메시지 3", sender: .user)
        
        try await historyService.addMessage(to: standardSession.id, chatMessage: message1)
        try await historyService.addMessage(to: standardSession.id, chatMessage: message2)
        try await historyService.addMessage(to: voiceSession.id, chatMessage: message3)
        
        // When
        let statistics = historyService.getStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalSessions, 2)
        XCTAssertEqual(statistics.totalMessages, 3)
        XCTAssertEqual(statistics.offlineSessions, 2) // 기본적으로 오프라인 세션
        XCTAssertEqual(statistics.onlineSessions, 0)
        XCTAssertEqual(statistics.sessionsByType[.standard], 1)
        XCTAssertEqual(statistics.sessionsByType[.voiceOnly], 1)
    }
    
    // MARK: - Export/Import Tests
    
    func testExportSessions() async throws {
        // Given
        let session = try await historyService.createSession(title: "내보내기 테스트")
        let message = ChatMessage(content: "테스트 메시지", sender: .user)
        
        try await historyService.addMessage(to: session.id, chatMessage: message)
        try await historyService.addTag(to: session.id, tag: "테스트")
        
        // When
        let exportData = try await historyService.exportAllSessions()
        
        // Then
        XCTAssertGreaterThan(exportData.count, 0)
        
        // JSON 파싱 검증
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let chatSessions = try decoder.decode([ChatSession].self, from: exportData)
        XCTAssertEqual(chatSessions.count, 1)
        
        let exportedSession = chatSessions.first!
        XCTAssertEqual(exportedSession.title, "내보내기 테스트")
        XCTAssertEqual(exportedSession.messages.count, 1)
        XCTAssertEqual(exportedSession.tags, ["테스트"])
    }
    
    func testImportSessions() async throws {
        // Given
        let chatSession = ChatSession(
            title: "가져온 대화",
            messages: [
                ChatMessage(content: "가져온 메시지", sender: .user)
            ],
            tags: ["가져오기"],
            isOfflineSession: true
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let importData = try encoder.encode([chatSession])
        
        // When
        try await historyService.importSessions(from: importData)
        
        // Then
        let sessions = await historyService.searchSessions(query: "가져온")
        XCTAssertEqual(sessions.count, 1)
        
        let importedSession = sessions.first!
        XCTAssertEqual(importedSession.title, "가져온 대화")
        XCTAssertEqual(importedSession.messageCount, 1)
        XCTAssertTrue(importedSession.tags.contains("가져오기"))
    }
    
    // MARK: - Error Handling Tests
    
    func testSessionNotFoundErrors() async {
        let nonExistentId = "non-existent-id"
        
        // Delete session
        await XCTAssertThrowsError(
            try await historyService.deleteSession(nonExistentId)
        ) { error in
            XCTAssertTrue(error is HistoryError)
            XCTAssertEqual(error as? HistoryError, HistoryError.sessionNotFound)
        }
        
        // Add message
        let message = ChatMessage(content: "테스트", sender: .user)
        await XCTAssertThrowsError(
            try await historyService.addMessage(to: nonExistentId, chatMessage: message)
        ) { error in
            XCTAssertTrue(error is HistoryError)
            XCTAssertEqual(error as? HistoryError, HistoryError.sessionNotFound)
        }
        
        // Add tag
        await XCTAssertThrowsError(
            try await historyService.addTag(to: nonExistentId, tag: "테스트")
        ) { error in
            XCTAssertTrue(error is HistoryError)
            XCTAssertEqual(error as? HistoryError, HistoryError.sessionNotFound)
        }
        
        // Remove tag
        await XCTAssertThrowsError(
            try await historyService.removeTag(from: nonExistentId, tag: "테스트")
        ) { error in
            XCTAssertTrue(error is HistoryError)
            XCTAssertEqual(error as? HistoryError, HistoryError.sessionNotFound)
        }
        
        // Toggle bookmark
        await XCTAssertThrowsError(
            try await historyService.toggleBookmark(for: nonExistentId)
        ) { error in
            XCTAssertTrue(error is HistoryError)
            XCTAssertEqual(error as? HistoryError, HistoryError.sessionNotFound)
        }
    }
    
    func testMessageNotFoundError() async {
        let nonExistentMessageId = "non-existent-message-id"
        let message = ChatMessage(content: "테스트", sender: .user)
        
        await XCTAssertThrowsError(
            try await historyService.updateMessage(messageId: nonExistentMessageId, chatMessage: message)
        ) { error in
            XCTAssertTrue(error is HistoryError)
            XCTAssertEqual(error as? HistoryError, HistoryError.messageNotFound)
        }
        
        await XCTAssertThrowsError(
            try await historyService.deleteMessage(nonExistentMessageId)
        ) { error in
            XCTAssertTrue(error is HistoryError)
            XCTAssertEqual(error as? HistoryError, HistoryError.messageNotFound)
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetPerformance() async throws {
        // Given
        let sessionCount = 100
        let messagesPerSession = 20
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<sessionCount {
            let session = try await historyService.createSession(title: "세션 \(i)")
            
            for j in 0..<messagesPerSession {
                let message = ChatMessage(
                    content: "메시지 \(j) in 세션 \(i)",
                    sender: j % 2 == 0 ? .user : .assistant
                )
                try await historyService.addMessage(to: session.id, chatMessage: message)
            }
        }
        
        let creationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(creationTime, 30.0, "대량 데이터 생성이 30초 이내에 완료되어야 함")
        
        // Search performance test
        let searchStartTime = CFAbsoluteTimeGetCurrent()
        let searchResults = await historyService.searchSessions(query: "메시지")
        let searchTime = CFAbsoluteTimeGetCurrent() - searchStartTime
        
        XCTAssertLessThan(searchTime, 2.0, "검색이 2초 이내에 완료되어야 함")
        XCTAssertEqual(searchResults.count, sessionCount)
        
        // Statistics performance test
        let statsStartTime = CFAbsoluteTimeGetCurrent()
        let statistics = historyService.getStatistics()
        let statsTime = CFAbsoluteTimeGetCurrent() - statsStartTime
        
        XCTAssertLessThan(statsTime, 1.0, "통계 계산이 1초 이내에 완료되어야 함")
        XCTAssertEqual(statistics.totalSessions, sessionCount)
        XCTAssertEqual(statistics.totalMessages, sessionCount * messagesPerSession)
    }
}

// MARK: - Mock SecureStorageService

class MockSecureStorageService: SecureStorageServiceProtocol {
    private var storage: [String: Data] = [:]
    
    func store<T: Codable>(_ data: T, for key: String) async throws {
        let encoded = try JSONEncoder().encode(data)
        storage[key] = encoded
    }
    
    func retrieve<T: Codable>(_ type: T.Type, for key: String) async throws -> T? {
        guard let data = storage[key] else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }
    
    func delete(for key: String) async throws {
        storage.removeValue(forKey: key)
    }
    
    func deleteAll() async throws {
        storage.removeAll()
    }
    
    func exists(for key: String) async throws -> Bool {
        return storage[key] != nil
    }
    
    func encrypt(_ data: Data) throws -> Data {
        return data // Mock implementation - no actual encryption
    }
    
    func decrypt(_ encryptedData: Data) throws -> Data {
        return encryptedData // Mock implementation - no actual decryption
    }
    
    func encrypt(_ data: Data, with key: Data) throws -> Data {
        return data // Mock implementation
    }
    
    func decrypt(_ encryptedData: Data, with key: Data) throws -> Data {
        return encryptedData // Mock implementation
    }
    
    func getOrCreateEncryptionKey() throws -> Data {
        return Data(repeating: 0, count: 32) // Mock key
    }
}

// MARK: - Test Helper Extensions

extension XCTTestCase {
    func XCTAssertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}
