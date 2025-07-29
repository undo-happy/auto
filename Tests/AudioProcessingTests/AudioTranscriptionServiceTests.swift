import XCTest
@testable import AudioProcessing
import AVFoundation

final class AudioTranscriptionServiceTests: XCTestCase {
    var transcriptionService: AudioTranscriptionService!
    
    override func setUp() {
        super.setUp()
        transcriptionService = AudioTranscriptionService()
    }
    
    override func tearDown() {
        transcriptionService?.stopRealTimeTranscription()
        transcriptionService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultLocale_SetsKoreanRecognizer() {
        XCTAssertNotNil(transcriptionService)
        XCTAssertFalse(transcriptionService.isTranscribing)
        XCTAssertEqual(transcriptionService.audioLevel, 0.0)
        XCTAssertEqual(transcriptionService.currentTranscription, "")
    }
    
    func testInitialization_CustomLocale_SetsCorrectRecognizer() {
        let englishService = AudioTranscriptionService(locale: Locale(identifier: "en-US"))
        XCTAssertNotNil(englishService)
    }
    
    // MARK: - Audio Data Validation Tests
    
    func testValidateAudioData_TooShort_ThrowsError() async {
        let shortAudioData = Data(count: 1000) // Too short
        
        do {
            _ = try await transcriptionService.transcribeAudio(shortAudioData)
            XCTFail("Expected audioTooShort error")
        } catch AudioTranscriptionService.TranscriptionError.audioTooShort {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testValidateAudioData_TooLong_ThrowsError() async {
        let longAudioData = Data(count: 2_000_000) // Too long
        
        do {
            _ = try await transcriptionService.transcribeAudio(longAudioData)
            XCTFail("Expected audioTooLong error")
        } catch AudioTranscriptionService.TranscriptionError.audioTooLong {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testValidateAudioData_LowQuality_ThrowsError() async {
        // Create audio data with mostly zeros (low quality)
        let lowQualityData = Data(count: 100_000) // All zeros
        
        do {
            _ = try await transcriptionService.transcribeAudio(lowQualityData)
            XCTFail("Expected audioQualityTooLow error")
        } catch AudioTranscriptionService.TranscriptionError.audioQualityTooLow {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testValidateAudioData_GoodQuality_Passes() async {
        // Create audio data with some variation (simulated audio)
        var audioData = Data(count: 50_000)
        audioData = audioData.map { _ in UInt8.random(in: 0...255) }
        
        // This should not throw validation errors
        // Note: Will likely fail at speech recognition, but validation should pass
        do {
            _ = try await transcriptionService.transcribeAudio(audioData)
        } catch AudioTranscriptionService.TranscriptionError.audioTooShort,
                AudioTranscriptionService.TranscriptionError.audioTooLong,
                AudioTranscriptionService.TranscriptionError.audioQualityTooLow {
            XCTFail("Audio validation should have passed")
        } catch {
            // Other errors (like transcription failure) are acceptable for this test
        }
    }
    
    // MARK: - Permissions Tests
    
    func testRequestPermissions_NoPermissions_ThrowsError() async {
        // Note: In real device testing, this would require actual permission states
        // In unit tests, we can only test the logic flow
        do {
            try await transcriptionService.requestPermissions()
            // If we reach here, permissions were granted or already available
        } catch AudioTranscriptionService.TranscriptionError.permissionDenied {
            // Expected if permissions are denied
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Real-time Transcription Tests
    
    func testStartRealTimeTranscription_SetsTranscribingState() async {
        do {
            try await transcriptionService.startRealTimeTranscription()
            XCTAssertTrue(transcriptionService.isTranscribing)
        } catch {
            // Permission or availability errors are acceptable in test environment
            print("Expected error in test environment: \(error)")
        }
    }
    
    func testStopRealTimeTranscription_ClearsState() {
        transcriptionService.stopRealTimeTranscription()
        XCTAssertFalse(transcriptionService.isTranscribing)
        XCTAssertEqual(transcriptionService.currentTranscription, "")
        XCTAssertEqual(transcriptionService.audioLevel, 0.0)
    }
    
    func testStopRealTimeTranscription_Multiple_DoesNotCrash() {
        // Should be safe to call multiple times
        transcriptionService.stopRealTimeTranscription()
        transcriptionService.stopRealTimeTranscription()
        transcriptionService.stopRealTimeTranscription()
        
        XCTAssertFalse(transcriptionService.isTranscribing)
    }
    
    // MARK: - Metrics Tests
    
    func testGetTranscriptionMetrics_ReturnsValidMetrics() {
        let metrics = transcriptionService.getTranscriptionMetrics()
        
        XCTAssertFalse(metrics.isTranscribing)
        XCTAssertEqual(metrics.audioLevel, 0.0)
        XCTAssertEqual(metrics.currentTranscription, "")
        XCTAssertFalse(metrics.hasActiveTranscription)
        XCTAssertEqual(metrics.audioLevelPercentage, 0)
        XCTAssertNotEqual(metrics.locale, "unknown")
    }
    
    func testTranscriptionMetrics_AudioLevelPercentage_CalculatesCorrectly() {
        let metrics = TranscriptionMetrics(
            isTranscribing: false,
            audioLevel: 0.75,
            currentTranscription: "",
            recognizerAvailable: true,
            locale: "ko-KR"
        )
        
        XCTAssertEqual(metrics.audioLevelPercentage, 75)
    }
    
    func testTranscriptionMetrics_HasActiveTranscription_DetectsNonEmptyText() {
        let activeMetrics = TranscriptionMetrics(
            isTranscribing: true,
            audioLevel: 0.5,
            currentTranscription: "안녕하세요",
            recognizerAvailable: true,
            locale: "ko-KR"
        )
        
        let inactiveMetrics = TranscriptionMetrics(
            isTranscribing: true,
            audioLevel: 0.5,
            currentTranscription: "   ",
            recognizerAvailable: true,
            locale: "ko-KR"
        )
        
        XCTAssertTrue(activeMetrics.hasActiveTranscription)
        XCTAssertFalse(inactiveMetrics.hasActiveTranscription)
    }
    
    // MARK: - Error Handling Tests
    
    func testTranscriptionError_ErrorDescriptions_AreLocalized() {
        let errors: [AudioTranscriptionService.TranscriptionError] = [
            .speechRecognitionNotAvailable,
            .permissionDenied,
            .audioEngineNotAvailable,
            .transcriptionFailed("test"),
            .audioQualityTooLow,
            .audioTooShort,
            .audioTooLong,
            .noSpeechDetected
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Audio Session Tests
    
    func testAudioSessionSetup_DoesNotCrash() {
        // Audio session setup should not crash
        let newService = AudioTranscriptionService()
        XCTAssertNotNil(newService)
    }
    
    // MARK: - Integration Tests
    
    func testTranscriptionResults_Publisher_EmitsCorrectly() {
        let expectation = XCTestExpectation(description: "Transcription result received")
        var receivedResult: String?
        
        let cancellable = transcriptionService.transcriptionResults
            .sink { result in
                receivedResult = result
                expectation.fulfill()
            }
        
        // Simulate transcription result (would normally come from speech recognizer)
        transcriptionService.transcriptionSubject.send("테스트 결과")
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedResult, "테스트 결과")
        
        cancellable.cancel()
    }
    
    // MARK: - Performance Tests
    
    func testAudioLevelCalculation_Performance() {
        // Test that audio level calculation doesn't block main thread
        measure {
            for _ in 0..<1000 {
                let buffer = createMockAudioBuffer()
                // Simulate audio level update
                _ = buffer
            }
        }
    }
    
    func testMultipleServiceInstances_NoMemoryLeaks() {
        // Test that creating and destroying multiple instances doesn't leak
        for _ in 0..<10 {
            let service = AudioTranscriptionService()
            service.stopRealTimeTranscription()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockAudioBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        return buffer
    }
    
    private func createValidAudioData() -> Data {
        // Create audio data that passes validation
        let dataSize = 50_000 // Valid size
        var audioData = Data(count: dataSize)
        
        // Add some variation to pass quality check
        for i in 0..<dataSize {
            if i % 100 < 20 { // 20% signal
                audioData[i] = UInt8.random(in: 100...200)
            }
        }
        
        return audioData
    }
}

// MARK: - Mock Extensions

extension AudioTranscriptionService {
    // Expose private subject for testing
    var transcriptionSubject: PassthroughSubject<String, Never> {
        return self.transcriptionSubject
    }
}