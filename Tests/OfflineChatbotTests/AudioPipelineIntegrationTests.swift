import XCTest
@testable import OfflineChatbot
@testable import AudioProcessing
@testable import MLModel

final class AudioPipelineIntegrationTests: XCTestCase {
    var audioPipelineService: AudioPipelineService!
    var mockInferenceService: MockInferenceService!
    var mockTranscriptionService: MockTranscriptionService!
    var mockTTSService: MockTTSService!
    
    override func setUp() {
        super.setUp()
        
        mockInferenceService = MockInferenceService()
        mockTranscriptionService = MockTranscriptionService()
        mockTTSService = MockTTSService()
        
        audioPipelineService = AudioPipelineService(
            transcriptionService: mockTranscriptionService,
            ttsService: mockTTSService,
            inferenceService: mockInferenceService
        )
    }
    
    override func tearDown() {
        audioPipelineService?.stopAllAudioProcessing()
        audioPipelineService = nil
        mockInferenceService = nil
        mockTranscriptionService = nil
        mockTTSService = nil
        super.tearDown()
    }
    
    // MARK: - Full Pipeline Tests
    
    func testProcessAudioInput_FullPipeline_Success() async throws {
        // Setup mocks
        mockTranscriptionService.mockTranscription = "안녕하세요"
        mockInferenceService.mockResponse = "안녕하세요! 무엇을 도와드릴까요?"
        mockTTSService.shouldSucceed = true
        
        let audioData = createMockAudioData()
        
        let result = try await audioPipelineService.processAudioInput(audioData)
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.transcribedText, "안녕하세요")
        XCTAssertEqual(result.responseText, "안녕하세요! 무엇을 도와드릴까요?")
        XCTAssertGreaterThan(result.processingTime, 0)
        XCTAssertEqual(result.transcriptionWordCount, 1)
        XCTAssertEqual(result.responseWordCount, 3)
        
