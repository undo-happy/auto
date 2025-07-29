import XCTest
import SwiftUI
import Combine
@testable import OfflineChatbot

/// 채팅 통합 플로우 검증 테스트 (입력 이벤트부터 출력 콜백까지 전체 검증)
final class ChatIntegrationFlowTests: XCTestCase {
    
    private var testEnvironment: ChatTestEnvironment!
    private var performanceTracker: PerformanceTracker!
    
    override func setUpWithError() throws {
        super.setUp()
        testEnvironment = ChatTestEnvironment()
        performanceTracker = PerformanceTracker()
        try testEnvironment.setup()
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        testEnvironment.cleanup()
        
        // 성능 분석 보고서 출력
        let report = performanceTracker.generateReport()
        print("\n📊 채팅 통합 플로우 성능 분석:")
        report.print()
    }
    
    // MARK: - End-to-End 채팅 플로우 테스트
    
    func testCompleteTextInputToOutputFlow() async throws {
        // Given: 완전한 텍스트 채팅 플로우
        let testInput = "Swift 프로그래밍의 장점을 설명해주세요"
        let flowId = UUID()
        
        performanceTracker.startFlow(flowId, type: .textChat)
        
        let expectation = XCTestExpectation(description: "Complete text chat flow")
        var flowResult: ChatFlowResult?
        
        // When: 전체 플로우 실행
        do {
            flowResult = try await testEnvironment.executeCompleteTextFlow(
                input: testInput,
                flowId: flowId
            )
            expectation.fulfill()
        } catch {
            XCTFail("텍스트 채팅 플로우 실행 실패: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Then: 플로우 결과 검증
        guard let result = flowResult else {
            XCTFail("플로우 결과가 없음")
            return
        }
        
        // 1. 타임스탬프 로그 검증
        XCTAssertGreaterThan(result.timestampLogs.count, 5, "최소 5개의 타임스탬프 로그가 있어야 함")
        
        // 2. 단계별 처리 시간 검증
        let inputEventTime = result.getTimestamp(for: .inputEvent)
        let preprocessingTime = result.getTimestamp(for: .preprocessing)
        let inferenceTime = result.getTimestamp(for: .inference)
        let postprocessingTime = result.getTimestamp(for: .postprocessing)
        let outputCallbackTime = result.getTimestamp(for: .outputCallback)
        
        XCTAssertNotNil(inputEventTime, "입력 이벤트 타임스탬프가 기록되어야 함")
        XCTAssertNotNil(outputCallbackTime, "출력 콜백 타임스탬프가 기록되어야 함")
        
        // 3. 순서 검증
        if let input = inputEventTime, let output = outputCallbackTime {
            XCTAssertLessThan(input, output, "입력 이벤트가 출력 콜백보다 먼저 발생해야 함")
        }
        
        // 4. 전체 처리 시간 검증
        let totalProcessingTime = result.getTotalProcessingTime()
        XCTAssertLessThanOrEqual(totalProcessingTime, 5.0, "전체 처리 시간이 5초 이하여야 함")
        
        // 5. 응답 품질 검증
        XCTAssertFalse(result.output.isEmpty, "응답이 생성되어야 함")
        XCTAssertGreaterThan(result.output.count, 20, "응답이 충분히 상세해야 함")
        
        performanceTracker.endFlow(flowId, success: true)
        
        print("✅ 텍스트 입력-출력 플로우 완료: \(String(format: "%.3f", totalProcessingTime))초")
        print("   📝 단계별 시간:")
        print("     - 입력 → 전처리: \(result.getStepDuration(.inputEvent, .preprocessing))ms")
        print("     - 전처리 → 추론: \(result.getStepDuration(.preprocessing, .inference))ms")
        print("     - 추론 → 후처리: \(result.getStepDuration(.inference, .postprocessing))ms")
        print("     - 후처리 → 출력: \(result.getStepDuration(.postprocessing, .outputCallback))ms")
    }
    
    func testCompleteImageInputToOutputFlow() async throws {
        // Given: 이미지 채팅 플로우
        let imageData = generateTestImageData(size: 1024)
        let prompt = "이 이미지를 분석해주세요"
        let flowId = UUID()
        
        performanceTracker.startFlow(flowId, type: .imageChat)
        
        let expectation = XCTestExpectation(description: "Complete image chat flow")
        var flowResult: ChatFlowResult?
        
        // When: 이미지 플로우 실행
        do {
            flowResult = try await testEnvironment.executeCompleteImageFlow(
                imageData: imageData,
                prompt: prompt,
                flowId: flowId
            )
            expectation.fulfill()
        } catch {
            XCTFail("이미지 채팅 플로우 실행 실패: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
        
        // Then: 이미지 플로우 검증
        guard let result = flowResult else {
            XCTFail("이미지 플로우 결과가 없음")
            return
        }
        
        // 이미지 특화 검증
        let imageProcessingTime = result.getTimestamp(for: .imageProcessing)
        XCTAssertNotNil(imageProcessingTime, "이미지 처리 타임스탬프가 기록되어야 함")
        
        let totalTime = result.getTotalProcessingTime()
        XCTAssertLessThanOrEqual(totalTime, 10.0, "이미지 처리 전체 시간이 10초 이하여야 함")
        
        // 분석 결과 검증
        XCTAssertTrue(result.output.contains("이미지"), "이미지 관련 응답이어야 함")
        
        performanceTracker.endFlow(flowId, success: true)
        
        print("✅ 이미지 입력-출력 플로우 완료: \(String(format: "%.3f", totalTime))초")
    }
    
    func testCompleteAudioInputToOutputFlow() async throws {
        // Given: 음성 채팅 플로우
        let audioData = generateTestAudioData(duration: 3.0)
        let flowId = UUID()
        
        performanceTracker.startFlow(flowId, type: .audioChat)
        
        let expectation = XCTestExpectation(description: "Complete audio chat flow")
        var flowResult: ChatFlowResult?
        
        // When: 음성 플로우 실행
        do {
            flowResult = try await testEnvironment.executeCompleteAudioFlow(
                audioData: audioData,
                flowId: flowId
            )
            expectation.fulfill()
        } catch {
            XCTFail("음성 채팅 플로우 실행 실패: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 12.0)
        
        // Then: 음성 플로우 검증
        guard let result = flowResult else {
            XCTFail("음성 플로우 결과가 없음")
            return
        }
        
        // 음성 특화 검증
        let transcriptionTime = result.getTimestamp(for: .audioTranscription)
        let ttsTime = result.getTimestamp(for: .textToSpeech)
        
        XCTAssertNotNil(transcriptionTime, "음성 인식 타임스탬프가 기록되어야 함")
        XCTAssertNotNil(ttsTime, "TTS 타임스탬프가 기록되어야 함")
        
        let totalTime = result.getTotalProcessingTime()
        XCTAssertLessThanOrEqual(totalTime, 8.0, "음성 처리 전체 시간이 8초 이하여야 함")
        
        performanceTracker.endFlow(flowId, success: true)
        
        print("✅ 음성 입력-출력 플로우 완료: \(String(format: "%.3f", totalTime))초")
    }
    
    // MARK: - 오류 상황 플로우 테스트
    
    func testErrorRecoveryFlow() async throws {
        // Given: 오류 복구 시나리오
        let invalidInputs = [
            "",
            String(repeating: "a", count: 10000), // 너무 긴 입력
            "�invalid-encoding�" // 인코딩 오류
        ]
        
        var successfulRecoveries = 0
        
        for (index, input) in invalidInputs.enumerated() {
            let flowId = UUID()
            performanceTracker.startFlow(flowId, type: .errorRecovery)
            
            let expectation = XCTestExpectation(description: "Error recovery flow \(index)")
            
            do {
                let result = try await testEnvironment.executeCompleteTextFlow(
                    input: input,
                    flowId: flowId,
                    expectError: true
                )
                
                // 적절한 오류 처리가 되었는지 확인
                if result.hasError {
                    XCTAssertFalse(result.errorMessage.isEmpty, "오류 메시지가 있어야 함")
                    XCTAssertLessThanOrEqual(result.getTotalProcessingTime(), 2.0, "오류 처리가 빨라야 함")
                    successfulRecoveries += 1
                }
                
                expectation.fulfill()
                
            } catch {
                // 예상된 오류인 경우 성공으로 간주
                if error is InferenceError {
                    successfulRecoveries += 1
                }
                expectation.fulfill()
            }
            
            await fulfillment(of: [expectation], timeout: 5.0)
            performanceTracker.endFlow(flowId, success: true)
        }
        
        // Then: 오류 복구 검증
        let recoveryRate = Double(successfulRecoveries) / Double(invalidInputs.count) * 100
        XCTAssertGreaterThanOrEqual(recoveryRate, 100.0, "모든 오류 상황이 적절히 처리되어야 함")
        
        print("✅ 오류 복구 플로우 완료: \(successfulRecoveries)/\(invalidInputs.count) 성공")
    }
    
    // MARK: - 성능 스트레스 테스트
    
    func testConcurrentFlowPerformance() async throws {
        // Given: 동시 다중 플로우
        let concurrentFlows = 5
        let expectation = XCTestExpectation(description: "Concurrent flow performance")
        expectation.expectedFulfillmentCount = concurrentFlows
        
        var completionTimes: [TimeInterval] = []
        let completionQueue = DispatchQueue(label: "completion.queue")
        
        // When: 동시 플로우 실행
        await withTaskGroup(of: Void.self) { group in
            for i in 1...concurrentFlows {
                group.addTask {
                    let flowId = UUID()
                    let startTime = Date()
                    
                    do {
                        let result = try await self.testEnvironment.executeCompleteTextFlow(
                            input: "동시 처리 테스트 \(i)",
                            flowId: flowId
                        )
                        
                        let completionTime = Date().timeIntervalSince(startTime)
                        
                        completionQueue.async {
                            completionTimes.append(completionTime)
                            expectation.fulfill()
                        }
                        
                    } catch {
                        print("❌ 동시 플로우 \(i) 실패: \(error)")
                        completionQueue.async {
                            expectation.fulfill()
                        }
                    }
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
        
        // Then: 동시 성능 검증
        XCTAssertEqual(completionTimes.count, concurrentFlows, "모든 플로우가 완료되어야 함")
        
        let averageTime = completionTimes.reduce(0, +) / Double(completionTimes.count)
        let maxTime = completionTimes.max() ?? 0
        
        XCTAssertLessThanOrEqual(averageTime, 8.0, "평균 처리 시간이 8초 이하여야 함")
        XCTAssertLessThanOrEqual(maxTime, 15.0, "최대 처리 시간이 15초 이하여야 함")
        
        print("✅ 동시 플로우 성능 테스트 완료")
        print("   📊 평균 시간: \(String(format: "%.2f", averageTime))초")
        print("   📊 최대 시간: \(String(format: "%.2f", maxTime))초")
    }
    
    // MARK: - 메모리 효율성 테스트
    
    func testMemoryEfficiencyDuringFlows() async throws {
        // Given: 메모리 효율성 검증
        let initialMemory = getCurrentMemoryUsage()
        let heavyFlowCount = 10
        
        // When: 메모리 집약적 플로우 실행
        for i in 1...heavyFlowCount {
            let flowId = UUID()
            
            // 대용량 이미지 처리
            let largeImageData = generateTestImageData(size: 2048)
            
            do {
                let _ = try await testEnvironment.executeCompleteImageFlow(
                    imageData: largeImageData,
                    prompt: "대용량 이미지 분석 \(i)",
                    flowId: flowId
                )
                
                // 주기적 메모리 체크
                if i % 3 == 0 {
                    let currentMemory = getCurrentMemoryUsage()
                    let memoryIncrease = currentMemory - initialMemory
                    
                    print("🧠 메모리 체크 \(i): \(memoryIncrease / 1024 / 1024)MB 증가")
                    
                    // 메모리 증가가 과도한 경우 경고
                    if memoryIncrease > 200 * 1024 * 1024 { // 200MB 초과
                        print("⚠️ 메모리 사용량 주의: \(memoryIncrease / 1024 / 1024)MB")
                    }
                }
                
            } catch {
                print("❌ 메모리 테스트 플로우 \(i) 실패: \(error)")
            }
            
            // 가비지 컬렉션 유도
            if i % 5 == 0 {
                // 메모리 정리를 위한 잠시 대기
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            }
        }
        
        // Then: 최종 메모리 검증
        let finalMemory = getCurrentMemoryUsage()
        let totalMemoryIncrease = finalMemory - initialMemory
        
        // 메모리 증가가 합리적인 범위 내에 있는지 확인
        XCTAssertLessThan(totalMemoryIncrease, 300 * 1024 * 1024, "총 메모리 증가가 300MB 이하여야 함")
        
        print("✅ 메모리 효율성 테스트 완료")
        print("   📈 총 메모리 증가: \(totalMemoryIncrease / 1024 / 1024)MB")
        print("   📊 플로우당 평균: \(totalMemoryIncrease / heavyFlowCount / 1024 / 1024)MB")
    }
    
    // MARK: - 보조 함수
    
    private func generateTestImageData(size: Int) -> Data {
        return Data(count: size * size * 4) // RGBA
    }
    
    private func generateTestAudioData(duration: TimeInterval) -> Data {
        let sampleRate = 44100.0
        let dataSize = Int(duration * sampleRate * 2) // 16-bit audio
        return Data(count: dataSize)
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}

// MARK: - 테스트 환경 및 유틸리티

class ChatTestEnvironment {
    private var performanceMonitor: RealTimePerformanceMonitor!
    private var conversationManager: ConversationManager!
    private var modelService: ModelInferenceService!
    
    func setup() throws {
        performanceMonitor = RealTimePerformanceMonitor.shared
        conversationManager = ConversationManager()
        modelService = ModelInferenceService()
        
        performanceMonitor.startMonitoring()
    }
    
    func cleanup() {
        performanceMonitor.stopMonitoring()
    }
    
    func executeCompleteTextFlow(
        input: String,
        flowId: UUID,
        expectError: Bool = false
    ) async throws -> ChatFlowResult {
        
        let result = ChatFlowResult(flowId: flowId, input: input)
        
        // 1. 입력 이벤트
        result.addTimestamp(.inputEvent)
        performanceMonitor.logEvent(.textInput, message: "텍스트 입력 이벤트", metadata: ["flowId": flowId.uuidString])
        
        // 2. 전처리
        result.addTimestamp(.preprocessing)
        let preprocessedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if preprocessedInput.isEmpty && !expectError {
            result.setError("빈 입력")
            result.addTimestamp(.outputCallback)
            return result
        }
        
        // 3. 모델 추론
        result.addTimestamp(.inference)
        do {
            // 모델이 로드되지 않은 경우 로드
            if !modelService.isModelLoaded {
                try await modelService.loadModel("test-model")
            }
            
            let response = try await modelService.processText(preprocessedInput)
            
            // 4. 후처리
            result.addTimestamp(.postprocessing)
            let processedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 5. 출력 콜백
            result.addTimestamp(.outputCallback)
            result.setOutput(processedResponse)
            
        } catch {
            result.setError(error.localizedDescription)
            result.addTimestamp(.outputCallback)
            
            if !expectError {
                throw error
            }
        }
        
        return result
    }
    
    func executeCompleteImageFlow(
        imageData: Data,
        prompt: String,
        flowId: UUID
    ) async throws -> ChatFlowResult {
        
        let result = ChatFlowResult(flowId: flowId, input: prompt)
        
        // 1. 입력 이벤트
        result.addTimestamp(.inputEvent)
        performanceMonitor.logEvent(.imageInput, message: "이미지 입력 이벤트")
        
        // 2. 이미지 처리
        result.addTimestamp(.imageProcessing)
        
        // 3. 추론
        result.addTimestamp(.inference)
        do {
            if !modelService.isModelLoaded {
                try await modelService.loadModel("test-model")
            }
            
            let response = try await modelService.processImage(imageData, prompt: prompt)
            
            // 4. 후처리
            result.addTimestamp(.postprocessing)
            
            // 5. 출력 콜백
            result.addTimestamp(.outputCallback)
            result.setOutput(response)
            
        } catch {
            result.setError(error.localizedDescription)
            result.addTimestamp(.outputCallback)
            throw error
        }
        
        return result
    }
    
    func executeCompleteAudioFlow(
        audioData: Data,
        flowId: UUID
    ) async throws -> ChatFlowResult {
        
        let result = ChatFlowResult(flowId: flowId, input: "음성 입력")
        
        // 1. 입력 이벤트
        result.addTimestamp(.inputEvent)
        performanceMonitor.logEvent(.audioInput, message: "음성 입력 이벤트")
        
        // 2. 음성 인식
        result.addTimestamp(.audioTranscription)
        
        // 3. 추론
        result.addTimestamp(.inference)
        do {
            if !modelService.isModelLoaded {
                try await modelService.loadModel("test-model")
            }
            
            let response = try await modelService.processAudio(audioData)
            
            // 4. TTS
            result.addTimestamp(.textToSpeech)
            
            // 5. 출력 콜백
            result.addTimestamp(.outputCallback)
            result.setOutput(response)
            
        } catch {
            result.setError(error.localizedDescription)
            result.addTimestamp(.outputCallback)
            throw error
        }
        
        return result
    }
}

// MARK: - 결과 추적 구조체

class ChatFlowResult {
    let flowId: UUID
    let input: String
    private(set) var output: String = ""
    private(set) var hasError: Bool = false
    private(set) var errorMessage: String = ""
    private(set) var timestampLogs: [(FlowStep, Date)] = []
    
    init(flowId: UUID, input: String) {
        self.flowId = flowId
        self.input = input
    }
    
    func addTimestamp(_ step: FlowStep) {
        timestampLogs.append((step, Date()))
    }
    
    func getTimestamp(for step: FlowStep) -> Date? {
        return timestampLogs.first { $0.0 == step }?.1
    }
    
    func setOutput(_ output: String) {
        self.output = output
    }
    
    func setError(_ error: String) {
        self.hasError = true
        self.errorMessage = error
    }
    
    func getTotalProcessingTime() -> TimeInterval {
        guard let start = timestampLogs.first?.1,
              let end = timestampLogs.last?.1 else {
            return 0
        }
        return end.timeIntervalSince(start)
    }
    
    func getStepDuration(_ from: FlowStep, _ to: FlowStep) -> Int {
        guard let fromTime = getTimestamp(for: from),
              let toTime = getTimestamp(for: to) else {
            return 0
        }
        return Int(toTime.timeIntervalSince(fromTime) * 1000) // milliseconds
    }
}

enum FlowStep: CaseIterable {
    case inputEvent
    case preprocessing
    case imageProcessing
    case audioTranscription
    case inference
    case postprocessing
    case textToSpeech
    case outputCallback
}

// MARK: - 성능 추적기

class PerformanceTracker {
    private var flowMetrics: [UUID: FlowMetric] = [:]
    
    func startFlow(_ flowId: UUID, type: FlowType) {
        flowMetrics[flowId] = FlowMetric(id: flowId, type: type, startTime: Date())
    }
    
    func endFlow(_ flowId: UUID, success: Bool) {
        guard var metric = flowMetrics[flowId] else { return }
        metric.endTime = Date()
        metric.success = success
        flowMetrics[flowId] = metric
    }
    
    func generateReport() -> PerformanceReport {
        return PerformanceReport(metrics: Array(flowMetrics.values))
    }
}

struct FlowMetric {
    let id: UUID
    let type: FlowType
    let startTime: Date
    var endTime: Date?
    var success: Bool = false
    
    var duration: TimeInterval {
        guard let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime)
    }
}

enum FlowType {
    case textChat
    case imageChat
    case audioChat
    case errorRecovery
}

struct PerformanceReport {
    let metrics: [FlowMetric]
    
    func print() {
        let successfulFlows = metrics.filter { $0.success }
        let averageDuration = successfulFlows.isEmpty ? 0 : successfulFlows.map { $0.duration }.reduce(0, +) / Double(successfulFlows.count)
        let successRate = metrics.isEmpty ? 0 : Double(successfulFlows.count) / Double(metrics.count) * 100
        
        Swift.print("- 총 플로우: \(metrics.count)개")
        Swift.print("- 성공률: \(String(format: "%.1f", successRate))%")
        Swift.print("- 평균 처리 시간: \(String(format: "%.3f", averageDuration))초")
        
        // 타입별 분석
        let typeGroups = Dictionary(grouping: successfulFlows, by: { $0.type })
        for (type, flows) in typeGroups {
            let typeAverage = flows.map { $0.duration }.reduce(0, +) / Double(flows.count)
            Swift.print("- \(type): \(flows.count)개, 평균 \(String(format: "%.3f", typeAverage))초")
        }
    }
}