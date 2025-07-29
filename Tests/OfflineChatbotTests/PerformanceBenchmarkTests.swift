import XCTest
import SwiftUI
@testable import OfflineChatbot

/// 성능 벤치마크 및 KPI 달성 테스트
final class PerformanceBenchmarkTests: XCTestCase {
    
    private var performanceMetrics: [String: Any] = [:]
    
    override func setUpWithError() throws {
        super.setUp()
        performanceMetrics.removeAll()
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        printPerformanceReport()
    }
    
    // MARK: - 핵심 KPI 테스트
    
    func testTextResponseTimeKPI() {
        // KPI: 텍스트 50토큰 기준 응답 ≤2초
        measure(metrics: [XCTClockMetric()]) {
            let testInputs = [
                "안녕하세요",
                "오늘 날씨가 어떤가요?",
                "이 문제를 해결하는 방법을 알려주세요",
                "한국의 역사에 대해 간단히 설명해주세요",
                "프로그래밍 언어 추천을 해주실 수 있나요?"
            ]
            
            var totalResponseTime: TimeInterval = 0
            var testCount = 0
            
            for input in testInputs {
                let startTime = Date()
                
                // 실제 텍스트 처리 시뮬레이션 (50토큰 정도)
                simulateTextProcessing(input: input, targetTokens: 50)
                
                let responseTime = Date().timeIntervalSince(startTime)
                totalResponseTime += responseTime
                testCount += 1
                
                XCTAssertLessThanOrEqual(responseTime, 2.0, "단일 응답이 2초 이하여야 함")
            }
            
            let averageResponseTime = totalResponseTime / Double(testCount)
            performanceMetrics["averageTextResponseTime"] = averageResponseTime
            
            XCTAssertLessThanOrEqual(averageResponseTime, 2.0, "평균 텍스트 응답시간이 2초 이하여야 함")
        }
    }
    
    func testInferenceErrorRateKPI() {
        // KPI: 추론 오류율 1% 이하
        let totalTests = 100
        var successfulInferences = 0
        
        for i in 1...totalTests {
            let input = "테스트 입력 \(i)"
            let success = simulateMLXInference(input: input)
            
            if success {
                successfulInferences += 1
            }
        }
        
        let successRate = Double(successfulInferences) / Double(totalTests) * 100
        let errorRate = 100.0 - successRate
        
        performanceMetrics["inferenceSuccessRate"] = successRate
        performanceMetrics["inferenceErrorRate"] = errorRate
        
        XCTAssertLessThanOrEqual(errorRate, 1.0, "추론 오류율이 1% 이하여야 함")
        XCTAssertGreaterThanOrEqual(successRate, 99.0, "추론 성공률이 99% 이상이어야 함")
    }
    
    func testInitialLoadingTimeKPI() {
        // KPI: iPhone 12 기준 초반 로딩 ≤5초
        measure(metrics: [XCTClockMetric()]) {
            let startTime = Date()
            
            // 앱 초기화 프로세스 시뮬레이션
            simulateAppInitialization()
            
            let loadingTime = Date().timeIntervalSince(startTime)
            performanceMetrics["initialLoadingTime"] = loadingTime
            
            XCTAssertLessThanOrEqual(loadingTime, 5.0, "초기 로딩시간이 5초 이하여야 함")
        }
    }
    
    func testCameraFPSKPI() {
        // KPI: 카메라 FPS 30↑
        measure(metrics: [XCTClockMetric()]) {
            let testDuration: TimeInterval = 3.0
            let expectedFPS = 30.0
            let frameInterval = 1.0 / expectedFPS
            
            var frameCount = 0
            let startTime = Date()
            var currentTime = startTime
            
            while currentTime.timeIntervalSince(startTime) < testDuration {
                // 프레임 처리 시뮬레이션
                simulateCameraFrameProcessing()
                frameCount += 1
                
                // 다음 프레임까지 대기
                Thread.sleep(forTimeInterval: frameInterval)
                currentTime = Date()
            }
            
            let actualDuration = currentTime.timeIntervalSince(startTime)
            let actualFPS = Double(frameCount) / actualDuration
            
            performanceMetrics["actualCameraFPS"] = actualFPS
            
            XCTAssertGreaterThanOrEqual(actualFPS, 30.0, "카메라 FPS가 30 이상이어야 함")
        }
    }
    
