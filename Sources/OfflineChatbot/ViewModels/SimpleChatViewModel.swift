import Foundation
import SwiftUI

@MainActor
public class SimpleChatViewModel: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var inputText: String = ""
    @Published public var isLoading: Bool = false
    
    private let inferenceService = ModelInferenceService()
    
    public init() {}
    
    public func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 사용자 메시지 추가
        let userMessage = ChatMessage.userMessage(content: inputText)
        messages.append(userMessage)
        
        let messageText = inputText
        inputText = ""
        isLoading = true
        
        Task {
            do {
                // AI 응답 생성
                let response = try await inferenceService.processText(messageText)
                let assistantMessage = ChatMessage.assistantMessage(content: response)
                
                await MainActor.run {
                    messages.append(assistantMessage)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage.assistantMessage(content: "오류가 발생했습니다: \(error.localizedDescription)")
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
}