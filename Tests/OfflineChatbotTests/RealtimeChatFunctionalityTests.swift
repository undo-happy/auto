import XCTest
import SwiftUI
import Combine
@testable import OfflineChatbot

/// T-043: 채팅 기능 전과정 실시간 테스트 및 오류 수정 검증
final class RealtimeChatFunctionalityTests: XCTestCase {
    
    private var performanceMonitor: RealTimePerformanceMonitor!
    private var conversationManager: ConversationManager!
    private var modelService: ModelInferenceService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        super.setUp()
        
        performanceMonitor = RealTimePerformanceMonitor.shared
        conversationManager = ConversationManager()
        modelService = ModelInferenceService()
        cancellables = Set<AnyCancellable>()
        
        // 모니터링 시작
        performanceMonitor.startMonitoring()
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        
        performanceMonitor.stopMonitoring()
        cancellables.removeAll()
        
        // 성능 보고서 생성
        let report = performanceMonitor.exportPerformanceData()
        print("\n📊 실시간 채팅 기능 성능 보고서:")
        print("- 총 작업 수: \(report.operationHistory.count)")
        print("- 성공률: \(String(format: "%.1f", report.summary.totalOperations > 0 ? Double(report.summary.successfulOperations) / Double(report.summary.totalOperations) * 100 : 0))%")
        print("- 평균 처리 시간: \(String(format: "%.3f", report.summary.averageDuration))초")
        print("- 피크 메모리: \(report.summary.peakMemoryUsage / 1024 / 1024)MB")
    }
    
    // MARK: - 핵심 채팅 플로우 테스트
    
    func testCompleteTextChatFlow() async throws {
        // Given: 텍스트 채팅 시나리오
        let testMessages = [
            "안녕하세요",
            "오늘 날씨가 어떤가요?",
            "Swift 프로그래밍에 대해 설명해주세요",
            "긴 텍스트 입력 테스트입니다. 이 메시지는 채팅 시스템의 처리 능력과 성능을 테스트하기 위한 더 긴 텍스트입니다."
        ]
        
        let expectation = XCTestExpectation(description: "Complete text chat flow")
        var allResponsesReceived = true
        var totalResponseTime: TimeInterval = 0
        
        // When: 순차적으로 메시지 처리
        for (index, message) in testMessages.enumerated() {
            let startTime = Date()
            
            // 사용자 메시지 추가
            let userMessage = ChatMessage(
                id: UUID(),
                content: message,
                isUser: true,
                timestamp: Date()
            )
            conversationManager.addMessage(userMessage)
            
            do {
                // 모델 추론 실행
                let response = try await modelService.processText(message)
                
                // AI 응답 메시지 추가
                let assistantMessage = ChatMessage(
                    id: UUID(),
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    metadata: MessageMetadata(
                        processingTime: Date().timeIntervalSince(startTime),
                        tokenCount: response.count / 4,
                        modelUsed: modelService.currentModel
                    )
                )
                conversationManager.addMessage(assistantMessage)
                
                let responseTime = Date().timeIntervalSince(startTime)
                totalResponseTime += responseTime
                
                print("📱 메시지 \(index + 1) 처리 완료: \(String(format: "%.2f", responseTime))초")
                
                // 응답 시간 검증 (4초 이하)
                XCTAssertLessThanOrEqual(responseTime, 4.0, "메시지 \(index + 1) 응답 시간이 4초를 초과함")
                
                // 응답 내용 검증
                XCTAssertFalse(response.isEmpty, "빈 응답이 생성됨")
                XCTAssertGreaterThan(response.count, 10, "응답이 너무 짧음")
                
            } catch {
                allResponsesReceived = false
                print("❌ 메시지 \(index + 1) 처리 실패: \(error.localizedDescription)")
                
                // 에러 메시지 추가
                let errorMessage = ChatMessage(
                    id: UUID(),
                    content: "죄송합니다. 처리 중 오류가 발생했습니다: \(error.localizedDescription)",
                    isUser: false,
                    timestamp: Date(),
                    isError: true
                )
                conversationManager.addMessage(errorMessage)
            }
            
            // 메시지 간 간격 (실제 사용자 시뮬레이션)
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5초
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 30.0)
        
        // Then: 전체 채팅 플로우 검증
        XCTAssertTrue(allResponsesReceived, "모든 메시지가 성공적으로 처리되어야 함")
        
        let averageResponseTime = totalResponseTime / Double(testMessages.count)
        XCTAssertLessThanOrEqual(averageResponseTime, 3.0, "평균 응답 시간이 3초 이하여야 함")
        
        // 대화 메트릭 검증
        let metrics = conversationManager.conversationMetrics
        XCTAssertEqual(metrics.userMessages, testMessages.count, "사용자 메시지 수가 일치해야 함")
        XCTAssertGreaterThan(metrics.assistantMessages, 0, "AI 응답이 생성되어야 함")
        XCTAssertLessThanOrEqual(metrics.errorRate, 20.0, "오류율이 20% 이하여야 함")
        
        print("✅ 전체 텍스트 채팅 플로우 완료: 평균 \(String(format: "%.2f", averageResponseTime))초")
    }
    
    func testMultimodalChatFlow() async throws {
        // Given: 멀티모달 입력 시나리오
        let expectation = XCTestExpectation(description: "Multimodal chat flow")
        var successfulProcessing = 0
        let totalTests = 4
        
        // When: 다양한 모달리티 테스트
        
        // 1. 텍스트 입력
        do {
            let response = try await modelService.processText("멀티모달 테스트 메시지")
            XCTAssertFalse(response.isEmpty)
            successfulProcessing += 1
            print("✅ 텍스트 처리 성공")
        } catch {
            print("❌ 텍스트 처리 실패: \(error)")
        }
        
        // 2. 이미지 입력 시뮬레이션
        do {
            let imageData = Data(count: 1024 * 1024) // 1MB 이미지 시뮬레이션
            let response = try await modelService.processImage(imageData, prompt: "이 이미지를 설명해주세요")
            XCTAssertFalse(response.isEmpty)
            successfulProcessing += 1
            print("✅ 이미지 처리 성공")
        } catch {
            print("❌ 이미지 처리 실패: \(error)")
        }
        
        // 3. 음성 입력 시뮬레이션
        do {
            let audioData = Data(count: 44100 * 2 * 5) // 5초 오디오 시뮬레이션
            let response = try await modelService.processAudio(audioData)
            XCTAssertFalse(response.isEmpty)
            successfulProcessing += 1
            print("✅ 음성 처리 성공")
        } catch {
            print("❌ 음성 처리 실패: \(error)")
        }
        
        // 4. 비디오 입력 시뮬레이션
        do {
            let videoData = Data(count: 10 * 1024 * 1024) // 10MB 비디오 시뮬레이션
            let response = try await modelService.processVideo(videoData)
            XCTAssertFalse(response.isEmpty)
            successfulProcessing += 1
            print("✅ 비디오 처리 성공")
        } catch {
            print("❌ 비디오 처리 실패: \(error)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 45.0)
        
        // Then: 멀티모달 처리 성공률 검증
        let successRate = Double(successfulProcessing) / Double(totalTests) * 100
        XCTAssertGreaterThanOrEqual(successRate, 75.0, "멀티모달 처리 성공률이 75% 이상이어야 함")
        
        print("✅ 멀티모달 채팅 플로우 완료: \(successfulProcessing)/\(totalTests) 성공 (\(String(format: "%.1f", successRate))%)")
    }
    
    // MARK: - 실시간 성능 모니터링 테스트
    
    func testRealTimePerformanceMonitoring() async throws {
        // Given: 성능 모니터링 시나리오
        let expectation = XCTestExpectation(description: "Real-time performance monitoring")
        var monitoringMetrics: [String: Any] = [:]
        
        // When: 다양한 작업 실행하며 모니터링
        
        // 1. 동시 작업 모니터링
        let concurrentTasks = 3
        await withTaskGroup(of: Void.self) { group in
            for i in 1...concurrentTasks {
                group.addTask {
                    do {
                        let _ = try await self.modelService.processText("동시 처리 테스트 \(i)")
                    } catch {
                        print("동시 작업 \(i) 실패: \(error)")
                    }
                }
            }
        }
        
        // 2. 메모리 사용량 체크
        let initialMemory = getCurrentMemoryUsage()
        
        // 대용량 처리 시뮬레이션
        for i in 1...5 {
            let largeImageData = Data(count: 2 * 1024 * 1024) // 2MB
            do {
                let _ = try await modelService.processImage(largeImageData)
            } catch {
                print("대용량 처리 \(i) 실패: \(error)")
            }
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        monitoringMetrics["memoryIncrease"] = memoryIncrease
        
        // 3. 시스템 메트릭 수집
        let systemMetrics = performanceMonitor.systemMetrics
        monitoringMetrics["averageResponseTime"] = systemMetrics.averageResponseTime
        monitoringMetrics["errorRate"] = systemMetrics.errorRate
        monitoringMetrics["activeOperations"] = systemMetrics.activeOperations
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 30.0)
        
        // Then: 성능 메트릭 검증
        XCTAssertLessThanOrEqual(systemMetrics.averageResponseTime, 5.0, "평균 응답 시간이 5초 이하여야 함")
        XCTAssertLessThanOrEqual(systemMetrics.errorRate, 10.0, "오류율이 10% 이하여야 함")
        XCTAssertLessThanOrEqual(memoryIncrease, 100 * 1024 * 1024, "메모리 증가가 100MB 이하여야 함")
        
        print("✅ 실시간 성능 모니터링 검증 완료")
        print("- 평균 응답시간: \(String(format: "%.2f", systemMetrics.averageResponseTime))초")
        print("- 오류율: \(String(format: "%.1f", systemMetrics.errorRate))%")
        print("- 메모리 증가: \(memoryIncrease / 1024 / 1024)MB")
    }
    
    // MARK: - 오류 처리 및 복구 테스트
    
    func testErrorHandlingAndRecovery() async throws {
        // Given: 다양한 오류 시나리오
        let expectation = XCTestExpectation(description: "Error handling and recovery")
        var errorRecoveryTests = 0
        var successfulRecoveries = 0
        
        // When: 오류 시나리오 테스트
        
        // 1. 빈 입력 처리
        do {
            let _ = try await modelService.processText("")
            XCTFail("빈 입력에 대해 오류가 발생해야 함")
        } catch {
            errorRecoveryTests += 1
            if error is InferenceError {
                successfulRecoveries += 1
                print("✅ 빈 입력 오류 처리 성공")
            }
        }
        
        // 2. 모델 미로드 상태 처리
        modelService.isModelLoaded = false
        do {
            let _ = try await modelService.processText("테스트 메시지")
            XCTFail("모델 미로드 상태에 대해 오류가 발생해야 함")
        } catch {
            errorRecoveryTests += 1
            if error is InferenceError {
                successfulRecoveries += 1
                print("✅ 모델 미로드 오류 처리 성공")
            }
        }
        
        // 3. 모델 다시 로드 및 복구
        do {
            try await modelService.loadModel("test-model")
            let response = try await modelService.processText("복구 테스트 메시지")
            XCTAssertFalse(response.isEmpty)
            successfulRecoveries += 1
            print("✅ 모델 복구 성공")
        } catch {
            print("❌ 모델 복구 실패: \(error)")
        }
        errorRecoveryTests += 1
        
        // 4. 대용량 입력 처리
        let largeInput = String(repeating: "테스트 ", count: 1000) // 매우 긴 입력
        do {
            let response = try await modelService.processText(largeInput)
            // 적절히 처리되거나 오류가 발생해야 함
            print("📏 대용량 입력 처리: \(response.count)자 응답")
        } catch {
            print("⚠️ 대용량 입력 오류 (예상된 동작): \(error.localizedDescription)")
        }
        errorRecoveryTests += 1
        successfulRecoveries += 1 // 처리되거나 적절한 오류 발생 모두 성공으로 간주
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 20.0)
        
        // Then: 오류 처리 및 복구 검증
        let recoveryRate = Double(successfulRecoveries) / Double(errorRecoveryTests) * 100
        XCTAssertGreaterThanOrEqual(recoveryRate, 75.0, "오류 복구율이 75% 이상이어야 함")
        
        print("✅ 오류 처리 및 복구 테스트 완료: \(successfulRecoveries)/\(errorRecoveryTests) 성공 (\(String(format: "%.1f", recoveryRate))%)")
    }
    
    // MARK: - 동시성 및 스레드 안전성 테스트
    
    func testConcurrencyAndThreadSafety() async throws {
        // Given: 동시성 테스트 시나리오
        let expectation = XCTestExpectation(description: "Concurrency and thread safety")
        let concurrentRequests = 10
        var completedRequests = 0
        var responseTimesSum: TimeInterval = 0
        
        // When: 동시 요청 처리
        await withTaskGroup(of: (Bool, TimeInterval).self) { group in
            for i in 1...concurrentRequests {
                group.addTask {
                    let startTime = Date()
                    do {
                        let response = try await self.modelService.processText("동시 요청 \(i)")
                        let responseTime = Date().timeIntervalSince(startTime)
                        return (true, responseTime)
                    } catch {
                        print("❌ 동시 요청 \(i) 실패: \(error)")
                        return (false, Date().timeIntervalSince(startTime))
                    }
                }
            }
            
            for await (success, responseTime) in group {
                if success {
                    completedRequests += 1
                }
                responseTimesSum += responseTime
            }
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 60.0)
        
        // Then: 동시성 성능 검증
        let successRate = Double(completedRequests) / Double(concurrentRequests) * 100
        let averageResponseTime = responseTimesSum / Double(concurrentRequests)
        
        XCTAssertGreaterThanOrEqual(successRate, 80.0, "동시 요청 성공률이 80% 이상이어야 함")
        XCTAssertLessThanOrEqual(averageResponseTime, 10.0, "동시 요청 평균 응답 시간이 10초 이하여야 함")
        
        // 메모리 누수 체크
        let finalMemoryUsage = getCurrentMemoryUsage()
        XCTAssertLessThan(finalMemoryUsage, 1024 * 1024 * 1024, "메모리 사용량이 1GB 이하여야 함")
        
        print("✅ 동시성 및 스레드 안전성 테스트 완료")
        print("- 성공률: \(String(format: "%.1f", successRate))%")
        print("- 평균 응답시간: \(String(format: "%.2f", averageResponseTime))초")
        print("- 최종 메모리: \(finalMemoryUsage / 1024 / 1024)MB")
    }
    
    // MARK: - UI 통합 성능 테스트
    
    @MainActor
    func testUIIntegrationPerformance() async throws {
        // Given: UI 통합 시나리오
        let expectation = XCTestExpectation(description: "UI integration performance")
        var uiUpdateTimes: [TimeInterval] = []
        var messageRenderTimes: [TimeInterval] = []
        
        // When: UI 업데이트를 포함한 채팅 플로우
        for i in 1...5 {
            let uiStartTime = Date()
            
            // 메시지 추가 (UI 업데이트)
            let userMessage = ChatMessage(
                id: UUID(),
                content: "UI 통합 테스트 메시지 \(i)",
                isUser: true,
                timestamp: Date()
            )
            
            conversationManager.addMessage(userMessage)
            let uiUpdateTime = Date().timeIntervalSince(uiStartTime)
            uiUpdateTimes.append(uiUpdateTime)
            
            // AI 응답 생성
            do {
                let response = try await modelService.processText(userMessage.content)
                
                let renderStartTime = Date()
                let assistantMessage = ChatMessage(
                    id: UUID(),
                    content: response,
                    isUser: false,
                    timestamp: Date()
                )
                
                conversationManager.addMessage(assistantMessage)
                let renderTime = Date().timeIntervalSince(renderStartTime)
                messageRenderTimes.append(renderTime)
                
            } catch {
                print("❌ UI 통합 테스트 \(i) 실패: \(error)")
            }
            
            // UI 업데이트 간격
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1초
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 30.0)
        
        // Then: UI 성능 검증
        let averageUIUpdateTime = uiUpdateTimes.reduce(0, +) / Double(uiUpdateTimes.count)
        let averageRenderTime = messageRenderTimes.reduce(0, +) / Double(messageRenderTimes.count)
        
        XCTAssertLessThanOrEqual(averageUIUpdateTime, 0.1, "UI 업데이트가 100ms 이하여야 함")
        XCTAssertLessThanOrEqual(averageRenderTime, 0.05, "메시지 렌더링이 50ms 이하여야 함")
        
        // 대화 히스토리 검증
        let totalMessages = conversationManager.messages.count
        XCTAssertEqual(totalMessages, 10, "총 10개 메시지가 있어야 함 (사용자 5개 + AI 5개)")
        
        print("✅ UI 통합 성능 테스트 완료")
        print("- 평균 UI 업데이트: \(String(format: "%.3f", averageUIUpdateTime * 1000))ms")
        print("- 평균 렌더링: \(String(format: "%.3f", averageRenderTime * 1000))ms")
        print("- 총 메시지: \(totalMessages)개")
    }
    
    // MARK: - 보조 함수
    
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

// MARK: - 추론 오류 타입 확장

public enum InferenceError: LocalizedError {
    case modelNotLoaded
    case emptyInput
    case modelLoadingFailed(String)
    case inferenceTimeout
    case invalidInputFormat
    case insufficientMemory
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "모델이 로드되지 않았습니다"
        case .emptyInput:
            return "입력이 비어있습니다"
        case .modelLoadingFailed(let reason):
            return "모델 로딩 실패: \(reason)"
        case .inferenceTimeout:
            return "추론 시간 초과"
        case .invalidInputFormat:
            return "잘못된 입력 형식"
        case .insufficientMemory:
            return "메모리 부족"
        case .networkError:
            return "네트워크 오류"
        }
    }
}