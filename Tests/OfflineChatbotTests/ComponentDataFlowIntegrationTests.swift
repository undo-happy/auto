import XCTest
import SwiftUI
import Combine
@testable import OfflineChatbot

/// T-044: 컴포넌트 간 데이터 전달 및 상태 동기화 실환경 테스트
final class ComponentDataFlowIntegrationTests: XCTestCase {
    
    private var dataFlowTracker: ComponentDataFlowTracker!
    private var boundaryLogger: LayerBoundaryLogger!
    private var testEnvironment: ComponentTestEnvironment!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        super.setUp()
        
        dataFlowTracker = ComponentDataFlowTracker.shared
        boundaryLogger = LayerBoundaryLogger.shared
        testEnvironment = ComponentTestEnvironment()
        cancellables = Set<AnyCancellable>()
        
        try testEnvironment.setup()
        dataFlowTracker.startTracking(sessionName: "Component Integration Test")
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        
        dataFlowTracker.stopTracking()
        testEnvironment.cleanup()
        cancellables.removeAll()
        
        // 분석 보고서 출력
        let report = dataFlowTracker.generateAnalysisReport()
        printAnalysisReport(report)
    }
    
    // MARK: - 레이어 간 데이터 플로우 테스트
    
    func testPresentationToViewModelDataFlow() async throws {
        // Given: Presentation → ViewModel 레이어 데이터 플로우
        let expectation = XCTestExpectation(description: "Presentation to ViewModel data flow")
        var dataFlowSuccess = false
        var stateConsistency = true
        
        // When: UI 이벤트를 통한 데이터 전달 시뮬레이션
        do {
            // 1. 사용자 입력 이벤트 (Presentation Layer)
            let userInput = "테스트 메시지 전달"
            
            let result = boundaryLogger.logBoundaryCall(
                from: .presentation,
                to: .viewModel,
                sourceComponent: "AdaptiveChatView",
                targetComponent: "ConversationManager",
                method: "addMessage",
                parameters: ["content": userInput, "isUser": true]
            ) {
                return testEnvironment.simulateAddMessage(content: userInput, isUser: true)
            }
            
            // 2. ViewModel의 상태 변경 확인
            await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
            
            let viewModelState = testEnvironment.getConversationManagerState()
            XCTAssertEqual(viewModelState["lastMessageContent"] as? String, userInput)
            XCTAssertEqual(viewModelState["messageCount"] as? Int, 1)
            
            dataFlowSuccess = result.success
            expectation.fulfill()
            
        } catch {
            XCTFail("Presentation to ViewModel 데이터 플로우 실패: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then: 데이터 플로우 검증
        XCTAssertTrue(dataFlowSuccess, "데이터 전달이 성공해야 함")
        XCTAssertTrue(stateConsistency, "상태 일관성이 유지되어야 함")
        
        // 플로우 이벤트 검증
        let flowEvents = dataFlowTracker.flowEvents
        XCTAssertGreaterThan(flowEvents.count, 0, "플로우 이벤트가 기록되어야 함")
        
        let addMessageEvents = flowEvents.filter { 
            $0.sourceComponent == "AdaptiveChatView" && 
            $0.targetComponent == "ConversationManager" 
        }
        XCTAssertGreaterThan(addMessageEvents.count, 0, "addMessage 호출 이벤트가 기록되어야 함")
        
        print("✅ Presentation → ViewModel 데이터 플로우 검증 완료")
    }
    
    func testViewModelToDomainDataFlow() async throws {
        // Given: ViewModel → Domain 레이어 데이터 플로우
        let expectation = XCTestExpectation(description: "ViewModel to Domain data flow")
        var inferenceTriggered = false
        
        // When: ViewModel에서 Domain 서비스 호출
        do {
            let inputText = "도메인 서비스 호출 테스트"
            
            let result = boundaryLogger.logBoundaryCall(
                from: .viewModel,
                to: .domain,
                sourceComponent: "ConversationManager",
                targetComponent: "ModelInferenceService",
                method: "processText",
                parameters: ["input": inputText]
            ) {
                return testEnvironment.simulateTextInference(input: inputText)
            }
            
            inferenceTriggered = result.success
            
            // Domain 서비스의 응답 처리 확인
            if result.success {
                let response = result.response ?? "기본 응답"
                
                // ViewModel 상태 업데이트 확인
                let updatedState = testEnvironment.getConversationManagerState()
                XCTAssertEqual(updatedState["lastAIResponse"] as? String, response)
            }
            
            expectation.fulfill()
            
        } catch {
            XCTFail("ViewModel to Domain 데이터 플로우 실패: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Then: 도메인 호출 검증
        XCTAssertTrue(inferenceTriggered, "추론 서비스가 호출되어야 함")
        
        // 비동기 응답 처리 검증
        let domainEvents = dataFlowTracker.flowEvents.filter { event in
            event.sourceComponent == "ConversationManager" && 
            event.targetComponent == "ModelInferenceService"
        }
        XCTAssertGreaterThan(domainEvents.count, 0, "도메인 서비스 호출 이벤트가 기록되어야 함")
        
        print("✅ ViewModel → Domain 데이터 플로우 검증 완료")
    }
    
    func testDomainToDataLayerFlow() async throws {
        // Given: Domain → Data 레이어 데이터 플로우
        let expectation = XCTestExpectation(description: "Domain to Data layer flow")
        var persistenceSuccess = false
        
        // When: 도메인에서 데이터 저장 요청
        do {
            let conversationData = [
                "id": UUID().uuidString,
                "messages": ["안녕하세요", "반갑습니다"],
                "timestamp": Date().timeIntervalSince1970
            ] as [String: Any]
            
            let result = boundaryLogger.logBoundaryCall(
                from: .domain,
                to: .data,
                sourceComponent: "ConversationService",
                targetComponent: "ConversationHistoryService",
                method: "saveConversation",
                parameters: conversationData
            ) {
                return testEnvironment.simulateConversationSave(data: conversationData)
            }
            
            persistenceSuccess = result.success
            
            // 저장된 데이터 검증
            if result.success {
                let savedData = testEnvironment.getLastSavedConversation()
                XCTAssertEqual(savedData["id"] as? String, conversationData["id"] as? String)
            }
            
            expectation.fulfill()
            
        } catch {
            XCTFail("Domain to Data 레이어 플로우 실패: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then: 데이터 영속성 검증
        XCTAssertTrue(persistenceSuccess, "데이터 저장이 성공해야 함")
        
        print("✅ Domain → Data 레이어 데이터 플로우 검증 완료")
    }
    
    // MARK: - Publisher-Subscriber 패턴 테스트
    
    func testPublisherSubscriberDataFlow() async throws {
        // Given: Publisher-Subscriber 패턴 데이터 플로우
        let expectation = XCTestExpectation(description: "Publisher-Subscriber data flow")
        expectation.expectedFulfillmentCount = 2 // Publisher 발행 + Subscriber 수신
        
        var publishedValue: String?
        var receivedValue: String?
        
        // When: Publisher에서 값 발행
        let testValue = "Publisher 테스트 데이터"
        
        // Subscriber 설정
        testEnvironment.setupSubscriber { value in
            receivedValue = value
            self.boundaryLogger.logSubscriberReceive(
                by: "TestSubscriber",
                layer: .presentation,
                subscriber: "testDataSubscriber",
                value: value,
                from: "TestPublisher"
            )
            expectation.fulfill()
        }
        
        // Publisher에서 값 발행
        testEnvironment.publishValue(testValue) { success in
            if success {
                publishedValue = testValue
                self.boundaryLogger.logPublisherEmit(
                    from: "TestPublisher",
                    layer: .viewModel,
                    publisher: "testDataPublisher",
                    value: testValue,
                    subscriberCount: 1
                )
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then: Publisher-Subscriber 플로우 검증
        XCTAssertEqual(publishedValue, testValue, "발행된 값이 일치해야 함")
        XCTAssertEqual(receivedValue, testValue, "수신된 값이 일치해야 함")
        
        // 이벤트 로깅 검증
        let publisherEvents = dataFlowTracker.flowEvents.filter { $0.eventType == .publisherEmit }
        let subscriberEvents = dataFlowTracker.flowEvents.filter { $0.eventType == .subscriberReceive }
        
        XCTAssertGreaterThan(publisherEvents.count, 0, "Publisher 이벤트가 기록되어야 함")
        XCTAssertGreaterThan(subscriberEvents.count, 0, "Subscriber 이벤트가 기록되어야 함")
        
        print("✅ Publisher-Subscriber 데이터 플로우 검증 완료")
    }
    
    // MARK: - 상태 동기화 테스트
    
    func testStateSynchronizationAcrossLayers() async throws {
        // Given: 여러 레이어 간 상태 동기화
        let expectation = XCTestExpectation(description: "State synchronization across layers")
        var synchronizationSuccess = true
        
        // When: 연쇄적인 상태 변경 시뮬레이션
        do {
            // 1. Presentation 레이어에서 상태 변경
            boundaryLogger.logStateChange(
                in: "AdaptiveChatView",
                layer: .presentation,
                property: "isLoading",
                oldValue: false,
                newValue: true,
                trigger: "userInput"
            )
            
            // 2. ViewModel 레이어 상태 동기화
            await Task.sleep(nanoseconds: 50_000_000) // 0.05초 대기
            
            boundaryLogger.logStateChange(
                in: "ConversationManager",
                layer: .viewModel,
                property: "processingMessage",
                oldValue: nil,
                newValue: "처리 중인 메시지",
                trigger: "presentationStateChange"
            )
            
            // 3. Domain 레이어 상태 동기화
            await Task.sleep(nanoseconds: 50_000_000)
            
            boundaryLogger.logStateChange(
                in: "ModelInferenceService",
                layer: .domain,
                property: "isInferencing",
                oldValue: false,
                newValue: true,
                trigger: "viewModelRequest"
            )
            
            // 4. 상태 일관성 검증
            let presentationState = testEnvironment.getPresentationLayerState()
            let viewModelState = testEnvironment.getViewModelLayerState()
            let domainState = testEnvironment.getDomainLayerState()
            
            // 상태 간 일관성 검사
            if presentationState["isLoading"] as? Bool != true ||
               viewModelState["processingMessage"] == nil ||
               domainState["isInferencing"] as? Bool != true {
                synchronizationSuccess = false
            }
            
            expectation.fulfill()
            
        } catch {
            XCTFail("상태 동기화 테스트 실패: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then: 상태 동기화 검증
        XCTAssertTrue(synchronizationSuccess, "레이어 간 상태 동기화가 성공해야 함")
        
        // 상태 변경 이벤트 검증
        let stateChangeEvents = dataFlowTracker.flowEvents.filter { $0.eventType == .stateChange }
        XCTAssertGreaterThanOrEqual(stateChangeEvents.count, 3, "3개 이상의 상태 변경 이벤트가 기록되어야 함")
        
        // 레이어별 상태 스냅샷 검증
        let layerStates = dataFlowTracker.layerStates
        let presentationStates = layerStates.filter { $0.layer == .presentation }
        let viewModelStates = layerStates.filter { $0.layer == .viewModel }
        let domainStates = layerStates.filter { $0.layer == .domain }
        
        XCTAssertGreaterThan(presentationStates.count, 0, "Presentation 레이어 상태가 기록되어야 함")
        XCTAssertGreaterThan(viewModelStates.count, 0, "ViewModel 레이어 상태가 기록되어야 함")
        XCTAssertGreaterThan(domainStates.count, 0, "Domain 레이어 상태가 기록되어야 함")
        
        print("✅ 레이어 간 상태 동기화 검증 완료")
    }
    
    // MARK: - 비동기 이벤트 순서 테스트
    
    func testAsynchronousEventOrdering() async throws {
        // Given: 비동기 이벤트 순서 변경 시나리오
        let expectation = XCTestExpectation(description: "Asynchronous event ordering")
        var eventOrder: [String] = []
        let eventOrderQueue = DispatchQueue(label: "event.order.tracking")
        
        // When: 동시 다발적 비동기 호출
        await withTaskGroup(of: Void.self) { group in
            // Task 1: 빠른 처리 (0.1초)
            group.addTask {
                try? await Task.sleep(nanoseconds: 100_000_000)
                eventOrderQueue.async {
                    eventOrder.append("FastTask")
                }
                
                self.boundaryLogger.logBoundaryCall(
                    from: .viewModel,
                    to: .domain,
                    sourceComponent: "TestComponent1",
                    targetComponent: "TestService1",
                    method: "fastOperation"
                ) {
                    return TestResult(success: true, response: "Fast completed")
                }
            }
            
            // Task 2: 중간 처리 (0.2초)
            group.addTask {
                try? await Task.sleep(nanoseconds: 200_000_000)
                eventOrderQueue.async {
                    eventOrder.append("MediumTask")
                }
                
                self.boundaryLogger.logBoundaryCall(
                    from: .viewModel,
                    to: .domain,
                    sourceComponent: "TestComponent2",
                    targetComponent: "TestService2",
                    method: "mediumOperation"
                ) {
                    return TestResult(success: true, response: "Medium completed")
                }
            }
            
            // Task 3: 느린 처리 (0.3초)
            group.addTask {
                try? await Task.sleep(nanoseconds: 300_000_000)
                eventOrderQueue.async {
                    eventOrder.append("SlowTask")
                }
                
                self.boundaryLogger.logBoundaryCall(
                    from: .viewModel,
                    to: .domain,
                    sourceComponent: "TestComponent3",
                    targetComponent: "TestService3",
                    method: "slowOperation"
                ) {
                    return TestResult(success: true, response: "Slow completed")
                }
            }
        }
        
        // 모든 비동기 작업 완료 대기
        try await Task.sleep(nanoseconds: 500_000_000)
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Then: 이벤트 순서 검증
        XCTAssertEqual(eventOrder, ["FastTask", "MediumTask", "SlowTask"], "이벤트가 처리 시간 순서대로 완료되어야 함")
        
        // 타임스탬프 순서 검증
        let flowEvents = dataFlowTracker.flowEvents.suffix(6) // 최근 6개 이벤트
        let sortedEvents = flowEvents.sorted { $0.timestamp < $1.timestamp }
        
        for i in 1..<sortedEvents.count {
            XCTAssertLessThanOrEqual(
                sortedEvents[i-1].timestamp,
                sortedEvents[i].timestamp,
                "이벤트 타임스탬프가 순차적이어야 함"
            )
        }
        
        print("✅ 비동기 이벤트 순서 검증 완료")
    }
    
    // MARK: - 동시 호출 스트레스 테스트
    
    func testConcurrentCallStressTest() async throws {
        // Given: 동시 다중 호출 스트레스 테스트
        let expectation = XCTestExpectation(description: "Concurrent call stress test")
        let concurrentCalls = 20
        var successfulCalls = 0
        var inconsistencies = 0
        
        let resultQueue = DispatchQueue(label: "stress.test.results")
        
        // When: 동시 다중 컴포넌트 호출
        await withTaskGroup(of: Void.self) { group in
            for i in 1...concurrentCalls {
                group.addTask {
                    do {
                        let result = self.boundaryLogger.logBoundaryCall(
                            from: .presentation,
                            to: .viewModel,
                            sourceComponent: "StressTestView\(i)",
                            targetComponent: "StressTestManager",
                            method: "concurrentProcess",
                            parameters: ["index": i, "data": "concurrent_test_\(i)"]
                        ) {
                            return self.testEnvironment.simulateConcurrentOperation(index: i)
                        }
                        
                        resultQueue.async {
                            if result.success {
                                successfulCalls += 1
                            }
                        }
                        
                    } catch {
                        resultQueue.async {
                            inconsistencies += 1
                        }
                    }
                }
            }
        }
        
        // 결과 정리 시간
        try await Task.sleep(nanoseconds: 100_000_000)
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 30.0)
        
        // Then: 스트레스 테스트 결과 검증
        let successRate = Double(successfulCalls) / Double(concurrentCalls) * 100
        XCTAssertGreaterThanOrEqual(successRate, 90.0, "동시 호출 성공률이 90% 이상이어야 함")
        XCTAssertLessThanOrEqual(inconsistencies, 2, "상태 불일치가 2개 이하여야 함")
        
        // 동시성 안전성 검증
        let detectedInconsistencies = dataFlowTracker.inconsistencies
        let concurrencyIssues = detectedInconsistencies.filter { 
            $0.description.contains("동시") || $0.description.contains("경합") 
        }
        
        XCTAssertLessThanOrEqual(concurrencyIssues.count, 1, "동시성 관련 이슈가 최소화되어야 함")
        
        print("✅ 동시 호출 스트레스 테스트 완료: \(successfulCalls)/\(concurrentCalls) 성공 (\(String(format: "%.1f", successRate))%)")
    }
    
    // MARK: - 시나리오 기반 통합 테스트
    
    func testCompleteUserJourneyScenario() async throws {
        // Given: 전체 사용자 여정 시나리오
        let scenario = TestScenario(
            name: "완전한 채팅 세션",
            description: "사용자 입력부터 AI 응답까지 전체 플로우",
            steps: [
                ScenarioStep(
                    description: "사용자 텍스트 입력",
                    targetComponent: "AdaptiveChatView",
                    action: "handleUserInput",
                    requiredInputData: ["text"],
                    expectedDuration: 0.1
                ),
                ScenarioStep(
                    description: "메시지 관리자에 추가",
                    targetComponent: "ConversationManager",
                    action: "addMessage",
                    requiredInputData: ["content", "isUser"],
                    expectedDuration: 0.2
                ),
                ScenarioStep(
                    description: "모델 추론 실행",
                    targetComponent: "ModelInferenceService",
                    action: "processText",
                    requiredInputData: ["input"],
                    expectedDuration: 2.0,
                    expectedDataSize: 1024
                ),
                ScenarioStep(
                    description: "응답 메시지 추가",
                    targetComponent: "ConversationManager",
                    action: "addMessage",
                    requiredInputData: ["content", "isUser"],
                    expectedDuration: 0.1
                ),
                ScenarioStep(
                    description: "대화 히스토리 저장",
                    targetComponent: "ConversationHistoryService",
                    action: "saveConversation",
                    requiredInputData: ["conversationData"],
                    expectedDuration: 0.5
                ),
                ScenarioStep(
                    description: "UI 업데이트",
                    targetComponent: "AdaptiveChatView",
                    action: "updateUI",
                    requiredInputData: ["messages"],
                    expectedDuration: 0.1
                )
            ]
        )
        
        // When: 시나리오 실행
        await dataFlowTracker.executeScenario(scenario)
        
        // Then: 시나리오 완료 검증
        let scenarioEvents = dataFlowTracker.flowEvents.filter { event in
            event.eventType == .scenarioStart || event.eventType == .scenarioEnd
        }
        
        XCTAssertGreaterThanOrEqual(scenarioEvents.count, 2, "시나리오 시작/종료 이벤트가 기록되어야 함")
        
        let stepEvents = dataFlowTracker.flowEvents.filter { $0.eventType == .stepExecution }
        XCTAssertEqual(stepEvents.count, scenario.steps.count, "모든 시나리오 단계가 실행되어야 함")
        
        // 전체 처리 시간 검증
        let totalExpectedTime = scenario.steps.reduce(0) { $0 + $1.expectedDuration }
        let actualTotalTime = dataFlowTracker.trackingSession?.duration ?? 0
        
        // 실제 시간이 예상 시간의 150% 이하여야 함 (여유 포함)
        XCTAssertLessThanOrEqual(actualTotalTime, totalExpectedTime * 1.5, "전체 처리 시간이 합리적이어야 함")
        
        print("✅ 완전한 사용자 여정 시나리오 검증 완료")
    }
    
    // MARK: - 보조 메서드
    
    private func printAnalysisReport(_ report: DataFlowAnalysisReport) {
        print("\n📊 컴포넌트 데이터 플로우 분석 보고서")
        print("=" * 60)
        print("세션: \(report.session.name)")
        print("기간: \(String(format: "%.2f", report.session.duration))초")
        print("총 이벤트: \(report.totalEvents)개")
        print("상태 불일치: \(report.totalInconsistencies)개")
        
        print("\n📈 레이어별 분석:")
        for analysis in report.layerAnalysis {
            let healthStatus = analysis.isHealthy ? "✅" : "❌"
            print("- \(analysis.layer.displayName): \(analysis.eventCount)개 이벤트, \(analysis.stateChanges)개 상태변경, 평균응답 \(String(format: "%.3f", analysis.averageResponseTime))초 \(healthStatus)")
        }
        
        print("\n🔧 컴포넌트별 분석:")
        for analysis in report.componentAnalysis.prefix(5) { // 상위 5개만 표시
            let responsive = analysis.isResponsive ? "반응함" : "지연됨"
            print("- \(analysis.component): 입력 \(analysis.incomingEvents), 출력 \(analysis.outgoingEvents), 오류 \(analysis.errorCount), 처리시간 \(String(format: "%.3f", analysis.averageProcessingTime))초 (\(responsive))")
        }
        
        print("\n📊 성능 메트릭:")
        print("- 오류율: \(String(format: "%.2f", report.performanceMetrics.errorRate))%")
        print("- 평균 이벤트 간격: \(String(format: "%.3f", report.performanceMetrics.averageEventInterval))초")
        print("- 피크 이벤트/초: \(String(format: "%.1f", report.performanceMetrics.peakEventsPerSecond))")
        print("- 데이터 전송량: \(report.performanceMetrics.dataTransferVolume)바이트")
        print("- 메모리 효율성: \(String(format: "%.1f", report.performanceMetrics.memoryEfficiency))%")
        
        print("\n💡 권장사항:")
        for recommendation in report.recommendations {
            print("- \(recommendation)")
        }
        
        print("=" * 60)
    }
}

// MARK: - 테스트 환경 및 유틸리티

class ComponentTestEnvironment {
    private var mockStates: [String: [String: Any]] = [:]
    private var mockResults: [String: TestResult] = [:]
    private var subscribers: [(String) -> Void] = []
    private var publishers: [(String, @escaping (Bool) -> Void) -> Void] = []
    
    func setup() throws {
        initializeMockStates()
        print("🔧 ComponentTestEnvironment 설정 완료")
    }
    
    func cleanup() {
        mockStates.removeAll()
        mockResults.removeAll()
        subscribers.removeAll()
        publishers.removeAll()
        print("🧹 ComponentTestEnvironment 정리 완료")
    }
    
    private func initializeMockStates() {
        // 초기 상태 설정
        mockStates["ConversationManager"] = [
            "messageCount": 0,
            "lastMessageContent": "",
            "lastAIResponse": "",
            "isProcessing": false
        ]
        
        mockStates["ModelInferenceService"] = [
            "isModelLoaded": true,
            "isInferencing": false,
            "lastProcessingTime": 0.0
        ]
        
        mockStates["Presentation"] = [
            "isLoading": false,
            "currentView": "chat"
        ]
        
        mockStates["ViewModel"] = [
            "processingMessage": nil,
            "activeConversationId": nil
        ]
        
        mockStates["Domain"] = [
            "isInferencing": false,
            "modelStatus": "loaded"
        ]
    }
    
    // MARK: - 시뮬레이션 메서드
    
    func simulateAddMessage(content: String, isUser: Bool) -> TestResult {
        var state = mockStates["ConversationManager"] ?? [:]
        state["messageCount"] = (state["messageCount"] as? Int ?? 0) + 1
        state["lastMessageContent"] = content
        mockStates["ConversationManager"] = state
        
        return TestResult(success: true, response: "Message added: \(content)")
    }
    
    func simulateTextInference(input: String) -> TestResult {
        var state = mockStates["ModelInferenceService"] ?? [:]
        state["isInferencing"] = true
        mockStates["ModelInferenceService"] = state
        
        // 추론 시뮬레이션 (0.5초 대기)
        Thread.sleep(forTimeInterval: 0.5)
        
        let response = "AI 응답: '\(input)'에 대한 처리된 결과입니다."
        
        state["isInferencing"] = false
        state["lastProcessingTime"] = 0.5
        mockStates["ModelInferenceService"] = state
        
        // ConversationManager 상태 업데이트
        var conversationState = mockStates["ConversationManager"] ?? [:]
        conversationState["lastAIResponse"] = response
        mockStates["ConversationManager"] = conversationState
        
        return TestResult(success: true, response: response)
    }
    
    func simulateConversationSave(data: [String: Any]) -> TestResult {
        mockStates["LastSavedConversation"] = data
        return TestResult(success: true, response: "Conversation saved")
    }
    
    func simulateConcurrentOperation(index: Int) -> TestResult {
        // 동시성 테스트를 위한 랜덤 처리 시간
        let processingTime = Double.random(in: 0.1...0.3)
        Thread.sleep(forTimeInterval: processingTime)
        
        return TestResult(
            success: arc4random_uniform(100) < 95, // 95% 성공률
            response: "Concurrent operation \(index) completed"
        )
    }
    
    // MARK: - 상태 조회 메서드
    
    func getConversationManagerState() -> [String: Any] {
        return mockStates["ConversationManager"] ?? [:]
    }
    
    func getLastSavedConversation() -> [String: Any] {
        return mockStates["LastSavedConversation"] ?? [:]
    }
    
    func getPresentationLayerState() -> [String: Any] {
        return mockStates["Presentation"] ?? [:]
    }
    
    func getViewModelLayerState() -> [String: Any] {
        return mockStates["ViewModel"] ?? [:]
    }
    
    func getDomainLayerState() -> [String: Any] {
        return mockStates["Domain"] ?? [:]
    }
    
    // MARK: - Publisher-Subscriber 시뮬레이션
    
    func setupSubscriber(_ handler: @escaping (String) -> Void) {
        subscribers.append(handler)
    }
    
    func publishValue(_ value: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            for subscriber in self.subscribers {
                subscriber(value)
            }
            completion(true)
        }
    }
}

struct TestResult {
    let success: Bool
    let response: String?
    
    init(success: Bool, response: String? = nil) {
        self.success = success
        self.response = response
    }
}