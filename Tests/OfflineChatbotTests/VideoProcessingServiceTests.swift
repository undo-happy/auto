import XCTest
@testable import OfflineChatbot
import AVFoundation
import UIKit

final class VideoProcessingServiceTests: XCTestCase {
    var videoProcessingService: VideoProcessingService!
    var mockImageProcessingService: MockImageProcessingService!
    
    override func setUp() {
        super.setUp()
        mockImageProcessingService = MockImageProcessingService()
        videoProcessingService = VideoProcessingService(imageProcessingService: mockImageProcessingService)
    }
    
    override func tearDown() {
        videoProcessingService = nil
        mockImageProcessingService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultValues_SetsCorrectly() {
        XCTAssertNotNil(videoProcessingService)
        XCTAssertFalse(videoProcessingService.isProcessing)
        XCTAssertEqual(videoProcessingService.processingProgress, 0.0)
        XCTAssertEqual(videoProcessingService.lastProcessingTime, 0.0)
        XCTAssertEqual(videoProcessingService.currentFrame, 0)
        XCTAssertEqual(videoProcessingService.totalFrames, 0)
    }
    
    // MARK: - Video Validation Tests
    
    func testValidateVideo_ValidVideo_Success() throws {
        let validVideoData = createMockMP4Data()
        XCTAssertNoThrow(try videoProcessingService.validateVideo(validVideoData))
    }
    
    func testValidateVideo_TooLarge_ThrowsError() {
        let largeVideoData = Data(count: 60 * 1024 * 1024) // 60MB
        
        XCTAssertThrowsError(try videoProcessingService.validateVideo(largeVideoData)) { error in
            guard case VideoProcessingService.VideoProcessingError.videoTooLarge = error else {
                XCTFail("Expected videoTooLarge error")
                return
            }
        }
    }
    
    func testValidateVideo_TooSmall_ThrowsError() {
        let smallVideoData = Data(count: 5000) // 5KB
        
        XCTAssertThrowsError(try videoProcessingService.validateVideo(smallVideoData)) { error in
            guard case VideoProcessingService.VideoProcessingError.invalidVideoData = error else {
                XCTFail("Expected invalidVideoData error")
                return
            }
        }
    }
    
    func testValidateVideo_UnsupportedFormat_ThrowsError() {
        let aviData = createMockAVIData()
        
        XCTAssertThrowsError(try videoProcessingService.validateVideo(aviData)) { error in
            guard case VideoProcessingService.VideoProcessingError.unsupportedFormat = error else {
                XCTFail("Expected unsupportedFormat error")
                return
            }
        }
    }
    
    // MARK: - Frame Extraction Tests
    
    func testExtractFrames_ValidVideo_ExtractsFrames() async throws {
        let testVideoURL = try createTestVideoFile()
        
        defer {
            try? FileManager.default.removeItem(at: testVideoURL)
        }
        
        let frames = try await videoProcessingService.extractFrames(from: testVideoURL, maxFrames: 5)
        
        XCTAssertFalse(frames.isEmpty)
        XCTAssertLessThanOrEqual(frames.count, 5)
        
        // 각 프레임이 유효한 UIImage인지 확인
        for frame in frames {
            XCTAssertGreaterThan(frame.size.width, 0)
            XCTAssertGreaterThan(frame.size.height, 0)
        }
    }
    
    func testExtractFrames_VideoTooLong_ThrowsError() async {
        let longVideoURL = try createTestVideoFile(duration: 35.0) // 35초
        
        defer {
            try? FileManager.default.removeItem(at: longVideoURL)
        }
        
        do {
            _ = try await videoProcessingService.extractFrames(from: longVideoURL, maxFrames: 5)
            XCTFail("Expected videoTooLong error")
        } catch VideoProcessingService.VideoProcessingError.videoTooLong {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Video Analysis Tests
    
    func testAnalyzeVideoFrames_ValidFrames_ReturnsAnalysis() async throws {
        let testFrames = createTestFrames(count: 3)
        mockImageProcessingService.mockDescription = "테스트 프레임 분석"
        
        let analysis = try await videoProcessingService.analyzeVideoFrames(testFrames)
        
        XCTAssertFalse(analysis.isEmpty)
        XCTAssertTrue(analysis.contains("MLX 비디오 분석"))
        XCTAssertTrue(analysis.contains("3개 프레임"))
        XCTAssertTrue(analysis.contains("Gemma 3n 모델"))
    }
    
    func testAnalyzeVideoFrames_EmptyFrames_ThrowsError() async {
        let emptyFrames: [UIImage] = []
        
        do {
            _ = try await videoProcessingService.analyzeVideoFrames(emptyFrames)
            XCTFail("Expected noFramesExtracted error")
        } catch VideoProcessingService.VideoProcessingError.noFramesExtracted {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Video Processing Integration Tests
    
    func testProcessVideo_FullPipeline_Success() async throws {
        let testVideoData = createMockMP4Data(duration: 10.0)
        mockImageProcessingService.mockDescription = "테스트 비디오 내용"
        mockImageProcessingService.mockObjects = [
            DetectedObject(label: "person", confidence: 0.9, boundingBox: CGRect.zero)
        ]
        
        let result = try await videoProcessingService.processVideo(testVideoData)
        
        XCTAssertGreaterThan(result.duration, 0)
        XCTAssertGreaterThan(result.frameRate, 0)
        XCTAssertGreaterThan(result.resolution.width, 0)
        XCTAssertGreaterThan(result.resolution.height, 0)
        XCTAssertEqual(result.format.lowercased(), "mp4")
        XCTAssertGreaterThan(result.totalFrames, 0)
        XCTAssertFalse(result.overallAnalysis.isEmpty)
        XCTAssertGreaterThan(result.processingTime, 0)
        
        // Check processing completed
        XCTAssertFalse(videoProcessingService.isProcessing)
        XCTAssertEqual(videoProcessingService.processingProgress, 1.0)
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProcessVideo_ProgressTracking_UpdatesCorrectly() async throws {
        let testVideoData = createMockMP4Data()
        mockImageProcessingService.mockDescription = "진행률 테스트"
        
        var progressValues: [Double] = []
        let progressExpectation = XCTestExpectation(description: "Progress updates")
        progressExpectation.expectedFulfillmentCount = 3
        
        let cancellable = videoProcessingService.$processingProgress
            .sink { progress in
                progressValues.append(progress)
                if progressValues.count >= 3 {
                    progressExpectation.fulfill()
                }
            }
        
        _ = try await videoProcessingService.processVideo(testVideoData)
        
        await fulfillment(of: [progressExpectation], timeout: 10.0)
        
        // Verify progress increased
        XCTAssertTrue(progressValues.contains { $0 > 0.0 })
        XCTAssertTrue(progressValues.contains { $0 >= 1.0 })
        
        cancellable.cancel()
    }
    
    // MARK: - Error Handling Tests
    
    func testVideoProcessingError_ErrorDescriptions_AreLocalized() {
        let errors: [VideoProcessingService.VideoProcessingError] = [
            .invalidVideoData,
            .unsupportedFormat("avi"),
            .videoTooLarge(1000000),
            .videoTooLong(45.0),
            .frameExtractionFailed,
            .noFramesExtracted,
            .analysisTimeout,
            .assetCreationFailed,
            .readerCreationFailed,
            .trackNotFound
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Metrics Tests
    
    func testGetVideoProcessingMetrics_ReturnsValidMetrics() {
        let metrics = videoProcessingService.getVideoProcessingMetrics()
        
        XCTAssertFalse(metrics.isProcessing)
        XCTAssertEqual(metrics.processingProgress, 0.0)
        XCTAssertEqual(metrics.lastProcessingTime, 0.0)
        XCTAssertEqual(metrics.currentFrame, 0)
        XCTAssertEqual(metrics.totalFrames, 0)
        XCTAssertEqual(metrics.progressPercentage, 0)
        XCTAssertEqual(metrics.frameProgress, "0/0")
        XCTAssertEqual(metrics.maxVideoLength, 30.0)
        XCTAssertEqual(metrics.maxFileSize, 50 * 1024 * 1024)
        XCTAssertEqual(metrics.maxFramesToExtract, 10)
        XCTAssertTrue(metrics.supportedFormats.contains("mp4"))
        XCTAssertTrue(metrics.supportedFormats.contains("mov"))
        XCTAssertEqual(metrics.performanceStatus, .excellent) // 0 duration
    }
    
    func testVideoProcessingStatus_CalculatesCorrectly() {
        let excellentMetrics = VideoProcessingMetrics(
            isProcessing: false,
            processingProgress: 1.0,
            lastProcessingTime: 3.0,
            currentFrame: 10,
            totalFrames: 10,
            maxVideoLength: 30.0,
            maxFileSize: 52428800,
            maxFramesToExtract: 10,
            supportedFormats: ["mp4", "mov"]
        )
        XCTAssertEqual(excellentMetrics.performanceStatus, .excellent)
        
        let goodMetrics = VideoProcessingMetrics(
            isProcessing: false,
            processingProgress: 1.0,
            lastProcessingTime: 10.0,
            currentFrame: 10,
            totalFrames: 10,
            maxVideoLength: 30.0,
            maxFileSize: 52428800,
            maxFramesToExtract: 10,
            supportedFormats: ["mp4", "mov"]
        )
        XCTAssertEqual(goodMetrics.performanceStatus, .good)
        
        let poorMetrics = VideoProcessingMetrics(
            isProcessing: false,
            processingProgress: 1.0,
            lastProcessingTime: 20.0,
            currentFrame: 10,
            totalFrames: 10,
            maxVideoLength: 30.0,
            maxFileSize: 52428800,
            maxFramesToExtract: 10,
            supportedFormats: ["mp4", "mov"]
        )
        XCTAssertEqual(poorMetrics.performanceStatus, .needsImprovement)
    }
    
    // MARK: - Video Analysis Result Tests
    
    func testVideoAnalysisResult_Properties_CalculateCorrectly() {
        let frames = createTestFrames(count: 5)
        let frameAnalyses = [
            FrameAnalysis(
                frameIndex: 0,
                timestamp: 0.0,
                objects: [DetectedObject(label: "cat", confidence: 0.9, boundingBox: CGRect.zero)],
                texts: [RecognizedText(text: "Hello", confidence: 0.95, boundingBox: CGRect.zero)],
                description: "Frame 0",
                confidence: 0.9
            ),
            FrameAnalysis(
                frameIndex: 1,
                timestamp: 1.0,
                objects: [DetectedObject(label: "dog", confidence: 0.8, boundingBox: CGRect.zero)],
                texts: [RecognizedText(text: "World", confidence: 0.85, boundingBox: CGRect.zero)],
                description: "Frame 1",
                confidence: 0.8
            )
        ]
        
        let result = VideoAnalysisResult(
            duration: 10.0,
            frameRate: 30.0,
            resolution: CGSize(width: 1920, height: 1080),
            fileSize: 1000000,
            format: "mp4",
            totalFrames: 5,
            extractedFrames: frames,
            frameAnalyses: frameAnalyses,
            overallAnalysis: "Test video analysis",
            processingTime: 5.0,
            videoInfo: VideoInfo(
                duration: 10.0,
                frameRate: 30.0,
                resolution: CGSize(width: 1920, height: 1080),
                format: "mp4"
            )
        )
        
        XCTAssertTrue(result.hasFrames)
        XCTAssertEqual(result.averageConfidence, 0.85)
        XCTAssertEqual(result.detectedObjects.sorted(), ["cat", "dog"])
        XCTAssertEqual(result.extractedTexts, ["Hello", "World"])
    }
    
    func testVideoInfo_Properties_FormatCorrectly() {
        let videoInfo = VideoInfo(
            duration: 125.5,
            frameRate: 29.97,
            resolution: CGSize(width: 1280, height: 720),
            format: "mp4"
        )
        
        XCTAssertEqual(videoInfo.durationString, "02:05")
        XCTAssertEqual(videoInfo.resolutionString, "1280x720")
    }
    
    // MARK: - Performance Tests
    
    func testProcessVideo_Performance_MeetsRequirements() async throws {
        let testVideoData = createMockMP4Data(duration: 5.0)
        mockImageProcessingService.mockDescription = "성능 테스트"
        
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await videoProcessingService.processVideo(testVideoData)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete within reasonable time (30 seconds for video processing)
        XCTAssertLessThan(processingTime, 30.0)
        XCTAssertGreaterThan(videoProcessingService.lastProcessingTime, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestFrames(count: Int) -> [UIImage] {
        var frames: [UIImage] = []
        
        for i in 0..<count {
            let size = CGSize(width: 640, height: 480)
            UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
            
            // Create different colored frames
            let colors: [UIColor] = [.red, .green, .blue, .yellow, .purple]
            colors[i % colors.count].setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let image = image {
                frames.append(image)
            }
        }
        
        return frames
    }
    
    private func createMockMP4Data(duration: TimeInterval = 10.0) -> Data {
        // MP4 file header signature
        var mp4Data = Data([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70])
        mp4Data.append(Data([0x69, 0x73, 0x6F, 0x6D])) // isom
        mp4Data.append(Data(count: Int(duration * 1000))) // Add content based on duration
        return mp4Data
    }
    
    private func createMockAVIData() -> Data {
        // AVI file header (unsupported format)
        var aviData = Data([0x52, 0x49, 0x46, 0x46]) // "RIFF"
        aviData.append(Data([0x00, 0x00, 0x00, 0x00])) // File size
        aviData.append(Data([0x41, 0x56, 0x49, 0x20])) // "AVI "
        aviData.append(Data(count: 10000))
        return aviData
    }
    
    private func createTestVideoFile(duration: TimeInterval = 10.0) throws -> URL {
        // Create a simple test video file
        let tempDirectory = FileManager.default.temporaryDirectory
        let videoURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        
        // Use a simple video creation approach for testing
        try createSimpleVideoFile(at: videoURL, duration: duration)
        
        return videoURL
    }
    
    private func createSimpleVideoFile(at url: URL, duration: TimeInterval) throws {
        // Create a minimal video file for testing
        // In a real test environment, you might use AVAssetWriter to create actual video files
        let mockVideoData = createMockMP4Data(duration: duration)
        try mockVideoData.write(to: url)
    }
}

// MARK: - Mock Image Processing Service

class MockImageProcessingService: ImageProcessingService {
    var mockDescription = "Mock image analysis"
    var mockObjects: [DetectedObject] = []
    var mockTexts: [RecognizedText] = []
    var shouldFail = false
    
    override func processImage(_ imageData: Data) async throws -> ImageAnalysisResult {
        if shouldFail {
            throw ImageProcessingError.processingFailed("Mock failure")
        }
        
        return ImageAnalysisResult(
            originalSize: CGSize(width: 640, height: 480),
            processedSize: CGSize(width: 640, height: 480),
            fileSize: imageData.count,
            format: "jpeg",
            objects: mockObjects,
            texts: mockTexts,
            contentDescription: mockDescription,
            confidence: 0.85,
            processingTime: 0.1,
            metadata: ImageMetadata(
                originalSize: CGSize(width: 640, height: 480),
                processedSize: CGSize(width: 640, height: 480),
                compressionQuality: 0.8,
                wasResized: false,
                processingTimestamp: Date()
            )
        )
    }
    
    override func analyzeImageContent(_ image: UIImage) async throws -> String {
        if shouldFail {
            throw ImageProcessingError.analysisTimeout
        }
        
        return mockDescription
    }
}