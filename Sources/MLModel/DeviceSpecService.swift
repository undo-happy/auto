import Foundation
import Metal

public final class DeviceSpecService: @unchecked Sendable {
    
    public static let shared = DeviceSpecService()
    
    public struct DeviceCapability {
        public let memoryGB: Double
        public let cpuCores: Int
        public let hasMetalSupport: Bool
        public let specTier: SpecTier
        public let recommendedModelURL: String
        public let estimatedModelSize: Int64
    }
    
    public enum SpecTier: Codable {
        case high
        case medium  
        case low
        
        public var description: String {
            switch self {
            case .high: return "high"
            case .medium: return "medium"
            case .low: return "low"
            }
        }
    }
    
    private init() {}
    
    public func getDeviceCapability() -> DeviceCapability {
        let physicalMemory = getPhysicalMemory()
        let cpuCores = getCPUCoreCount()
        let metalSupport = hasMetalGPUSupport()
        
        let specTier = determineSpecTier(
            memoryGB: physicalMemory,
            cpuCores: cpuCores,
            hasMetalSupport: metalSupport
        )
        
        let modelInfo = getModelInfo(for: specTier)
        
        return DeviceCapability(
            memoryGB: physicalMemory,
            cpuCores: cpuCores,
            hasMetalSupport: metalSupport,
            specTier: specTier,
            recommendedModelURL: modelInfo.url,
            estimatedModelSize: modelInfo.size
        )
    }
    
    private func getPhysicalMemory() -> Double {
        var size: Int64 = 0
        var length = MemoryLayout<Int64>.size
        
        let result = sysctlbyname("hw.memsize", &size, &length, nil, 0)
        
        if result == 0 {
            return Double(size) / (1024 * 1024 * 1024) // Convert to GB
        }
        
        return 0.0
    }
    
    private func getCPUCoreCount() -> Int {
        return ProcessInfo.processInfo.activeProcessorCount
    }
    
    private func hasMetalGPUSupport() -> Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
    
    private func determineSpecTier(memoryGB: Double, cpuCores: Int, hasMetalSupport: Bool) -> SpecTier {
        if memoryGB >= 8.0 && cpuCores >= 8 && hasMetalSupport {
            return .high
        } else if memoryGB >= 6.0 && cpuCores >= 6 && hasMetalSupport {
            return .medium
        } else {
            return .low
        }
    }
    
    private func getModelInfo(for tier: SpecTier) -> (url: String, size: Int64) {
        switch tier {
        case .high:
            return (
                url: "https://huggingface.co/mlx-community/gemma-3n-E4B-it-bf16",
                size: 4_000_000_000 // 4GB (E4B model)
            )
        case .medium:
            return (
                url: "https://huggingface.co/mlx-community/gemma-3n-E2B-it-bf16", 
                size: 2_000_000_000 // 2GB (E2B bf16)
            )
        case .low:
            return (
                url: "https://huggingface.co/mlx-community/gemma-3n-E2B-it-4bit",
                size: 1_000_000_000 // 1GB (E2B 4bit)
            )
        }
    }
    
    public func getModelURLs() -> [SpecTier: String] {
        return [
            .high: "https://huggingface.co/mlx-community/gemma-3n-E4B-it-bf16",
            .medium: "https://huggingface.co/mlx-community/gemma-3n-E2B-it-bf16",
            .low: "https://huggingface.co/mlx-community/gemma-3n-E2B-it-4bit"
        ]
    }
}