        // Verify pipeline completed
        XCTAssertEqual(audioPipelineService.currentStage, .completed)
        XCTAssertFalse(audioPipelineService.isProcessingAudio)
        XCTAssertEqual(audioPipelineService.processingProgress, 1.0)
    }
    
    func testProcessAudioInput_TranscriptionFails_HandlesError() async {
        // Setup transcription failure
        mockTranscriptionService.shouldFail = true
        
        let audioData = createMockAudioData()
        
        do {
            _ = try await audioPipelineService.processAudioInput(audioData)
            XCTFail("Expected transcription error")
        } catch AudioPipelineService.AudioPipelineError.transcriptionFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Verify error state
        if case .failed = audioPipelineService.currentStage {
            // Expected
        } else {
            XCTFail("Expected failed stage")
        }
        XCTAssertFalse(audioPipelineService.isProcessingAudio)
    }
    
    func testProcessAudioInput_InferenceFails_HandlesError() async {
        // Setup inference failure
        mockTranscriptionService.mockTranscription = "테스트"
        mockInferenceService.shouldFail = true
        
        let audioData = createMockAudioData()
        
        do {
            _ = try await audioPipelineService.processAudioInput(audioData)
            XCTFail("Expected inference error")
        } catch AudioPipelineService.AudioPipelineError.inferenceFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testProcessAudioInput_TTSFails_HandlesError() async {
        // Setup TTS failure
        mockTranscriptionService.mockTranscription = "테스트"
        mockInferenceService.mockResponse = "응답"
        mockTTSService.shouldFail = true
        
        let audioData = createMockAudioData()
        
        do {
            _ = try await audioPipelineService.processAudioInput(audioData)
            XCTFail("Expected TTS error")
        } catch AudioPipelineService.AudioPipelineError.synthesisFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Stage Progression Tests
    
    func testProcessAudioInput_StageProgression_UpdatesCorrectly() async throws {
        // Setup mocks with delays to observe stage changes
        mockTranscriptionService.mockTranscription = "테스트"
        mockTranscriptionService.processingDelay = 0.1
        mockInferenceService.mockResponse = "응답"
        mockInferenceService.processingDelay = 0.1
        mockTTSService.shouldSucceed = true
        mockTTSService.processingDelay = 0.1
        
        let audioData = createMockAudioData()
        
        // Start processing
        let processingTask = Task {
            try await audioPipelineService.processAudioInput(audioData)
        }
        
        // Check initial state
        XCTAssertEqual(audioPipelineService.currentStage, .transcribing)
        XCTAssertTrue(audioPipelineService.isProcessingAudio)
        
        // Wait for completion
        _ = try await processingTask.value
        
        // Check final state
        XCTAssertEqual(audioPipelineService.currentStage, .completed)
        XCTAssertFalse(audioPipelineService.isProcessingAudio)
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProcessAudioInput_ProgressTracking_UpdatesCorrectly() async throws {
        mockTranscriptionService.mockTranscription = "진행률 테스트"
        mockInferenceService.mockResponse = "진행률 응답"
        mockTTSService.shouldSucceed = true
        
        let audioData = createMockAudioData()
        
        var progressValues: [Double] = []
        let progressExpectation = XCTestExpectation(description: "Progress updates")
        progressExpectation.expectedFulfillmentCount = 3 // At least 3 progress updates
        
        // Monitor progress changes
        let cancellable = audioPipelineService.$processingProgress
            .sink { progress in
                progressValues.append(progress)
                if progressValues.count >= 3 {
                    progressExpectation.fulfill()
                }
            }
        
        _ = try await audioPipelineService.processAudioInput(audioData)
        
        await fulfillment(of: [progressExpectation], timeout: 2.0)
        
        // Verify progress increased
        XCTAssertTrue(progressValues.contains { $0 > 0.0 })
        XCTAssertTrue(progressValues.contains { $0 >= 1.0 })
        
        cancellable.cancel()
    }
    
    // MARK: - Real-time Transcription Tests
    
    func testStartRealTimeTranscription_Success() async throws {
        mockTranscriptionService.shouldSucceed = true
        
        try await audioPipelineService.startRealTimeTranscription()
        
        XCTAssertTrue(audioPipelineService.isTranscribing)
        XCTAssertTrue(mockTranscriptionService.isTranscribing)
    }
    
    func testStopRealTimeTranscription_StopsCorrectly() {
        audioPipelineService.stopRealTimeTranscription()
        
        XCTAssertFalse(audioPipelineService.isTranscribing)
        XCTAssertFalse(mockTranscriptionService.isTranscribing)
    }
    
    // MARK: - TTS Only Tests
    
    func testProcessTextToSpeech_Success() async throws {
        mockTTSService.shouldSucceed = true
        
        try await audioPipelineService.processTextToSpeech("테스트 음성 출력")
        
        XCTAssertEqual(audioPipelineService.currentStage, .completed)
        XCTAssertEqual(mockTTSService.lastSpokenText, "테스트 음성 출력")
    }
    
    func testProcessTextToSpeech_Failure() async {
        mockTTSService.shouldFail = true
        
        do {
            try await audioPipelineService.processTextToSpeech("실패 테스트")
            XCTFail("Expected TTS error")
        } catch AudioPipelineService.AudioPipelineError.synthesisFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Control Tests
    
    func testStopAllAudioProcessing_StopsEverything() {
        // Start some processing
        mockTranscriptionService.isTranscribing = true
        mockTTSService.isSpeaking = true
        audioPipelineService.isProcessingAudio = true
        
        audioPipelineService.stopAllAudioProcessing()
        
        XCTAssertFalse(audioPipelineService.isProcessingAudio)
        XCTAssertFalse(audioPipelineService.isTranscribing)
        XCTAssertFalse(audioPipelineService.isSpeaking)
        XCTAssertEqual(audioPipelineService.currentStage, .idle)
        XCTAssertEqual(audioPipelineService.processingProgress, 0.0)
    }
    
    func testPauseResumeTTS_WorksCorrectly() {
        audioPipelineService.pauseTTS()
        XCTAssertTrue(mockTTSService.isPaused)
        
        audioPipelineService.resumeTTS()
        XCTAssertFalse(mockTTSService.isPaused)
    }
    
    // MARK: - Metrics Tests
    
    func testGetAudioMetrics_ReturnsValidMetrics() {
        let metrics = audioPipelineService.getAudioMetrics()
        
        XCTAssertFalse(metrics.isProcessingAudio)
        XCTAssertEqual(metrics.currentStage, .idle)
        XCTAssertEqual(metrics.processingProgress, 0.0)
        XCTAssertEqual(metrics.progressPercentage, 0)
        XCTAssertFalse(metrics.isAudioInputActive)
        XCTAssertFalse(metrics.isAudioOutputActive)
        XCTAssertEqual(metrics.performanceStatus, .excellent) // 0 duration
    }
    
    func testAudioPerformanceStatus_CalculatesCorrectly() {
        // Test excellent performance
        audioPipelineService.lastAudioDuration = 2.0
        let excellentMetrics = audioPipelineService.getAudioMetrics()
        XCTAssertEqual(excellentMetrics.performanceStatus, .excellent)
        
        // Test good performance
        audioPipelineService.lastAudioDuration = 4.0
        let goodMetrics = audioPipelineService.getAudioMetrics()
        XCTAssertEqual(goodMetrics.performanceStatus, .good)
        
        // Test needs improvement
        audioPipelineService.lastAudioDuration = 8.0
        let poorMetrics = audioPipelineService.getAudioMetrics()
        XCTAssertEqual(poorMetrics.performanceStatus, .needsImprovement)
    }
    
    // MARK: - Convenience Property Tests
    
    func testConvenienceProperties_ReturnCorrectValues() {
        mockTranscriptionService.isTranscribing = true
        mockTranscriptionService.currentTranscription = "현재 전사 중"
        mockTranscriptionService.audioLevel = 0.75
        mockTTSService.isSpeaking = true
        
        XCTAssertTrue(audioPipelineService.isTranscribing)
        XCTAssertTrue(audioPipelineService.isSpeaking)
        XCTAssertEqual(audioPipelineService.currentTranscription, "현재 전사 중")
        XCTAssertEqual(audioPipelineService.audioLevel, 0.75)
    }
    
    // MARK: - Helper Methods
    
    private func createMockAudioData() -> Data {
        return Data(count: 50_000) // Valid size audio data
    }
}

// MARK: - Mock Services

class MockTranscriptionService: AudioTranscriptionService {
    var mockTranscription = "Mock transcription"
    var shouldFail = false
    var shouldSucceed = true
    var processingDelay: TimeInterval = 0.0
    
    override var isTranscribing: Bool {
        get { return _isTranscribing }
        set { _isTranscribing = newValue }
    }
    private var _isTranscribing = false
    
    override var currentTranscription: String {
        get { return _currentTranscription }
        set { _currentTranscription = newValue }
    }
    private var _currentTranscription = ""
    
    override var audioLevel: Float {
        get { return _audioLevel }
        set { _audioLevel = newValue }
    }
    private var _audioLevel: Float = 0.0
    
    override func transcribeAudio(_ audioData: Data) async throws -> String {
        if processingDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        }
        
        if shouldFail {
            throw TranscriptionError.transcriptionFailed("Mock failure")
        }
        
        return mockTranscription
    }
    
    override func startRealTimeTranscription() async throws {
        if shouldFail {
            throw TranscriptionError.permissionDenied
        }
        _isTranscribing = true
    }
    
    override func stopRealTimeTranscription() {
        _isTranscribing = false
        _currentTranscription = ""
        _audioLevel = 0.0
    }
}

class MockTTSService: TextToSpeechService {
    var shouldFail = false
    var shouldSucceed = true
    var processingDelay: TimeInterval = 0.0
    var lastSpokenText: String?
    
    override var isSpeaking: Bool {
        get { return _isSpeaking }
        set { _isSpeaking = newValue }
    }
    private var _isSpeaking = false
    
    override var isPaused: Bool {
        get { return _isPaused }
        set { _isPaused = newValue }
    }
    private var _isPaused = false
    
    override func speakText(_ text: String) async throws {
        lastSpokenText = text
        
        if processingDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        }
        
        if shouldFail {
            throw TTSError.speakingFailed("Mock failure")
        }
        
        _isSpeaking = true
        
        // Simulate speaking completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self._isSpeaking = false
        }
    }
    
    override func stopSpeaking() {
        _isSpeaking = false
        _isPaused = false
    }
    
    override func pauseSpeaking() {
        _isPaused = true
    }
    
    override func continueSpeaking() {
        _isPaused = false
    }
}

class MockInferenceService: ModelInferenceService {
    var mockResponse = "Mock response"
    var shouldFail = false
    var processingDelay: TimeInterval = 0.0
    
    override func generateAudioResponse(for audioData: Data) async throws -> String {
        if processingDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        }
        
        if shouldFail {
            throw InferenceError.modelNotReady
        }
        
        return mockResponse
    }
}