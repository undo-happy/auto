import XCTest
import SwiftUI
import Combine
@testable import OfflineChatbot

/// 상태 불일치 및 동기화 문제 감지 및 해결 검증 테스트
final class StateConsistencyValidationTests: XCTestCase {
    
    private var dataFlowTracker: ComponentDataFlowTracker!
    private var boundaryLogger: LayerBoundaryLogger!
    private var stateValidator: StateConsistencyValidator!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        super.setUp()
        
        dataFlowTracker = ComponentDataFlowTracker.shared
        boundaryLogger = LayerBoundaryLogger.shared
        stateValidator = StateConsistencyValidator()
        cancellables = Set<AnyCancellable>()
        
        dataFlowTracker.startTracking(sessionName: "State Consistency Validation")
        stateValidator.startValidation()
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        
        stateValidator.stopValidation()
        dataFlowTracker.stopTracking()
        cancellables.removeAll()
        
        // 상태 일관성 보고서 출력
        let report = stateValidator.generateConsistencyReport()
        printConsistencyReport(report)
    }
    
    // MARK: - 상태 누락 감지 테스트
    
    func testStatePropagationMissing() async throws {
        // Given: 상태 전파 누락 시나리오
        let expectation = XCTestExpectation(description: "State propagation missing detection")
        var inconsistencyDetected = false
        
        // When: 일부 컴포넌트에서 상태 업데이트 누락 시뮬레이션
        
        // 1. Presentation 레이어 상태 변경
        stateValidator.recordStateChange(
            component: "AdaptiveChatView",
            layer: .presentation,
            state: StateChange(
                property: "isLoading",
                oldValue: false,
                newValue: true,
                timestamp: Date(),
                trigger: "userInput"
            )
        )
        
        // 2. ViewModel 레이어는 정상 업데이트
        await Task.sleep(nanoseconds: 50_000_000) // 0.05초 대기
        
        stateValidator.recordStateChange(
            component: "ConversationManager",
            layer: .viewModel,
            state: StateChange(
                property: "isProcessing",
                oldValue: false,
                newValue: true,
                timestamp: Date(),
                trigger: "presentationChange"
            )
        )
        
        // 3. Domain 레이어는 상태 업데이트 누락 (의도적)
        // ModelInferenceService의 isInferencing 상태가 업데이트되지 않음
        
        // 4. 일관성 검사 실행
        await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
        
        let inconsistencies = stateValidator.validateConsistency()
        inconsistencyDetected = !inconsistencies.isEmpty
        
        // 누락된 상태 전파 감지 확인
        let propagationMissing = inconsistencies.contains { inconsistency in
            inconsistency.type == .missingStatePropagation &&
            inconsistency.involvedComponents.contains("ModelInferenceService")
        }
        
        XCTAssertTrue(propagationMissing, "누락된 상태 전파가 감지되어야 함")
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then: 상태 누락 감지 검증
        XCTAssertTrue(inconsistencyDetected, "상태 불일치가 감지되어야 함")
        
        print("✅ 상태 전파 누락 감지 테스트 완료")
    }
    
    func testStateDuplicationDetection() async throws {
        // Given: 중복 상태 전파 시나리오
        let expectation = XCTestExpectation(description: "State duplication detection")
        var duplicationDetected = false
        
        // When: 동일한 상태 변경이 중복으로 전파되는 상황 시뮬레이션
        
        // 1. 첫 번째 상태 변경
        stateValidator.recordStateChange(
            component: "ConversationManager",
            layer: .viewModel,
            state: StateChange(
                property: "messageCount",
                oldValue: 0,
                newValue: 1,
                timestamp: Date(),
                trigger: "messageAdded"
            )
        )
        
        // 2. 동일한 상태 변경이 중복으로 발생 (버그 시뮬레이션)
        await Task.sleep(nanoseconds: 10_000_000) // 0.01초 대기
        
        stateValidator.recordStateChange(
            component: "ConversationManager",
            layer: .viewModel,
            state: StateChange(
                property: "messageCount",
                oldValue: 0,
                newValue: 1,
                timestamp: Date(),
                trigger: "messageAdded"
            )
        )
        
        // 3. 또 다른 중복 상태 변경
        await Task.sleep(nanoseconds: 10_000_000)
        
        stateValidator.recordStateChange(
            component: "ConversationManager",
            layer: .viewModel,
            state: StateChange(
                property: "messageCount",
                oldValue: 1,
                newValue: 1,
                timestamp: Date(),
                trigger: "redundantUpdate"
            )
        )
        
        // 4. 중복 감지 검사
        let inconsistencies = stateValidator.validateConsistency()
        duplicationDetected = inconsistencies.contains { $0.type == .duplicateStatePropagation }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then: 중복 상태 전파 감지 검증
        XCTAssertTrue(duplicationDetected, "중복 상태 전파가 감지되어야 함")
        
        print("✅ 중복 상태 전파 감지 테스트 완료")
    }
    
    // MARK: - 상태 순서 검증 테스트
    
    func testStateChangeOrderValidation() async throws {
        // Given: 상태 변경 순서 검증 시나리오
        let expectation = XCTestExpectation(description: "State change order validation")
        var orderViolationDetected = false
        
        // When: 잘못된 순서의 상태 변경 시뮬레이션
        
        // 1. 정상적인 순서: Presentation → ViewModel → Domain
        stateValidator.recordStateChange(
            component: "AdaptiveChatView",
            layer: .presentation,
            state: StateChange(
                property: "inputText",
                oldValue: "",
                newValue: "사용자 입력",
                timestamp: Date(),
                trigger: "userTyping"
            )
        )
        
        await Task.sleep(nanoseconds: 50_000_000)
        
        // 2. 역방향 상태 변경 (잘못된 순서)
        stateValidator.recordStateChange(
            component: "ModelInferenceService",
            layer: .domain,
            state: StateChange(
                property: "isProcessing",
                oldValue: false,
                newValue: true,
                timestamp: Date(),
                trigger: "directDomainUpdate"
            )
        )
        
        await Task.sleep(nanoseconds: 30_000_000)
        
        // 3. ViewModel이 나중에 업데이트 (순서 위반)
        stateValidator.recordStateChange(
            component: "ConversationManager",
            layer: .viewModel,
            state: StateChange(
                property: "isProcessing",
                oldValue: false,
                newValue: true,
                timestamp: Date(),
                trigger: "delayedViewModelUpdate"
            )
        )
        
        // 4. 순서 검증
        let inconsistencies = stateValidator.validateConsistency()
        orderViolationDetected = inconsistencies.contains { $0.type == .stateOrderViolation }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then: 상태 순서 위반 감지 검증
        XCTAssertTrue(orderViolationDetected, "상태 변경 순서 위반이 감지되어야 함")
        
        print("✅ 상태 변경 순서 검증 테스트 완료")
    }
    
    // MARK: - 동시성 상태 충돌 테스트
    
    func testConcurrentStateConflicts() async throws {
        // Given: 동시성 상태 충돌 시나리오
        let expectation = XCTestExpectation(description: "Concurrent state conflicts")
        var conflictDetected = false
        
        // When: 동시에 발생하는 상태 변경 충돌
        await withTaskGroup(of: Void.self) { group in
            // Task 1: 메시지 카운트 증가
            group.addTask {
                self.stateValidator.recordStateChange(
                    component: "ConversationManager",
                    layer: .viewModel,
                    state: StateChange(
                        property: "messageCount",
                        oldValue: 5,
                        newValue: 6,
                        timestamp: Date(),
                        trigger: "userMessage"
                    )
                )
            }
            
            // Task 2: 동시에 다른 값으로 메시지 카운트 변경
            group.addTask {
                try? await Task.sleep(nanoseconds: 1_000_000) // 0.001초 차이
                
                self.stateValidator.recordStateChange(
                    component: "ConversationManager",
                    layer: .viewModel,
                    state: StateChange(
                        property: "messageCount",
                        oldValue: 5,
                        newValue: 7,
                        timestamp: Date(),
                        trigger: "aiMessage"
                    )
                )
            }
            
            // Task 3: 또 다른 동시 상태 변경
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_000_000) // 0.002초 차이
                
                self.stateValidator.recordStateChange(
                    component: "ConversationManager",
                    layer: .viewModel,
                    state: StateChange(
                        property: "messageCount",
                        oldValue: 6,
                        newValue: 8,
                        timestamp: Date(),
                        trigger: "batchUpdate"
                    )
                )
            }
        }
        
        // 동시성 충돌 검사
        await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
        
        let inconsistencies = stateValidator.validateConsistency()
        conflictDetected = inconsistencies.contains { $0.type == .concurrentStateConflict }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then: 동시성 충돌 감지 검증
        XCTAssertTrue(conflictDetected, "동시성 상태 충돌이 감지되어야 함")
        
        print("✅ 동시성 상태 충돌 감지 테스트 완료")
    }
    
    // MARK: - 상태 회복 메커니즘 테스트
    
    func testStateRecoveryMechanism() async throws {
        // Given: 상태 회복 메커니즘 테스트
        let expectation = XCTestExpectation(description: "State recovery mechanism")
        var recoverySuccessful = false
        
        // When: 상태 불일치 발생 후 자동 회복 시도
        
        // 1. 정상 상태 설정
        stateValidator.recordStateChange(
            component: "ModelInferenceService",
            layer: .domain,
            state: StateChange(
                property: "modelStatus",
                oldValue: "unloaded",
                newValue: "loaded",
                timestamp: Date(),
                trigger: "modelInitialization"
            )
        )
        
        // 2. 불일치 상태 발생 (모델이 로드되었지만 뷰모델에서는 미로드 상태)
        stateValidator.recordStateChange(
            component: "ModelStateManager",
            layer: .viewModel,
            state: StateChange(
                property: "isModelReady",
                oldValue: true,
                newValue: false,
                timestamp: Date(),
                trigger: "inconsistentUpdate"
            )
        )
        
        // 3. 불일치 감지 및 회복 시도
        let inconsistencies = stateValidator.validateConsistency()
        let modelStateInconsistency = inconsistencies.first { 
            $0.involvedComponents.contains("ModelInferenceService") &&
            $0.involvedComponents.contains("ModelStateManager")
        }
        
        if let inconsistency = modelStateInconsistency {
            // 4. 자동 회복 시도
            let recoveryActions = stateValidator.generateRecoveryActions(for: inconsistency)
            
            for action in recoveryActions {
                try await executeRecoveryAction(action)
            }
            
            // 5. 회복 후 상태 재검증
            await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
            
            let postRecoveryInconsistencies = stateValidator.validateConsistency()
            recoverySuccessful = postRecoveryInconsistencies.count < inconsistencies.count
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Then: 상태 회복 검증
        XCTAssertTrue(recoverySuccessful, "상태 회복 메커니즘이 작동해야 함")
        
        print("✅ 상태 회복 메커니즘 테스트 완료")
    }
    
    // MARK: - 복합 상태 시나리오 테스트
    
    func testComplexStateScenario() async throws {
        // Given: 복합적인 상태 시나리오
        let expectation = XCTestExpectation(description: "Complex state scenario")
        var scenarioValidated = true
        
        // When: 복잡한 멀티레이어 상태 변경 시나리오 실행
        
        // 시나리오: 사용자가 이미지 입력 → 처리 → 응답 생성
        
        // 1. Presentation: 이미지 선택
        stateValidator.recordStateChange(
            component: "AdaptiveChatView",
            layer: .presentation,
            state: StateChange(
                property: "selectedImage",
                oldValue: nil,
                newValue: "image_data_placeholder",
                timestamp: Date(),
                trigger: "userImageSelection"
            )
        )
        
        stateValidator.recordStateChange(
            component: "AdaptiveChatView",
            layer: .presentation,
            state: StateChange(
                property: "isProcessingImage",
                oldValue: false,
                newValue: true,
                timestamp: Date(),
                trigger: "imageProcessingStart"
            )
        )
        
        await Task.sleep(nanoseconds: 50_000_000)
        
        // 2. ViewModel: 이미지 처리 요청
        stateValidator.recordStateChange(
            component: "ConversationManager",
            layer: .viewModel,
            state: StateChange(
                property: "currentInputType",
                oldValue: "text",
                newValue: "image",
                timestamp: Date(),
                trigger: "imageInputReceived"
            )
        )
        
        stateValidator.recordStateChange(
            component: "ConversationManager",
            layer: .viewModel,
            state: StateChange(
                property: "isProcessing",
                oldValue: false,
                newValue: true,
                timestamp: Date(),
                trigger: "processingRequest"
            )
        )
        
        await Task.sleep(nanoseconds: 100_000_000)
        
        // 3. Domain: 이미지 분석 수행
        stateValidator.recordStateChange(
            component: "ModelInferenceService",
            layer: .domain,
            state: StateChange(
                property: "currentTask",
                oldValue: "idle",
                newValue: "imageAnalysis",
                timestamp: Date(),
                trigger: "inferenceRequest"
            )
        )
        
        stateValidator.recordStateChange(
            component: "ModelInferenceService",
            layer: .domain,
            state: StateChange(
                property: "isInferencing",
                oldValue: false,
                newValue: true,
                timestamp: Date(),
                trigger: "inferenceStart"
            )
        )
        
        await Task.sleep(nanoseconds: 200_000_000) // 추론 시간 시뮬레이션
        
        // 4. 처리 완료 및 역방향 상태 업데이트
        stateValidator.recordStateChange(
            component: "ModelInferenceService",
            layer: .domain,
            state: StateChange(
                property: "isInferencing",
                oldValue: true,
                newValue: false,
                timestamp: Date(),
                trigger: "inferenceComplete"
            )
        )
        
        stateValidator.recordStateChange(
            component: "ModelInferenceService",
            layer: .domain,
            state: StateChange(
                property: "lastResult",
                oldValue: nil,
                newValue: "이미지 분석 결과: 고양이가 보입니다.",
                timestamp: Date(),
                trigger: "resultGenerated"
            )
        )
        
        await Task.sleep(nanoseconds: 50_000_000)
        
        // 5. ViewModel: 결과 수신 및 상태 업데이트
        stateValidator.recordStateChange(
            component: "ConversationManager",
            layer: .viewModel,
            state: StateChange(
                property: "isProcessing",
                oldValue: true,
                newValue: false,
                timestamp: Date(),
                trigger: "processingComplete"
            )
        )
        
        stateValidator.recordStateChange(
            component: "ConversationManager",
            layer: .viewModel,
            state: StateChange(
                property: "lastAIResponse",
                oldValue: "",
                newValue: "이미지 분석 결과: 고양이가 보입니다.",
                timestamp: Date(),
                trigger: "responseReceived"
            )
        )
        
        await Task.sleep(nanoseconds: 50_000_000)
        
        // 6. Presentation: UI 업데이트
        stateValidator.recordStateChange(
            component: "AdaptiveChatView",
            layer: .presentation,
            state: StateChange(
                property: "isProcessingImage",
                oldValue: true,
                newValue: false,
                timestamp: Date(),
                trigger: "processingComplete"
            )
        )
        
        stateValidator.recordStateChange(
            component: "AdaptiveChatView",
            layer: .presentation,
            state: StateChange(
                property: "displayedResponse",
                oldValue: "",
                newValue: "이미지 분석 결과: 고양이가 보입니다.",
                timestamp: Date(),
                trigger: "responseDisplay"
            )
        )
        
        // 7. 전체 시나리오 일관성 검증
        await Task.sleep(nanoseconds: 100_000_000)
        
        let inconsistencies = stateValidator.validateConsistency()
        let validationResults = stateValidator.validateComplexScenario(name: "ImageAnalysisFlow")
        
        scenarioValidated = inconsistencies.isEmpty && validationResults.isValid
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 15.0)
        
        // Then: 복합 시나리오 검증
        XCTAssertTrue(scenarioValidated, "복합 상태 시나리오가 일관성 있게 실행되어야 함")
        
        // 상태 변경 순서 검증
        let stateChanges = stateValidator.getStateChangeHistory()
        let imageProcessingChanges = stateChanges.filter { change in
            change.trigger.contains("image") || change.trigger.contains("Image")
        }
        
        XCTAssertGreaterThan(imageProcessingChanges.count, 5, "이미지 처리 관련 상태 변경이 충분히 기록되어야 함")
        
        print("✅ 복합 상태 시나리오 검증 완료")
    }
    
    // MARK: - 보조 메서드
    
    private func executeRecoveryAction(_ action: StateRecoveryAction) async throws {
        switch action.type {
        case .resyncState:
            // 상태 재동기화
            stateValidator.recordStateChange(
                component: action.targetComponent,
                layer: action.targetLayer,
                state: StateChange(
                    property: action.property,
                    oldValue: action.currentValue,
                    newValue: action.expectedValue,
                    timestamp: Date(),
                    trigger: "autoRecovery"
                )
            )
            
        case .rollbackState:
            // 상태 롤백
            stateValidator.recordStateChange(
                component: action.targetComponent,
                layer: action.targetLayer,
                state: StateChange(
                    property: action.property,
                    oldValue: action.currentValue,
                    newValue: action.rollbackValue,
                    timestamp: Date(),
                    trigger: "rollbackRecovery"
                )
            )
            
        case .forwardPropagation:
            // 상태 전파
            stateValidator.recordStateChange(
                component: action.targetComponent,
                layer: action.targetLayer,
                state: StateChange(
                    property: action.property,
                    oldValue: nil,
                    newValue: action.expectedValue,
                    timestamp: Date(),
                    trigger: "forwardPropagation"
                )
            )
        }
        
        await Task.sleep(nanoseconds: 10_000_000) // 0.01초 대기
    }
    
    private func printConsistencyReport(_ report: StateConsistencyReport) {
        print("\n🔍 상태 일관성 검증 보고서")
        print("=" * 60)
        print("검증 기간: \(String(format: "%.2f", report.validationDuration))초")
        print("총 상태 변경: \(report.totalStateChanges)개")
        print("감지된 불일치: \(report.totalInconsistencies)개")
        print("성공적 회복: \(report.successfulRecoveries)개")
        
        print("\n📊 불일치 유형별 분석:")
        for (type, count) in report.inconsistencyByType {
            print("- \(type.displayName): \(count)개")
        }
        
        print("\n🏥 회복 작업 분석:")
        for (action, count) in report.recoveryActionCounts {
            print("- \(action.displayName): \(count)회")
        }
        
        print("\n💡 개선 권장사항:")
        for recommendation in report.recommendations {
            print("- \(recommendation)")
        }
        
        print("=" * 60)
    }
}

