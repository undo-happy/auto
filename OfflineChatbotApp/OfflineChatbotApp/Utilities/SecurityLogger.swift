import Foundation
import os.log

/// ISMS-P compliant security logging system
class SecurityLogger {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OfflineChatbot", category: "Security")
    
    enum SecurityEvent {
        case downloadStarted(model: String, userIP: String?)
        case downloadCompleted(model: String, size: Int64)
        case downloadFailed(model: String, error: String)
        case unauthorizedAccess(resource: String)
        case dataValidationFailure(input: String)
        case networkConnectionEstablished(endpoint: String)
        case networkConnectionFailed(endpoint: String, error: String)
    }
    
    /// Log security events with ISMS-P compliance
    static func logSecurityEvent(_ event: SecurityEvent) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let eventDetails = formatSecurityEvent(event)
        
        // Log to system logger (persisted)
        logger.info("\(timestamp) - SECURITY: \(eventDetails)")
        
        // Additional logging for critical events
        switch event {
        case .unauthorizedAccess, .dataValidationFailure:
            logger.fault("CRITICAL SECURITY EVENT: \(eventDetails)")
        default:
            break
        }
    }
    
    private static func formatSecurityEvent(_ event: SecurityEvent) -> String {
        switch event {
        case .downloadStarted(let model, let userIP):
            return "DOWNLOAD_STARTED - Model: \(model), IP: \(userIP ?? "unknown")"
        case .downloadCompleted(let model, let size):
            return "DOWNLOAD_COMPLETED - Model: \(model), Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
        case .downloadFailed(let model, let error):
            return "DOWNLOAD_FAILED - Model: \(model), Error: \(sanitizeErrorMessage(error))"
        case .unauthorizedAccess(let resource):
            return "UNAUTHORIZED_ACCESS - Resource: \(resource)"
        case .dataValidationFailure(let input):
            return "DATA_VALIDATION_FAILED - Input: \(sanitizeInput(input))"
        case .networkConnectionEstablished(let endpoint):
            return "NETWORK_CONNECTED - Endpoint: \(sanitizeURL(endpoint))"
        case .networkConnectionFailed(let endpoint, let error):
            return "NETWORK_FAILED - Endpoint: \(sanitizeURL(endpoint)), Error: \(sanitizeErrorMessage(error))"
        }
    }
    
    /// Sanitize sensitive information from logs
    private static func sanitizeErrorMessage(_ error: String) -> String {
        // Remove potential sensitive information from error messages
        return error
            .replacingOccurrences(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, with: "[EMAIL]", options: .regularExpression)
            .replacingOccurrences(of: #"\d{3}-\d{2}-\d{4}"#, with: "[SSN]", options: .regularExpression)
    }
    
    private static func sanitizeInput(_ input: String) -> String {
        // Truncate and sanitize user inputs
        let maxLength = 100
        let truncated = String(input.prefix(maxLength))
        return truncated.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")
    }
    
    private static func sanitizeURL(_ url: String) -> String {
        // Remove query parameters that might contain sensitive data
        if let urlComponents = URLComponents(string: url) {
            var sanitizedComponents = urlComponents
            sanitizedComponents.query = nil
            return sanitizedComponents.string ?? url
        }
        return url
    }
}

/// Input validation utilities for security
class InputValidator {
    
    /// Validate model tier input
    static func validateModelTier(_ tierString: String) -> Bool {
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-./"))
        return tierString.rangeOfCharacter(from: allowedChars.inverted) == nil && tierString.count < 100
    }
    
    /// Validate file path input
    static func validateFilePath(_ path: String) -> Bool {
        // Prevent path traversal attacks
        let dangerousPatterns = ["../", "..\\", "/etc/", "/var/", "/usr/", "C:\\", "cmd.exe", "powershell"]
        
        for pattern in dangerousPatterns {
            if path.localizedCaseInsensitiveContains(pattern) {
                SecurityLogger.logSecurityEvent(.dataValidationFailure(input: path))
                return false
            }
        }
        
        return path.count < 500 // Reasonable path length limit
    }
    
    /// Validate URL input
    static func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            SecurityLogger.logSecurityEvent(.dataValidationFailure(input: urlString))
            return false
        }
        
        // Allow only huggingface.co domains for model downloads
        guard let host = url.host,
              host.hasSuffix("huggingface.co") else {
            SecurityLogger.logSecurityEvent(.unauthorizedAccess(resource: urlString))
            return false
        }
        
        return true
    }
}