import Foundation

enum ModelTier: String, CaseIterable, Sendable {
    case low = "저사양"
    case medium = "중사양" 
    case high = "고사양"
    
    var repoId: String {
        switch self {
        case .high:
            return "mlx-community/gemma-3n-E4B-it-bf16"
        case .medium:
            return "mlx-community/gemma-3n-E2B-it-bf16"
        case .low:
            return "mlx-community/gemma-3n-E2B-it-4bit"
        }
    }
    
    var fileNames: [String] {
        switch self {
        case .low:
            return ["model.safetensors", "tokenizer.json", "config.json"]
        case .medium, .high:
            // Assuming similar structure for other models
            return ["model.safetensors", "tokenizer.json", "config.json"]
        }
    }
    
    var displayName: String {
        switch self {
        case .high:
            return "Gemma E4B (~15.7GB)"
        case .medium:
            return "Gemma E2B BF16 (~10.9GB)"
        case .low:
            return "Gemma E2B 4bit (~4.46GB)"
        }
    }
    
    var folderName: String {
        return repoId.replacingOccurrences(of: "/", with: "_")
    }
    
    var estimatedSize: String {
        switch self {
        case .low: return "~4.46GB"
        case .medium: return "~10.9GB"  
        case .high: return "~15.7GB"
        }
    }
}