// MARK: - 상태 일관성 검증 클래스

class StateConsistencyValidator {
    private var stateHistory: [StateChangeRecord] = []
    private var inconsistencies: [StateInconsistencyDetailed] = []
    private var isValidating = false
    private let validationQueue = DispatchQueue(label: "state.consistency.validation", qos: .utility)
    
    func startValidation() {
        isValidating = true
        print("🔍 상태 일관성 검증 시작")
    }
    
    func stopValidation() {
        isValidating = false
        print("⏹️ 상태 일관성 검증 중지")
    }
    
    func recordStateChange(component: String, layer: ArchitectureLayer, state: StateChange) {
        guard isValidating else { return }
        
        let record = StateChangeRecord(
            id: UUID(),
            component: component,
            layer: layer,
            change: state,
            recordedAt: Date()
        )
        
        validationQueue.async {
            self.stateHistory.append(record)
            
            // 실시간 검증
            self.performRealtimeValidation(for: record)
        }
    }
    
    func validateConsistency() -> [StateInconsistencyDetailed] {
        return validationQueue.sync {
            inconsistencies.removeAll()
            
            // 1. 상태 전파 누락 검사
            detectMissingStatePropagation()
            
            // 2. 중복 상태 전파 검사
            detectDuplicateStatePropagation()
            
            // 3. 상태 순서 위반 검사
            detectStateOrderViolations()
            
            // 4. 동시성 충돌 검사
            detectConcurrentStateConflicts()
            
            return inconsistencies
        }
    }
    
