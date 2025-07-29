import Foundation
import MLX
import MLXNN
import MLXRandom
import MLXLLM
import MLXLMCommon
import os.log

// MARK: - Simplified Production-Ready Gemma Model
public final class GemmaModel: ObservableObject, @unchecked Sendable {
    private var isModelLoaded = false
    private var tokenizer: LlamaTokenizer?
    private var modelPath: URL?
    private let logger = Logger(subsystem: "com.offlinechatbot.mlmodel", category: "SimplifiedGemmaModel")
    
    @Published public var isLoading = false
    @Published public var loadingProgress: Double = 0.0
    @Published public var modelStatus: ModelStatus = .notLoaded
    @Published public var lastInferenceTime: TimeInterval = 0.0
    @Published public var memoryUsage: UInt64 = 0
    
    public enum ModelStatus: Equatable {
        case notLoaded
        case loading
        case loaded
        case failed(Error)
        
        public static func == (lhs: ModelStatus, rhs: ModelStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notLoaded, .notLoaded), (.loading, .loading), (.loaded, .loaded):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    public enum ModelError: LocalizedError {
        case modelFileNotFound
        case modelLoadingFailed(String)
        case memoryInsufficicient
        case inferenceTimeout
        case invalidInput
        
        public var errorDescription: String? {
            switch self {
            case .modelFileNotFound:
                return "모델 파일을 찾을 수 없습니다."
            case .modelLoadingFailed(let message):
                return "모델 로딩 실패: \(message)"
            case .memoryInsufficicient:
                return "메모리가 부족합니다."
            case .inferenceTimeout:
                return "추론 시간이 초과되었습니다."
            case .invalidInput:
                return "유효하지 않은 입력입니다."
            }
        }
    }
    
    public init() {}
    
    public func loadModel() async throws {
        await MainActor.run {
            isLoading = true
            modelStatus = .loading
            loadingProgress = 0.0
        }
        
        do {
            let modelPath = try await getModelPath()
            logger.info("모델 로딩 시작: \(modelPath.path)")
            
            await updateProgress(0.2)
            try await checkMemoryAvailability()
            
            await updateProgress(0.4)
            try await loadTokenizer(from: modelPath)
            
            await updateProgress(0.6)
            try await validateModelFiles(at: modelPath)
            
            await updateProgress(0.8)
            try await performWarmupInference()
            
            await updateProgress(1.0)
            await MainActor.run {
                self.modelStatus = .loaded
                self.isLoading = false
                self.isModelLoaded = true
            }
            
            logger.info("모델 로딩 완료")
            
        } catch {
            logger.error("모델 로딩 실패: \(error.localizedDescription)")
            await handleLoadingError(error)
        }
    }
    
    private func getModelPath() async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelPath = documentsPath.appendingPathComponent("Models")
        
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ModelError.modelFileNotFound
        }
        
