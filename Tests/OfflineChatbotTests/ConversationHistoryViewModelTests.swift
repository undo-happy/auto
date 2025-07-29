import XCTest
import SwiftUI
import Combine
@testable import OfflineChatbot

@MainActor
final class ConversationHistoryViewModelTests: XCTestCase {
    
    var viewModel: ConversationHistoryViewModel!
    var mockHistoryService: MockConversationHistoryService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        super.setUp()
        
        mockHistoryService = MockConversationHistoryService()
        viewModel = ConversationHistoryViewModel(historyService: mockHistoryService)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
        mockHistoryService = nil
        cancellables?.removeAll()
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertTrue(viewModel.filteredSessions.isEmpty)
        XCTAssertNil(viewModel.selectedSession)
        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertEqual(viewModel.selectedFilter, .all)
        XCTAssertTrue(viewModel.selectedTags.isEmpty)
        XCTAssertEqual(viewModel.sortOption, .recentlyUpdated)
        XCTAssertNil(viewModel.dateRange)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showStatistics)
    }
    
    // MARK: - Session Management Tests
    
    func testCreateNewSession() async {
        // Given
        let title = "새로운 대화"
        let sessionType = SessionType.standard
        
        // When
        await viewModel.createNewSession(title: title, sessionType: sessionType)
        
        // Then
        XCTAssertNotNil(viewModel.selectedSession)
        XCTAssertEqual(viewModel.selectedSession?.title, title)
        XCTAssertEqual(SessionType(rawValue: viewModel.selectedSession?.sessionType ?? ""), sessionType)
    }
    
    func testCreateDefaultSession() async {
        // When
        await viewModel.createNewSession()
        
        // Then
        XCTAssertNotNil(viewModel.selectedSession)
        XCTAssertEqual(viewModel.selectedSession?.title, "새 대화")
        XCTAssertEqual(SessionType(rawValue: viewModel.selectedSession?.sessionType ?? ""), .standard)
    }
    
    func testSelectSession() {
        // Given
        let session = ConversationSession(
            id: "test-id",
            title: "테스트 세션"
        )
        
        // When
        viewModel.selectSession(session)
        
        // Then
        XCTAssertNotNil(viewModel.selectedSession)
        XCTAssertEqual(viewModel.selectedSession?.id, "test-id")
        XCTAssertEqual(viewModel.selectedSession?.title, "테스트 세션")
    }
    
    func testDeleteSession() async {
        // Given
        mockHistoryService.mockSessions = [
            ConversationSession(id: "1", title: "세션 1"),
            ConversationSession(id: "2", title: "세션 2")
        ]
        let sessionToDelete = "1"
        
        // When
        await viewModel.deleteSession(sessionToDelete)
        
        // Then
        XCTAssertTrue(mockHistoryService.deleteSessionCalled)
        XCTAssertEqual(mockHistoryService.deletedSessionId, sessionToDelete)
        XCTAssertTrue(mockHistoryService.loadStatisticsCalled)
    }
    
    // MARK: - Filter and Search Tests
    
    func testSearchQueryUpdate() {
        // Given
        let query = "테스트 검색어"
        let expectation = expectation(description: "Search query updated")
        
        viewModel.$searchQuery
            .dropFirst()
            .sink { updatedQuery in
                XCTAssertEqual(updatedQuery, query)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        viewModel.updateSearchQuery(query)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.searchQuery, query)
    }
    
    func testFilterChange() {
        // Given
        let filter = HistoryFilter.bookmarked
        let expectation = expectation(description: "Filter changed")
        
        viewModel.$selectedFilter
            .dropFirst()
            .sink { updatedFilter in
                XCTAssertEqual(updatedFilter, filter)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        viewModel.changeFilter(filter)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.selectedFilter, filter)
    }
    
    func testSortOptionChange() {
        // Given
        let sortOption = SortOption.alphabetical
        
        // When
        viewModel.changeSortOption(sortOption)
        
        // Then
        XCTAssertEqual(viewModel.sortOption, sortOption)
    }
    
    func testDateRangeSetting() {
        // Given
        let startDate = Date().addingTimeInterval(-86400) // 어제
        let endDate = Date() // 오늘
        let dateRange = DateInterval(start: startDate, end: endDate)
        
        // When
        viewModel.setDateRange(dateRange)
        
        // Then
        XCTAssertNotNil(viewModel.dateRange)
        XCTAssertEqual(viewModel.dateRange?.start, startDate)
        XCTAssertEqual(viewModel.dateRange?.end, endDate)
    }
    
    func testTagToggle() {
        // Given
        let tag = "개발"
        
        // When - 태그 추가
        viewModel.toggleTag(tag)
        
        // Then
        XCTAssertTrue(viewModel.selectedTags.contains(tag))
        
        // When - 태그 제거
        viewModel.toggleTag(tag)
        
        // Then
        XCTAssertFalse(viewModel.selectedTags.contains(tag))
    }
    
    func testClearAllFilters() {
        // Given - 필터 설정
        viewModel.searchQuery = "테스트"
        viewModel.selectedFilter = .bookmarked
        viewModel.selectedTags = ["태그1", "태그2"]
        viewModel.setDateRange(DateInterval(start: Date(), duration: 3600))
        
        // When
        viewModel.clearAllFilters()
        
        // Then
        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertEqual(viewModel.selectedFilter, .all)
        XCTAssertTrue(viewModel.selectedTags.isEmpty)
        XCTAssertNil(viewModel.dateRange)
    }
    
    // MARK: - Tag Management Tests
    
    func testAddTag() async {
        // Given
        let sessionId = "test-session"
        let tag = "새태그"
        
        // When
        await viewModel.addTag(to: sessionId, tag: tag)
        
        // Then
        XCTAssertTrue(mockHistoryService.addTagCalled)
        XCTAssertEqual(mockHistoryService.addTagSessionId, sessionId)
        XCTAssertEqual(mockHistoryService.addedTag, tag)
    }
    
    func testRemoveTag() async {
        // Given
        let sessionId = "test-session"
        let tag = "제거할태그"
        
        // When
        await viewModel.removeTag(from: sessionId, tag: tag)
        
        // Then
        XCTAssertTrue(mockHistoryService.removeTagCalled)
        XCTAssertEqual(mockHistoryService.removeTagSessionId, sessionId)
        XCTAssertEqual(mockHistoryService.removedTag, tag)
    }
    
    // MARK: - Bookmark Tests
    
    func testToggleBookmark() async {
        // Given
        let sessionId = "bookmarkable-session"
        
        // When
        await viewModel.toggleBookmark(for: sessionId)
        
        // Then
        XCTAssertTrue(mockHistoryService.toggleBookmarkCalled)
        XCTAssertEqual(mockHistoryService.bookmarkSessionId, sessionId)
    }
    
    // MARK: - Statistics Tests
    
    func testLoadStatistics() {
        // Given
        let expectedStats = HistoryStatistics(
            totalSessions: 5,
            totalMessages: 25,
            offlineSessions: 3,
            onlineSessions: 2,
            sessionsByType: [.standard: 5],
            oldestSession: Date().addingTimeInterval(-86400),
            newestSession: Date()
        )
        mockHistoryService.mockStatistics = expectedStats
        
        // When
        viewModel.loadStatistics()
        
        // Then
        XCTAssertEqual(viewModel.statistics.totalSessions, 5)
        XCTAssertEqual(viewModel.statistics.totalMessages, 25)
        XCTAssertEqual(viewModel.statistics.offlineSessions, 3)
        XCTAssertEqual(viewModel.statistics.onlineSessions, 2)
    }
    
    // MARK: - Export/Import Tests
    
    func testExportHistory() async {
        // Given
        let expectedData = "test export data".data(using: .utf8)!
        mockHistoryService.mockExportData = expectedData
        
        // When
        let result = await viewModel.exportHistory()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result, expectedData)
        XCTAssertTrue(mockHistoryService.exportCalled)
    }
    
    func testExportHistoryError() async {
        // Given
        mockHistoryService.shouldThrowExportError = true
        
        // When
        let result = await viewModel.exportHistory()
        
        // Then
        XCTAssertNil(result)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testImportHistory() async {
        // Given
        let importData = "test import data".data(using: .utf8)!
        let expectation = expectation(description: "Import completed")
        
        viewModel.$isLoading
            .dropFirst(2) // 초기값, true, false
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await viewModel.importHistory(from: importData)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(mockHistoryService.importCalled)
        XCTAssertEqual(mockHistoryService.importedData, importData)
        XCTAssertTrue(mockHistoryService.refreshCalled)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async {
        // Given
        mockHistoryService.shouldThrowError = true
        
        // When
        await viewModel.createNewSession()
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Mock error"))
    }
    
    func testErrorMessageBinding() {
        // Given
        let errorMessage = "Test error message"
        let expectation = expectation(description: "Error message received")
        
        viewModel.$errorMessage
            .dropFirst()
            .sink { message in
                XCTAssertEqual(message, errorMessage)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockHistoryService.errorMessage = errorMessage
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateBinding() {
        // Given
        let expectation = expectation(description: "Loading state changed")
        
        viewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                XCTAssertTrue(isLoading)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockHistoryService.isLoading = true
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Session Filtering Tests
    
    func testSessionFiltering() {
        // Given
        let sessions = [
            ConversationSession(id: "1", title: "일반 세션", sessionType: .standard),
            ConversationSession(id: "2", title: "다른 세션", sessionType: .standard),
            ConversationSession(id: "3", title: "음성 전용", sessionType: .voiceOnly)
        ]
        
        // 북마크 설정
        sessions[0].isBookmarked = true
        sessions[1].isOfflineSession = false // 온라인 세션
        
        mockHistoryService.mockSessions = sessions
        
        // When & Then - 전체 필터
        viewModel.selectedFilter = .all
        viewModel.refresh()
        // mockHistoryService는 모든 세션을 반환해야 함
        
        // When & Then - 북마크 필터
        viewModel.selectedFilter = .bookmarked
        viewModel.refresh()
        // 실제 필터링은 ConversationHistoryService에서 수행됨
        
        // When & Then - 세션 타입 필터
        viewModel.selectedFilter = .sessionType(.standard)
        viewModel.refresh()
        
        XCTAssertTrue(mockHistoryService.searchCalled)
    }
    
    // MARK: - Refresh Tests
    
    func testRefresh() {
        // When
        viewModel.refresh()
        
        // Then
        XCTAssertTrue(mockHistoryService.searchCalled)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetHandling() {
        // Given
        let largeSessions = (0..<1000).map { index in
            ConversationSession(
                id: "session-\(index)",
                title: "세션 \(index)",
                sessionType: .standard
            )
        }
        mockHistoryService.mockSessions = largeSessions
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        viewModel.refresh()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0, "대량 데이터 처리가 1초 이내에 완료되어야 함")
    }
}

// MARK: - Mock ConversationHistoryService

@MainActor
class MockConversationHistoryService: ConversationHistoryService, ObservableObject {
    
    // Mock data
    var mockSessions: [ConversationSession] = []
    var mockStatistics = HistoryStatistics(
        totalSessions: 0, totalMessages: 0, offlineSessions: 0,
        onlineSessions: 0, sessionsByType: [:],
        oldestSession: nil, newestSession: nil
    )
    var mockExportData: Data?
    
    // Control behavior
    var shouldThrowError = false
    var shouldThrowExportError = false
    
    // Track method calls
    var createSessionCalled = false
    var deleteSessionCalled = false
    var deletedSessionId: String?
    var addTagCalled = false
    var addTagSessionId: String?
    var addedTag: String?
    var removeTagCalled = false
    var removeTagSessionId: String?
    var removedTag: String?
    var toggleBookmarkCalled = false
    var bookmarkSessionId: String?
    var searchCalled = false
    var loadStatisticsCalled = false
    var exportCalled = false
    var importCalled = false
    var importedData: Data?
    var refreshCalled = false
    
    init() {
        let mockSecureStorage = MockSecureStorageService()
        try! super.init(secureStorage: mockSecureStorage)
    }
    
    override func createSession(
        title: String = "새 대화",
        sessionType: SessionType = .standard
    ) async throws -> ConversationSession {
        createSessionCalled = true
        
        if shouldThrowError {
            throw HistoryError.databaseError("Mock error")
        }
        
        let session = ConversationSession(
            title: title,
            sessionType: sessionType
        )
        currentSession = session
        return session
    }
    
    override func deleteSession(_ sessionId: String) async throws {
        deleteSessionCalled = true
        deletedSessionId = sessionId
        
        if shouldThrowError {
            throw HistoryError.sessionNotFound
        }
        
        mockSessions.removeAll { $0.id == sessionId }
        loadStatistics()
    }
    
    override func addTag(to sessionId: String, tag: String) async throws {
        addTagCalled = true
        addTagSessionId = sessionId
        addedTag = tag
        
        if shouldThrowError {
            throw HistoryError.sessionNotFound
        }
    }
    
    override func removeTag(from sessionId: String, tag: String) async throws {
        removeTagCalled = true
        removeTagSessionId = sessionId
        removedTag = tag
        
        if shouldThrowError {
            throw HistoryError.sessionNotFound
        }
    }
    
    override func toggleBookmark(for sessionId: String) async throws {
        toggleBookmarkCalled = true
        bookmarkSessionId = sessionId
        
        if shouldThrowError {
            throw HistoryError.sessionNotFound
        }
    }
    
    override func searchSessions(
        query: String,
        tags: [String] = [],
        sessionType: SessionType? = nil,
        dateRange: DateInterval? = nil
    ) async -> [ConversationSession] {
        searchCalled = true
        return mockSessions
    }
    
    override func getStatistics() -> HistoryStatistics {
        loadStatisticsCalled = true
        return mockStatistics
    }
    
    override func exportAllSessions() async throws -> Data {
        exportCalled = true
        
        if shouldThrowExportError {
            throw HistoryError.databaseError("Export failed")
        }
        
        return mockExportData ?? Data()
    }
    
    override func importSessions(from data: Data) async throws {
        importCalled = true
        importedData = data
        
        if shouldThrowError {
            throw HistoryError.databaseError("Import failed")
        }
    }
    
    func refresh() {
        refreshCalled = true
        // Mock implementation
        sessions = mockSessions
    }
}