    func generateRecoveryActions(for inconsistency: StateInconsistencyDetailed) -> [StateRecoveryAction] {
        var actions: [StateRecoveryAction] = []
        
        switch inconsistency.type {
        case .missingStatePropagation:
            actions.append(StateRecoveryAction(
                type: .forwardPropagation,
                targetComponent: inconsistency.involvedComponents.last!,
                targetLayer: .domain,
                property: inconsistency.affectedProperty,
                currentValue: nil,
                expectedValue: inconsistency.expectedValue,
                rollbackValue: nil
            ))
            
        case .duplicateStatePropagation:
            actions.append(StateRecoveryAction(
                type: .resyncState,
                targetComponent: inconsistency.involvedComponents.first!,
                targetLayer: .viewModel,
                property: inconsistency.affectedProperty,
                currentValue: inconsistency.currentValue,
                expectedValue: inconsistency.expectedValue,
                rollbackValue: nil
            ))
            
        case .stateOrderViolation:
            actions.append(StateRecoveryAction(
                type: .rollbackState,
                targetComponent: inconsistency.involvedComponents.first!,
                targetLayer: .domain,
                property: inconsistency.affectedProperty,
                currentValue: inconsistency.currentValue,
                expectedValue: inconsistency.expectedValue,
                rollbackValue: inconsistency.rollbackValue
            ))
            
        case .concurrentStateConflict:
            actions.append(StateRecoveryAction(
                type: .resyncState,
                targetComponent: inconsistency.involvedComponents.first!,
                targetLayer: .viewModel,
                property: inconsistency.affectedProperty,
                currentValue: inconsistency.currentValue,
                expectedValue: inconsistency.expectedValue,
                rollbackValue: nil
            ))
        }
        
        return actions
    }
    