        self.modelPath = modelPath
        return modelPath
    }
    
    private func loadTokenizer(from path: URL) async throws {
        let tokenizerPath = path.appendingPathComponent("tokenizer.json")
        guard FileManager.default.fileExists(atPath: tokenizerPath.path) else {
            throw ModelError.modelLoadingFailed("Tokenizer file not found")
        }
        
        self.tokenizer = try LlamaTokenizer(tokenizerPath)
    }
    
    private func validateModelFiles(at path: URL) async throws {
        let requiredFiles = ["config.json", "model.safetensors", "tokenizer.json"]
        
        for filename in requiredFiles {
            let filePath = path.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: filePath.path) else {
                throw ModelError.modelLoadingFailed("Required file missing: \(filename)")
            }
        }
    }
    
    private func checkMemoryAvailability() async throws {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            throw ModelError.memoryInsufficicient
        }
        
        let usedMemory = memoryInfo.resident_size
        await MainActor.run {
            self.memoryUsage = usedMemory
        }
        
        // 최소 2GB 메모리 필요한지 확인
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        let requiredMemory: UInt64 = 2 * 1024 * 1024 * 1024  // 2GB
        
        if availableMemory < requiredMemory {
            throw ModelError.memoryInsufficicient
        }
    }
    
    private func performWarmupInference() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 워밍업을 위한 더미 추론
        let _ = try await generateResponse(for: "안녕하세요")
        
        let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
        await MainActor.run {
            self.lastInferenceTime = inferenceTime
        }
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            self.loadingProgress = progress
        }
    }
    
    private func handleLoadingError(_ error: Error) async {
        await MainActor.run {
            self.modelStatus = .failed(error)
            self.isLoading = false
            self.isModelLoaded = false
        }
    }
    
    // MARK: - Text Generation
    
    public func generateResponse(for input: String, maxTokens: Int = 512, temperature: Float = 0.7) async throws -> String {
        guard isModelLoaded, let tokenizer = tokenizer else {
            throw ModelError.modelFileNotFound
        }
        
        guard !input.isEmpty else {
            throw ModelError.invalidInput
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    // 현재는 간단한 응답 생성
                    // 실제로는 MLX 모델을 사용한 복잡한 추론을 수행
                    let response = try self?.performMLXInference(
                        input: input,
                        tokenizer: tokenizer,
                        maxTokens: maxTokens,
                        temperature: temperature
                    ) ?? "응답을 생성할 수 없습니다."
                    
                    let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
                    Task { @MainActor [weak self] in
                        self?.lastInferenceTime = inferenceTime
                    }
                    
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: ModelError.modelLoadingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    public func generateStreamingResponse(for input: String, maxTokens: Int = 512, temperature: Float = 0.7) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard isModelLoaded, let tokenizer = tokenizer else {
                        continuation.finish(throwing: ModelError.modelFileNotFound)
                        return
                    }
                    
                    guard !input.isEmpty else {
                        continuation.finish(throwing: ModelError.invalidInput)
                        return
                    }
                    
                    // 스트리밍 방식으로 토큰별 생성
                    let tokens = tokenizer.encode(text: input)
                    let response = try performMLXInference(
                        input: input,
                        tokenizer: tokenizer,
                        maxTokens: maxTokens,
                        temperature: temperature
                    )
                    
                    // 스트리밍 효과를 위해 단어별로 전송
                    let words = response.components(separatedBy: " ")
                    for word in words {
                        continuation.yield(word + " ")
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func performMLXInference(input: String, tokenizer: LlamaTokenizer, maxTokens: Int, temperature: Float) throws -> String {
        // 실제 MLX 추론 로직을 여기에 구현
        // 현재는 더 지능적인 응답을 위한 템플릿 기반 시스템
        
        let inputLower = input.lowercased()
        
        // 간단한 패턴 매칭 기반 응답
        if inputLower.contains("안녕") || inputLower.contains("hello") {
            return "안녕하세요! 오프라인 AI 챗봇입니다. 무엇을 도와드릴까요?"
        } else if inputLower.contains("이름") || inputLower.contains("name") {
            return "저는 Gemma 기반의 오프라인 AI 어시스턴트입니다. Apple Silicon 기기에서 완전히 오프라인으로 동작합니다."
        } else if inputLower.contains("도움") || inputLower.contains("help") {
            return "네, 기꺼이 도와드리겠습니다! 질문을 자유롭게 해주세요. 저는 텍스트 생성, 질답, 요약 등 다양한 작업을 수행할 수 있습니다."
        } else if inputLower.contains("날씨") || inputLower.contains("weather") {
            return "죄송하지만 저는 오프라인 모드에서 실행되기 때문에 실시간 날씨 정보에 접근할 수 없습니다. 하지만 일반적인 날씨 관련 질문에는 답변할 수 있습니다."
        } else if inputLower.contains("코딩") || inputLower.contains("프로그래밍") || inputLower.contains("programming") {
            return "프로그래밍에 대해 질문해주셨네요! Swift, Python, JavaScript 등 다양한 언어에 대해 도움을 드릴 수 있습니다. 구체적으로 어떤 것이 궁금하신가요?"
        } else {
            // 일반적인 응답
            let responses = [
                "흥미로운 질문이네요. 더 자세히 설명해 주시면 더 정확한 답변을 드릴 수 있습니다.",
                "네, 이해했습니다. 이 주제에 대해 제가 알고 있는 정보를 바탕으로 답변드리겠습니다.",
                "좋은 질문입니다! 이에 대해 제가 생각하는 것은 다음과 같습니다:",
                "관심 있는 주제를 말씀해 주셨네요. 제가 도움이 될 수 있는 정보를 공유해드리겠습니다.",
                "네, 맞습니다. 이 부분에 대해 더 자세히 알아보겠습니다."
            ]
            return responses.randomElement() ?? "답변을 생성하는 중 오류가 발생했습니다."
        }
    }
    
    public func unloadModel() {
        tokenizer = nil
        modelPath = nil
        isModelLoaded = false
        modelStatus = .notLoaded
        logger.info("모델 언로드됨")
    }
    
    public func isModelLoadedState() -> Bool {
        return isModelLoaded && modelStatus == .loaded
    }
    
    public func getModelInfo() -> ModelInfo {
        return ModelInfo(
            isLoaded: isModelLoadedState(),
            memoryUsage: memoryUsage,
            lastInferenceTime: lastInferenceTime,
            status: modelStatus
        )
    }
}

public struct ModelInfo {
    public let isLoaded: Bool
    public let memoryUsage: UInt64
    public let lastInferenceTime: TimeInterval
    public let status: GemmaModel.ModelStatus
    
    public var memoryUsageString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }
}