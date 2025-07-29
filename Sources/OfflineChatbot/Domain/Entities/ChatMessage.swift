import Foundation

/// 통합 채팅 메시지 엔티티 (Domain Layer)
public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let content: String
    public let sender: MessageSender
    public let timestamp: Date
    public let messageType: MessageType
    public var status: MessageStatus
    public let metadata: MessageMetadata?
    
    public init(
        id: UUID = UUID(),
        content: String,
        sender: MessageSender,
        timestamp: Date = Date(),
        messageType: MessageType = .text,
        status: MessageStatus = .sent,
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
        self.messageType = messageType
        self.status = status
        self.metadata = metadata
    }
    
    // MARK: - Computed Properties
    
    public var isFromUser: Bool {
        return sender == .user
    }
    
    public var isFromAssistant: Bool {
        return sender == .assistant
    }
    
    /// 사용자 메시지인지 확인 (호환성)
    public var isUser: Bool {
        return sender == .user
    }
    
    public var isSystemMessage: Bool {
        return sender == .system
    }
    
    public var isError: Bool {
        return status == .error || messageType == .error
    }
    
    public var displayContent: String {
        if messageType == .error {
            return "⚠️ \(content)"
        } else if sender == .system {
            return "ℹ️ \(content)"
        }
        return content
    }
    
    /// 추정 토큰 수 (메타데이터의 tokensUsed 또는 간단한 추정)
    public var estimatedTokenCount: Int {
        if let tokensUsed = metadata?.tokensUsed {
            return tokensUsed
        }
        // 간단한 토큰 수 추정: 단어 수 * 1.3
        let words = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return max(1, Int(Double(words.count) * 1.3))
    }
    
    /// 처리 시간 (메타데이터에서 가져옴)
    public var processingTime: TimeInterval? {
        return metadata?.processingTime
    }
}

// MARK: - Supporting Enums

public enum MessageSender: String, Codable, CaseIterable, Sendable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    public var displayName: String {
        switch self {
        case .user:
            return "사용자"
        case .assistant:
            return "AI"
        case .system:
            return "시스템"
        }
    }
    
    public var isFromUser: Bool {
        return self == .user
    }
}

public enum MessageType: String, Codable, CaseIterable, Sendable {
    case text = "text"
    case system = "system"
    case error = "error"
    case image = "image"
    case audio = "audio"
    case video = "video"
    
    public var displayName: String {
        switch self {
        case .text: return "텍스트"
        case .system: return "시스템"
        case .error: return "오류"
        case .image: return "이미지"
        case .audio: return "오디오"
        case .video: return "비디오"
        }
    }
    
    public var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .system: return "info.circle"
        case .error: return "exclamationmark.triangle"
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        }
    }
}

public enum MessageStatus: String, Codable, CaseIterable, Sendable {
    case sending = "sending"
    case sent = "sent"
    case generating = "generating"
    case completed = "completed"
    case error = "error"
    case retry = "retry"
    
    public var displayName: String {
        switch self {
        case .sending: return "전송 중"
        case .sent: return "전송됨"
        case .generating: return "생성 중"
        case .completed: return "완료"
        case .error: return "오류"
        case .retry: return "재시도"
        }
    }
    
    public var isProcessing: Bool {
        return self == .sending || self == .generating
    }
}

public struct MessageMetadata: Codable, Equatable, Sendable {
    public let processingTime: TimeInterval?
    public let modelUsed: String?
    public let tokensUsed: Int?
    public let confidence: Double?
    public let originalFileSize: Int?
    public let processedFileSize: Int?
    public let additionalData: [String: String]?
    
    public init(
        processingTime: TimeInterval? = nil,
        modelUsed: String? = nil,
        tokensUsed: Int? = nil,
        confidence: Double? = nil,
        originalFileSize: Int? = nil,
        processedFileSize: Int? = nil,
        additionalData: [String: String]? = nil
    ) {
        self.processingTime = processingTime
        self.modelUsed = modelUsed
        self.tokensUsed = tokensUsed
        self.confidence = confidence
        self.originalFileSize = originalFileSize
        self.processedFileSize = processedFileSize
        self.additionalData = additionalData
    }
}

// MARK: - Convenience Extensions

extension ChatMessage {
    /// 새 메시지를 텍스트 타입으로 생성
    public static func text(
        content: String,
        sender: MessageSender,
        status: MessageStatus = .sent
    ) -> ChatMessage {
        return ChatMessage(
            content: content,
            sender: sender,
            messageType: .text,
            status: status
        )
    }
    
    /// 사용자 메시지 생성
    public static func userMessage(
        content: String,
        messageType: MessageType = .text
    ) -> ChatMessage {
        return ChatMessage(
            content: content,
            sender: .user,
            messageType: messageType,
            status: .sent
        )
    }
    
    /// 어시스턴트 메시지 생성
    public static func assistantMessage(
        content: String,
        messageType: MessageType = .text,
        status: MessageStatus = .completed,
        metadata: MessageMetadata? = nil
    ) -> ChatMessage {
        return ChatMessage(
            content: content,
            sender: .assistant,
            messageType: messageType,
            status: status,
            metadata: metadata
        )
    }
    
    /// 시스템 메시지 생성
    public static func systemMessage(content: String) -> ChatMessage {
        return ChatMessage(
            content: content,
            sender: .system,
            messageType: .system,
            status: .completed
        )
    }
    
    /// 오류 메시지 생성
    public static func errorMessage(content: String) -> ChatMessage {
        return ChatMessage(
            content: content,
            sender: .system,
            messageType: .error,
            status: .error
        )
    }
}