    func validateComplexScenario(name: String) -> ScenarioValidationResult {
        let scenarioStates = stateHistory.filter { record in
            record.change.trigger.contains(name) || 
            record.change.trigger.contains("image") ||
            record.change.trigger.contains("Image")
        }
        
        let isValid = scenarioStates.count > 5 && 
                     inconsistencies.filter { inconsistency in
                         inconsistency.detectedAt > scenarioStates.first?.recordedAt ?? Date()
                     }.isEmpty
        
        return ScenarioValidationResult(
            scenarioName: name,
            isValid: isValid,
            stateChangesCount: scenarioStates.count,
            inconsistenciesFound: inconsistencies.count,
            validationDetails: "시나리오 상태 변경 검증 완료"
        )
    }
    
    func getStateChangeHistory() -> [StateChangeRecord] {
        return stateHistory
    }
    
    func generateConsistencyReport() -> StateConsistencyReport {
        let validationDuration = stateHistory.last?.recordedAt.timeIntervalSince(
            stateHistory.first?.recordedAt ?? Date()
        ) ?? 0
        
        let inconsistencyByType = Dictionary(grouping: inconsistencies, by: { $0.type })
            .mapValues { $0.count }
        
        let recoveryActionCounts = inconsistencies
            .flatMap { generateRecoveryActions(for: $0) }
            .reduce(into: [StateRecoveryActionType: Int]()) { result, action in
                result[action.type, default: 0] += 1
            }
        
        return StateConsistencyReport(
            validationDuration: validationDuration,
            totalStateChanges: stateHistory.count,
            totalInconsistencies: inconsistencies.count,
            successfulRecoveries: 0,
            inconsistencyByType: inconsistencyByType,
            recoveryActionCounts: recoveryActionCounts,
            recommendations: generateRecommendations()
        )
    }
    