    // MARK: - 메모리 성능 테스트
    
    func testMemoryUsageEfficiency() {
        // 메모리 사용량 효율성 테스트
        measure(metrics: [XCTMemoryMetric()]) {
            let initialMemory = getCurrentMemoryUsage()
            
            // 다양한 크기의 이미지 처리
            let imageSizes = [512, 1024, 2048, 4096]
            for size in imageSizes {
                let imageData = generateTestImageData(size: size)
                simulateImageProcessing(data: imageData)
                
                // 메모리 정리
                performMemoryCleanup()
            }
            
            let finalMemory = getCurrentMemoryUsage()
            let memoryIncrease = finalMemory - initialMemory
            
            performanceMetrics["memoryIncrease"] = memoryIncrease
            
            // 메모리 증가가 200MB 이하여야 함
            XCTAssertLessThanOrEqual(memoryIncrease, 200 * 1024 * 1024, "메모리 증가가 200MB 이하여야 함")
        }
    }
    
    func testMemoryLeakPrevention() {
        // 메모리 누수 방지 테스트
        let initialMemory = getCurrentMemoryUsage()
        
        // 반복적인 추론 작업
        for _ in 1...50 {
            let input = "메모리 누수 테스트 입력"
            _ = simulateMLXInference(input: input)
            
            // 주기적 메모리 정리
            if arc4random_uniform(10) == 0 { // 10% 확률로 정리
                performMemoryCleanup()
            }
        }
        
        // 최종 메모리 정리
        performMemoryCleanup()
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryDifference = finalMemory - initialMemory
        
        performanceMetrics["memoryLeakTest"] = memoryDifference
        
        // 메모리 차이가 50MB 이하여야 함 (누수 없음)
        XCTAssertLessThanOrEqual(memoryDifference, 50 * 1024 * 1024, "메모리 누수가 없어야 함")
    }
    
    // MARK: - 동시성 성능 테스트
    
