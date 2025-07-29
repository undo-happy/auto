import XCTest
import Foundation
@testable import MLModel

final class DeviceSpecServiceTests: XCTestCase {
    
    var deviceSpecService: DeviceSpecService!
    
    override func setUp() {
        super.setUp()
        deviceSpecService = DeviceSpecService.shared
    }
    
    override func tearDown() {
        deviceSpecService = nil
        super.tearDown()
    }
    
    func testGetDeviceCapability() {
        // Given
        let capability = deviceSpecService.getDeviceCapability()
        
        // Then
        XCTAssertGreaterThan(capability.memoryGB, 0, "메모리는 0보다 커야 합니다")
        XCTAssertGreaterThan(capability.cpuCores, 0, "CPU 코어 수는 0보다 커야 합니다")
        XCTAssertNotNil(capability.specTier, "사양 티어가 설정되어야 합니다")
        XCTAssertFalse(capability.recommendedModelURL.isEmpty, "모델 URL이 설정되어야 합니다")
        XCTAssertGreaterThan(capability.estimatedModelSize, 0, "모델 크기는 0보다 커야 합니다")
    }
    
    func testSpecTierDetermination() {
        // Test high spec tier
        XCTAssertNotNil(DeviceSpecService.SpecTier.high)
        XCTAssertNotNil(DeviceSpecService.SpecTier.medium)
        XCTAssertNotNil(DeviceSpecService.SpecTier.low)
    }
    
    func testSpecTierDescription() {
        // Given
        let highTier = DeviceSpecService.SpecTier.high
        let mediumTier = DeviceSpecService.SpecTier.medium
        let lowTier = DeviceSpecService.SpecTier.low
        
        // Then
        XCTAssertEqual(highTier.description, "high")
        XCTAssertEqual(mediumTier.description, "medium")
        XCTAssertEqual(lowTier.description, "low")
    }
    
    func testGetModelURLs() {
        // Given
        let modelURLs = deviceSpecService.getModelURLs()
        
        // Then
        XCTAssertEqual(modelURLs.count, 3, "3개의 모델 URL이 있어야 합니다")
        XCTAssertTrue(modelURLs[.high]?.contains("huggingface.co") ?? false, "고사양 모델 URL은 huggingface.co를 포함해야 합니다")
        XCTAssertTrue(modelURLs[.medium]?.contains("huggingface.co") ?? false, "중사양 모델 URL은 huggingface.co를 포함해야 합니다")
        XCTAssertTrue(modelURLs[.low]?.contains("huggingface.co") ?? false, "저사양 모델 URL은 huggingface.co를 포함해야 합니다")
    }
    
    func testModelSizes() {
        // Given
        let capability = deviceSpecService.getDeviceCapability()
        
        // Then
        switch capability.specTier {
        case .high:
            XCTAssertEqual(capability.estimatedModelSize, 4_000_000_000, "고사양 모델 크기는 4GB여야 합니다")
        case .medium:
            XCTAssertEqual(capability.estimatedModelSize, 2_000_000_000, "중사양 모델 크기는 2GB여야 합니다")
        case .low:
            XCTAssertEqual(capability.estimatedModelSize, 1_000_000_000, "저사양 모델 크기는 1GB여야 합니다")
        }
    }
    
    func testDeviceCapabilityConsistency() {
        // Given
        let capability1 = deviceSpecService.getDeviceCapability()
        let capability2 = deviceSpecService.getDeviceCapability()
        
        // Then (같은 디바이스에서는 일관된 값이 나와야 함)
        XCTAssertEqual(capability1.memoryGB, capability2.memoryGB)
        XCTAssertEqual(capability1.cpuCores, capability2.cpuCores)
        XCTAssertEqual(capability1.hasMetalSupport, capability2.hasMetalSupport)
        XCTAssertEqual(capability1.specTier, capability2.specTier)
    }
}