    // MARK: - Private Methods
    
    private func performRealtimeValidation(for record: StateChangeRecord) {
        // 실시간 검증 로직
        
        // 최근 상태 변경들과 비교
        let recentRecords = stateHistory.suffix(10)
        
        // 빠른 중복 검사
        let duplicates = recentRecords.filter { recent in
            recent.component == record.component &&
            recent.change.property == record.change.property &&
            recent.change.newValue as? String == record.change.newValue as? String &&
            abs(recent.recordedAt.timeIntervalSince(record.recordedAt)) < 0.1
        }
        
        if duplicates.count > 1 {
            inconsistencies.append(StateInconsistencyDetailed(
                id: UUID(),
                type: .duplicateStatePropagation,
                description: "중복 상태 전파 감지: \(record.component).\(record.change.property)",
                involvedComponents: [record.component],
                affectedProperty: record.change.property,
                currentValue: record.change.newValue,
                expectedValue: record.change.newValue,
                rollbackValue: record.change.oldValue,
                detectedAt: Date(),
                severity: .medium
            ))
        }
    }
    
    private func detectMissingStatePropagation() {
        // 상태 전파 누락 감지 로직
        let layerGroups = Dictionary(grouping: stateHistory, by: { $0.layer })
        
        for (layer, records) in layerGroups {
            if layer != .data { // Data 레이어는 일반적으로 다른 레이어로 전파하지 않음
                let nextLayer = ArchitectureLayer(rawValue: layer.rawValue + 1)
                
                for record in records {
                    let relatedChanges = stateHistory.filter { related in
                        related.layer == nextLayer &&
                        related.change.property == record.change.property &&
                        related.recordedAt > record.recordedAt &&
                        related.recordedAt.timeIntervalSince(record.recordedAt) < 1.0
                    }
                    
                    if relatedChanges.isEmpty && shouldPropagate(record.change.property) {
                        inconsistencies.append(StateInconsistencyDetailed(
                            id: UUID(),
                            type: .missingStatePropagation,
                            description: "상태 전파 누락: \(record.component).\(record.change.property)",
                            involvedComponents: [record.component],
                            affectedProperty: record.change.property,
                            currentValue: record.change.newValue,
                            expectedValue: record.change.newValue,
                            rollbackValue: nil,
                            detectedAt: Date(),
                            severity: .high
                        ))
                    }
                }
            }
        }
    }
    