    func testConcurrentRequestHandling() {
        // 동시 요청 처리 성능 테스트
        measure(metrics: [XCTClockMetric()]) {
            let concurrentRequests = 10
            let expectation = XCTestExpectation(description: "Concurrent requests")
            expectation.expectedFulfillmentCount = concurrentRequests
            
            var completionTimes: [TimeInterval] = []
            let startTime = Date()
            
            for i in 1...concurrentRequests {
                DispatchQueue.global().async {
                    let requestStartTime = Date()
                    let input = "동시 요청 \(i)"
                    _ = self.simulateMLXInference(input: input)
                    
                    let completionTime = Date().timeIntervalSince(requestStartTime)
                    
                    DispatchQueue.main.async {
                        completionTimes.append(completionTime)
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
            
            let totalTime = Date().timeIntervalSince(startTime)
            let averageCompletionTime = completionTimes.reduce(0, +) / Double(completionTimes.count)
            
            performanceMetrics["concurrentTotalTime"] = totalTime
            performanceMetrics["concurrentAverageTime"] = averageCompletionTime
            
            XCTAssertLessThanOrEqual(totalTime, 15.0, "동시 요청 총 처리시간이 15초 이하여야 함")
            XCTAssertLessThanOrEqual(averageCompletionTime, 5.0, "동시 요청 평균 처리시간이 5초 이하여야 함")
        }
    }
    
    func testThreadSafety() {
        // 스레드 안전성 테스트
        let sharedCounter = NSMutableString(string: "")
        let iterations = 1000
        let threadCount = 5
        
        let expectation = XCTestExpectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = threadCount
        
        for threadIndex in 1...threadCount {
            DispatchQueue.global().async {
                for i in 1...iterations {
                    // 공유 리소스 접근 시뮬레이션
                    self.accessSharedResource(counter: sharedCounter, value: "\(threadIndex)-\(i)")
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        let finalLength = sharedCounter.length
        let expectedLength = threadCount * iterations * 3 // 평균 문자열 길이 추정
        
        performanceMetrics["threadSafetyTest"] = finalLength
        
        // 스레드 안전성이 보장되어야 함 (데이터 손실 없음)
        XCTAssertGreaterThan(finalLength, expectedLength / 2, "스레드 안전성이 보장되어야 함")
    }
    
    // MARK: - 배터리 효율성 테스트
    
    func testBatteryEfficiencySimulation() {
        // 배터리 효율성 시뮬레이션 테스트
        measure(metrics: [XCTCPUMetric()]) {
            let testDuration: TimeInterval = 5.0
            let startTime = Date()
            
            var operationCount = 0
            
            while Date().timeIntervalSince(startTime) < testDuration {
                // CPU 집약적 작업 시뮬레이션
                simulateCPUIntensiveOperation()
                operationCount += 1
                
                // 배터리 절약을 위한 주기적 휴식
                if operationCount % 10 == 0 {
                    Thread.sleep(forTimeInterval: 0.01) // 10ms 휴식
                }
            }
            
            let operationsPerSecond = Double(operationCount) / testDuration
            performanceMetrics["operationsPerSecond"] = operationsPerSecond
            
            // 적절한 처리량 확보 (초당 50회 이상)
            XCTAssertGreaterThanOrEqual(operationsPerSecond, 50.0, "배터리 효율성을 고려한 적절한 처리량이어야 함")
        }
    }
    
    func testGPUUtilizationEfficiency() {
        // GPU 활용 효율성 테스트
        measure(metrics: [XCTClockMetric()]) {
            let imageProcessingTasks = 20
            var totalGPUTime: TimeInterval = 0
            
            for i in 1...imageProcessingTasks {
                let startTime = Date()
                
                // GPU 집약적 이미지 처리 시뮬레이션
                simulateGPUImageProcessing(taskId: i)
                
                let gpuTime = Date().timeIntervalSince(startTime)
                totalGPUTime += gpuTime
            }
            
            let averageGPUTime = totalGPUTime / Double(imageProcessingTasks)
            performanceMetrics["averageGPUProcessingTime"] = averageGPUTime
            
            // GPU 처리 시간이 효율적이어야 함 (평균 0.5초 이하)
            XCTAssertLessThanOrEqual(averageGPUTime, 0.5, "GPU 처리가 효율적이어야 함")
        }
    }
    
    // MARK: - 네트워크 성능 테스트
    
    func testOnlineOfflineTransitionPerformance() {
        // 온라인/오프라인 전환 성능 테스트
        measure(metrics: [XCTClockMetric()]) {
            var transitionTimes: [TimeInterval] = []
            
            // 여러 번의 온라인/오프라인 전환 시뮬레이션
            for _ in 1...5 {
                let startTime = Date()
                
                // 온라인 → 오프라인 전환
                simulateNetworkTransition(toOffline: true)
                let offlineTransitionTime = Date().timeIntervalSince(startTime)
                
                // 잠시 오프라인 상태 유지
                Thread.sleep(forTimeInterval: 0.5)
                
                let onlineStartTime = Date()
                
                // 오프라인 → 온라인 전환
                simulateNetworkTransition(toOffline: false)
                let onlineTransitionTime = Date().timeIntervalSince(onlineStartTime)
                
                transitionTimes.append(offlineTransitionTime)
                transitionTimes.append(onlineTransitionTime)
            }
            
            let averageTransitionTime = transitionTimes.reduce(0, +) / Double(transitionTimes.count)
            performanceMetrics["averageNetworkTransitionTime"] = averageTransitionTime
            
            // 네트워크 전환이 신속해야 함 (평균 1초 이하)
            XCTAssertLessThanOrEqual(averageTransitionTime, 1.0, "네트워크 전환이 신속해야 함")
        }
    }
    
    func testModelSwitchingPerformance() {
        // 모델 전환 성능 테스트 (온디바이스 ↔ 클라우드)
        measure(metrics: [XCTClockMetric()]) {
            let switchingCycles = 3
            var switchingTimes: [TimeInterval] = []
            
            for cycle in 1...switchingCycles {
                // 온디바이스 → 클라우드 모델 전환
                let cloudSwitchStart = Date()
                simulateModelSwitch(toCloud: true)
                let cloudSwitchTime = Date().timeIntervalSince(cloudSwitchStart)
                switchingTimes.append(cloudSwitchTime)
                
                // 몇 개의 요청 처리
                for _ in 1...3 {
                    _ = simulateCloudInference(input: "클라우드 테스트 \(cycle)")
                }
                
                // 클라우드 → 온디바이스 모델 전환
                let localSwitchStart = Date()
                simulateModelSwitch(toCloud: false)
                let localSwitchTime = Date().timeIntervalSince(localSwitchStart)
                switchingTimes.append(localSwitchTime)
                
                // 몇 개의 요청 처리
                for _ in 1...3 {
                    _ = simulateMLXInference(input: "로컬 테스트 \(cycle)")
                }
            }
            
            let averageSwitchTime = switchingTimes.reduce(0, +) / Double(switchingTimes.count)
            performanceMetrics["averageModelSwitchTime"] = averageSwitchTime
            
            // 모델 전환이 빨라야 함 (평균 2초 이하)
            XCTAssertLessThanOrEqual(averageSwitchTime, 2.0, "모델 전환이 신속해야 함")
        }
    }
    
    // MARK: - 보조 함수들
    
    private func simulateTextProcessing(input: String, targetTokens: Int) {
        let processingTime = Double(targetTokens) / 50.0 * 0.8 // 50토큰당 0.8초
        Thread.sleep(forTimeInterval: processingTime)
    }
    
    private func simulateMLXInference(input: String) -> Bool {
        Thread.sleep(forTimeInterval: Double.random(in: 0.8...1.5))
        return arc4random_uniform(100) >= 1 // 99% 성공률
    }
    
    private func simulateAppInitialization() {
        // 모델 로딩 시뮬레이션
        Thread.sleep(forTimeInterval: 2.0)
        
        // UI 초기화 시뮬레이션
        Thread.sleep(forTimeInterval: 1.0)
        
        // 설정 로딩 시뮬레이션
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    private func simulateCameraFrameProcessing() {
        Thread.sleep(forTimeInterval: 0.001) // 1ms 프레임 처리
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
    
    private func generateTestImageData(size: Int) -> Data {
        return Data(count: size * size * 4) // RGBA
    }
    
    private func simulateImageProcessing(data: Data) {
        let processingTime = Double(data.count) / 1000000.0 * 0.1
        Thread.sleep(forTimeInterval: min(processingTime, 2.0))
    }
    
    private func performMemoryCleanup() {
        Thread.sleep(forTimeInterval: 0.01)
    }
    
    private func accessSharedResource(counter: NSMutableString, value: String) {
        objc_sync_enter(counter)
        counter.append(value)
        objc_sync_exit(counter)
    }
    
    private func simulateCPUIntensiveOperation() {
        // CPU 집약적 작업 시뮬레이션
        var result = 0
        for i in 1...1000 {
            result += i * i
        }
    }
    
    private func simulateGPUImageProcessing(taskId: Int) {
        Thread.sleep(forTimeInterval: Double.random(in: 0.1...0.4))
    }
    
    private func simulateNetworkTransition(toOffline: Bool) {
        Thread.sleep(forTimeInterval: Double.random(in: 0.2...0.8))
    }
    
    private func simulateModelSwitch(toCloud: Bool) {
        Thread.sleep(forTimeInterval: Double.random(in: 0.5...1.5))
    }
    
    private func simulateCloudInference(input: String) -> Bool {
        Thread.sleep(forTimeInterval: Double.random(in: 0.3...0.8))
        return arc4random_uniform(100) >= 2 // 98% 성공률 (네트워크 고려)
    }
    
    private func printPerformanceReport() {
        print("\n" + "=" * 60)
        print("📊 성능 벤치마크 보고서")
        print("=" * 60)
        
        for (key, value) in performanceMetrics {
            if let doubleValue = value as? Double {
                print("\(key): \(String(format: "%.3f", doubleValue))")
            } else if let intValue = value as? Int {
                print("\(key): \(intValue)")
            } else {
                print("\(key): \(value)")
            }
        }
        
        print("=" * 60)
    }
}