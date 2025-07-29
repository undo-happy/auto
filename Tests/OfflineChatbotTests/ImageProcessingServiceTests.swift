import XCTest
@testable import OfflineChatbot
import UIKit

final class ImageProcessingServiceTests: XCTestCase {
    var imageProcessingService: ImageProcessingService!
    
    override func setUp() {
        super.setUp()
        imageProcessingService = ImageProcessingService()
    }
    
    override func tearDown() {
        imageProcessingService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultValues_SetsCorrectly() {
        XCTAssertNotNil(imageProcessingService)
        XCTAssertFalse(imageProcessingService.isProcessing)
        XCTAssertEqual(imageProcessingService.processingProgress, 0.0)
        XCTAssertEqual(imageProcessingService.lastProcessingTime, 0.0)
    }
    
    // MARK: - Image Validation Tests
    
    func testValidateImage_ValidJPEG_Success() throws {
        let validJPEGData = createMockJPEGData()
        XCTAssertNoThrow(try imageProcessingService.validateImage(validJPEGData))
    }
    
    func testValidateImage_TooLarge_ThrowsError() {
        let largeImageData = Data(count: 15 * 1024 * 1024) // 15MB
        
        XCTAssertThrowsError(try imageProcessingService.validateImage(largeImageData)) { error in
            guard case ImageProcessingService.ImageProcessingError.imageTooLarge = error else {
                XCTFail("Expected imageTooLarge error")
                return
            }
        }
    }
    
    func testValidateImage_TooSmall_ThrowsError() {
        let smallImageData = Data(count: 500) // 500 bytes
        
        XCTAssertThrowsError(try imageProcessingService.validateImage(smallImageData)) { error in
            guard case ImageProcessingService.ImageProcessingError.invalidImageData = error else {
                XCTFail("Expected invalidImageData error")
                return
            }
        }
    }
    
    func testValidateImage_UnsupportedFormat_ThrowsError() {
        let bmpData = createMockBMPData()
        
        XCTAssertThrowsError(try imageProcessingService.validateImage(bmpData)) { error in
            guard case ImageProcessingService.ImageProcessingError.unsupportedFormat = error else {
                XCTFail("Expected unsupportedFormat error")
                return
            }
        }
    }
    
    func testValidateImage_CorruptedData_ThrowsError() {
        let corruptedData = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: 0x00, count: 1000))
        