    private func detectDuplicateStatePropagation() {
        // 중복 상태 전파 감지 로직
        let timeWindow: TimeInterval = 0.1 // 100ms 윈도우
        
        for i in 0..<stateHistory.count {
            let current = stateHistory[i]
            let duplicates = stateHistory[i+1...].filter { other in
                other.component == current.component &&
                other.change.property == current.change.property &&
                other.recordedAt.timeIntervalSince(current.recordedAt) < timeWindow
            }
            
            if !duplicates.isEmpty {
                inconsistencies.append(StateInconsistencyDetailed(
                    id: UUID(),
                    type: .duplicateStatePropagation,
                    description: "중복 상태 전파: \(current.component).\(current.change.property)",
                    involvedComponents: [current.component],
                    affectedProperty: current.change.property,
                    currentValue: current.change.newValue,
                    expectedValue: current.change.newValue,
                    rollbackValue: current.change.oldValue,
                    detectedAt: Date(),
                    severity: .medium
                ))
            }
        }
    }
    
    private func detectStateOrderViolations() {
        // 상태 순서 위반 감지 로직
        let processingStates = stateHistory.filter { record in
            record.change.property.contains("Processing") || 
            record.change.property.contains("isLoading") ||
            record.change.property.contains("isInferencing")
        }
        
        for i in 1..<processingStates.count {
            let previous = processingStates[i-1]
            let current = processingStates[i]
            
            // 하위 레이어가 상위 레이어보다 먼저 처리 상태가 되면 위반
            if previous.layer.rawValue > current.layer.rawValue &&
               current.recordedAt > previous.recordedAt {
                
                inconsistencies.append(StateInconsistencyDetailed(
                    id: UUID(),
                    type: .stateOrderViolation,
                    description: "상태 순서 위반: \(previous.layer.displayName) → \(current.layer.displayName)",
                    involvedComponents: [previous.component, current.component],
                    affectedProperty: current.change.property,
                    currentValue: current.change.newValue,
                    expectedValue: previous.change.newValue,
                    rollbackValue: current.change.oldValue,
                    detectedAt: Date(),
                    severity: .high
                ))
            }
        }
    }
    
    private func detectConcurrentStateConflicts() {
        // 동시성 상태 충돌 감지 로직
        let conflictWindow: TimeInterval = 0.01 // 10ms 윈도우
        
        for i in 0..<stateHistory.count {
            let current = stateHistory[i]
            let concurrent = stateHistory.filter { other in
                other.component == current.component &&
                other.change.property == current.change.property &&
                other.id != current.id &&
                abs(other.recordedAt.timeIntervalSince(current.recordedAt)) < conflictWindow
            }
            
            if !concurrent.isEmpty {
                inconsistencies.append(StateInconsistencyDetailed(
                    id: UUID(),
                    type: .concurrentStateConflict,
                    description: "동시성 상태 충돌: \(current.component).\(current.change.property)",
                    involvedComponents: [current.component],
                    affectedProperty: current.change.property,
                    currentValue: current.change.newValue,
                    expectedValue: current.change.newValue,
                    rollbackValue: current.change.oldValue,
                    detectedAt: Date(),
                    severity: .critical
                ))
            }
        }
    }
    
    private func shouldPropagate(_ property: String) -> Bool {
        // 전파되어야 하는 속성인지 확인
        let propagatableProperties = [
            "isLoading", "isProcessing", "isInferencing",
            "messageCount", "modelStatus", "currentTask"
        ]
        
        return propagatableProperties.contains { property.contains($0) }
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        let criticalIssues = inconsistencies.filter { $0.severity == .critical }
        if !criticalIssues.isEmpty {
            recommendations.append("심각한 상태 불일치가 \(criticalIssues.count)개 감지되었습니다. 즉시 수정이 필요합니다.")
        }
        
        let orderViolations = inconsistencies.filter { $0.type == .stateOrderViolation }
        if !orderViolations.isEmpty {
            recommendations.append("상태 순서 위반이 감지되었습니다. 아키텍처 레이어 의존성을 재검토하세요.")
        }
        
        let concurrentConflicts = inconsistencies.filter { $0.type == .concurrentStateConflict }
        if !concurrentConflicts.isEmpty {
            recommendations.append("동시성 충돌이 감지되었습니다. 상태 관리에 동기화 메커니즘을 추가하세요.")
        }
        
        if recommendations.isEmpty {
            recommendations.append("상태 일관성이 양호합니다. 현재 상태 관리 패턴을 유지하세요.")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Data Models

struct StateChange {
    let property: String
    let oldValue: Any?
    let newValue: Any
    let timestamp: Date
    let trigger: String
}

struct StateChangeRecord {
    let id: UUID
    let component: String
    let layer: ArchitectureLayer
    let change: StateChange
    let recordedAt: Date
}

struct StateInconsistencyDetailed {
    let id: UUID
    let type: StateInconsistencyType
    let description: String
    let involvedComponents: [String]
    let affectedProperty: String
    let currentValue: Any?
    let expectedValue: Any?
    let rollbackValue: Any?
    let detectedAt: Date
    let severity: InconsistencySeverity
}

enum StateInconsistencyType: CaseIterable {
    case missingStatePropagation
    case duplicateStatePropagation
    case stateOrderViolation
    case concurrentStateConflict
    
    var displayName: String {
        switch self {
        case .missingStatePropagation: return "상태 전파 누락"
        case .duplicateStatePropagation: return "중복 상태 전파"
        case .stateOrderViolation: return "상태 순서 위반"
        case .concurrentStateConflict: return "동시성 상태 충돌"
        }
    }
}

struct StateRecoveryAction {
    let type: StateRecoveryActionType
    let targetComponent: String
    let targetLayer: ArchitectureLayer
    let property: String
    let currentValue: Any?
    let expectedValue: Any?
    let rollbackValue: Any?
}

enum StateRecoveryActionType: CaseIterable {
    case resyncState
    case rollbackState
    case forwardPropagation
    
    var displayName: String {
        switch self {
        case .resyncState: return "상태 재동기화"
        case .rollbackState: return "상태 롤백"
        case .forwardPropagation: return "상태 전파"
        }
    }
}

struct ScenarioValidationResult {
    let scenarioName: String
    let isValid: Bool
    let stateChangesCount: Int
    let inconsistenciesFound: Int
    let validationDetails: String
}

struct StateConsistencyReport {
    let validationDuration: TimeInterval
    let totalStateChanges: Int
    let totalInconsistencies: Int
    let successfulRecoveries: Int
    let inconsistencyByType: [StateInconsistencyType: Int]
    let recoveryActionCounts: [StateRecoveryActionType: Int]
    let recommendations: [String]
}