        XCTAssertThrowsError(try imageProcessingService.validateImage(corruptedData)) { error in
            guard case ImageProcessingService.ImageProcessingError.invalidImageData = error else {
                XCTFail("Expected invalidImageData error")
                return
            }
        }
    }
    
    // MARK: - Image Preprocessing Tests
    
    func testPreprocessImage_SmallImage_NoResize() throws {
        let smallImage = createTestImage(size: CGSize(width: 500, height: 500))
        let result = try imageProcessingService.preprocessImage(smallImage)
        
        XCTAssertEqual(result.image.size, smallImage.size)
        XCTAssertFalse(result.metadata.wasResized)
        XCTAssertEqual(result.metadata.originalSize, smallImage.size)
        XCTAssertNotNil(result.data)
    }
    
    func testPreprocessImage_LargeImage_Resizes() throws {
        let largeImage = createTestImage(size: CGSize(width: 2000, height: 2000))
        let result = try imageProcessingService.preprocessImage(largeImage)
        
        XCTAssertTrue(result.image.size.width <= 1024)
        XCTAssertTrue(result.image.size.height <= 1024)
        XCTAssertTrue(result.metadata.wasResized)
        XCTAssertEqual(result.metadata.originalSize, largeImage.size)
        XCTAssertGreaterThan(result.metadata.sizeReduction, 0)
    }
    
    func testPreprocessImage_AspectRatioPreserved() throws {
        let rectangularImage = createTestImage(size: CGSize(width: 1600, height: 800))
        let result = try imageProcessingService.preprocessImage(rectangularImage)
        
        let originalRatio = rectangularImage.size.width / rectangularImage.size.height
        let processedRatio = result.image.size.width / result.image.size.height
        
        XCTAssertEqual(originalRatio, processedRatio, accuracy: 0.01)
    }
    
    // MARK: - Image Analysis Tests
    
    func testAnalyzeImageContent_ValidImage_ReturnsDescription() async throws {
        let testImage = createTestImage(size: CGSize(width: 800, height: 600))
        let description = try await imageProcessingService.analyzeImageContent(testImage)
        
        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.contains("이미지"))
    }
    
    func testProcessImage_FullPipeline_Success() async throws {
        let testImageData = createMockJPEGData(size: CGSize(width: 800, height: 600))
        
        let result = try await imageProcessingService.processImage(testImageData)
        
        XCTAssertEqual(result.format.lowercased(), "jpeg")
        XCTAssertGreaterThan(result.processingTime, 0)
        XCTAssertGreaterThan(result.confidence, 0)
        XCTAssertFalse(result.contentDescription.isEmpty)
        XCTAssertNotNil(result.metadata)
        
        // Check that processing completed
        XCTAssertFalse(imageProcessingService.isProcessing)
        XCTAssertEqual(imageProcessingService.processingProgress, 1.0)
    }
    
    // MARK: - Format Detection Tests
    
    func testFormatDetection_JPEG_DetectsCorrectly() throws {
        let jpegData = createMockJPEGData()
        try imageProcessingService.validateImage(jpegData)
        // If validation passes, format was correctly detected as supported
    }
    
    func testFormatDetection_PNG_DetectsCorrectly() throws {
        let pngData = createMockPNGData()
        try imageProcessingService.validateImage(pngData)
        // If validation passes, format was correctly detected as supported
    }
    
    // MARK: - Error Handling Tests
    
    func testImageProcessingError_ErrorDescriptions_AreLocalized() {
        let errors: [ImageProcessingService.ImageProcessingError] = [
            .invalidImageData,
            .unsupportedFormat("bmp"),
            .imageTooLarge(1000000),
            .resolutionTooHigh(CGSize(width: 5000, height: 5000)),
            .processingFailed("test"),
            .analysisTimeout,
            .noContent,
            .visionFrameworkError(NSError(domain: "test", code: 1))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProcessImage_ProgressTracking_UpdatesCorrectly() async throws {
        let testImageData = createMockJPEGData()
        
        var progressValues: [Double] = []
        let progressExpectation = XCTestExpectation(description: "Progress updates")
        progressExpectation.expectedFulfillmentCount = 3
        
        let cancellable = imageProcessingService.$processingProgress
            .sink { progress in
                progressValues.append(progress)
                if progressValues.count >= 3 {
                    progressExpectation.fulfill()
                }
            }
        
        _ = try await imageProcessingService.processImage(testImageData)
        
        await fulfillment(of: [progressExpectation], timeout: 5.0)
        
        // Verify progress increased
        XCTAssertTrue(progressValues.contains { $0 > 0.0 })
        XCTAssertTrue(progressValues.contains { $0 >= 1.0 })
        
        cancellable.cancel()
    }
    
    // MARK: - Metrics Tests
    
    func testGetImageProcessingMetrics_ReturnsValidMetrics() {
        let metrics = imageProcessingService.getImageProcessingMetrics()
        
        XCTAssertFalse(metrics.isProcessing)
        XCTAssertEqual(metrics.processingProgress, 0.0)
        XCTAssertEqual(metrics.lastProcessingTime, 0.0)
        XCTAssertEqual(metrics.progressPercentage, 0)
        XCTAssertEqual(metrics.maxImageSize, CGSize(width: 1024, height: 1024))
        XCTAssertEqual(metrics.maxFileSize, 10 * 1024 * 1024)
        XCTAssertTrue(metrics.supportedFormats.contains("jpeg"))
        XCTAssertTrue(metrics.supportedFormats.contains("png"))
        XCTAssertEqual(metrics.performanceStatus, .excellent) // 0 duration
    }
    
    func testImageProcessingStatus_CalculatesCorrectly() {
        let excellentMetrics = ImageProcessingMetrics(
            isProcessing: false,
            processingProgress: 1.0,
            lastProcessingTime: 0.5,
            maxImageSize: CGSize(width: 1024, height: 1024),
            maxFileSize: 10485760,
            supportedFormats: ["jpeg", "png"]
        )
        XCTAssertEqual(excellentMetrics.performanceStatus, .excellent)
        
        let goodMetrics = ImageProcessingMetrics(
            isProcessing: false,
            processingProgress: 1.0,
            lastProcessingTime: 2.0,
            maxImageSize: CGSize(width: 1024, height: 1024),
            maxFileSize: 10485760,
            supportedFormats: ["jpeg", "png"]
        )
        XCTAssertEqual(goodMetrics.performanceStatus, .good)
        
        let poorMetrics = ImageProcessingMetrics(
            isProcessing: false,
            processingProgress: 1.0,
            lastProcessingTime: 5.0,
            maxImageSize: CGSize(width: 1024, height: 1024),
            maxFileSize: 10485760,
            supportedFormats: ["jpeg", "png"]
        )
        XCTAssertEqual(poorMetrics.performanceStatus, .needsImprovement)
    }
    
    // MARK: - Analysis Result Tests
    
    func testImageAnalysisResult_Properties_CalculateCorrectly() {
        let result = ImageAnalysisResult(
            originalSize: CGSize(width: 1920, height: 1080),
            processedSize: CGSize(width: 960, height: 540),
            fileSize: 100000,
            format: "jpeg",
            objects: [
                DetectedObject(label: "cat", confidence: 0.9, boundingBox: CGRect.zero),
                DetectedObject(label: "dog", confidence: 0.8, boundingBox: CGRect.zero)
            ],
            texts: [
                RecognizedText(text: "Hello", confidence: 0.95, boundingBox: CGRect.zero),
                RecognizedText(text: "World", confidence: 0.85, boundingBox: CGRect.zero)
            ],
            contentDescription: "Test image",
            confidence: 0.85,
            processingTime: 1.5,
            metadata: ImageMetadata(
                originalSize: CGSize(width: 1920, height: 1080),
                processedSize: CGSize(width: 960, height: 540),
                compressionQuality: 0.8,
                wasResized: true,
                processingTimestamp: Date()
            )
        )
        
        XCTAssertTrue(result.hasObjects)
        XCTAssertTrue(result.hasText)
        XCTAssertEqual(result.combinedText, "Hello World")
        XCTAssertEqual(result.objectLabels, ["cat", "dog"])
    }
    
    // MARK: - Performance Tests
    
    func testProcessImage_Performance_MeetsRequirements() async throws {
        let testImageData = createMockJPEGData(size: CGSize(width: 800, height: 600))
        
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await imageProcessingService.processImage(testImageData)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete within reasonable time (5 seconds for local processing)
        XCTAssertLessThan(processingTime, 5.0)
        XCTAssertGreaterThan(imageProcessingService.lastProcessingTime, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Create a simple pattern
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        UIColor.red.setFill()
        UIRectFill(CGRect(x: size.width/4, y: size.height/4, width: size.width/2, height: size.height/2))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image ?? UIImage()
    }
    
    private func createMockJPEGData(size: CGSize = CGSize(width: 800, height: 600)) -> Data {
        let image = createTestImage(size: size)
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
    
    private func createMockPNGData() -> Data {
        // PNG header
        var pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        
        // Add minimal PNG structure (simplified)
        let image = createTestImage(size: CGSize(width: 100, height: 100))
        if let data = image.pngData() {
            return data
        }
        
        // Fallback: create mock PNG header
        pngData.append(Data(count: 5000)) // Add some content
        return pngData
    }
    
    private func createMockBMPData() -> Data {
        // BMP header (unsupported format)
        var bmpData = Data([0x42, 0x4D]) // "BM" signature
        bmpData.append(Data(count: 1000))
        return bmpData
    }
}