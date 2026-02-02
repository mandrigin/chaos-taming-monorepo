import Foundation

/// Represents a content part in a multi-modal AI request.
enum AIContentPart: Sendable {
    case text(String)
    case imageData(Data, mimeType: String)
}

/// A message in a conversation with the AI service.
struct AIMessage: Sendable {
    enum Role: String, Sendable {
        case system
        case user
        case assistant
    }

    var role: Role
    var parts: [AIContentPart]

    static func system(_ text: String) -> AIMessage {
        AIMessage(role: .system, parts: [.text(text)])
    }

    static func user(_ text: String) -> AIMessage {
        AIMessage(role: .user, parts: [.text(text)])
    }

    static func user(_ parts: [AIContentPart]) -> AIMessage {
        AIMessage(role: .user, parts: parts)
    }

    static func assistant(_ text: String) -> AIMessage {
        AIMessage(role: .assistant, parts: [.text(text)])
    }
}

/// Errors that can occur during AI service operations.
enum AIServiceError: Error, LocalizedError {
    case noAPIKey
    case networkError(underlying: Error)
    case rateLimited(retryAfter: TimeInterval?)
    case invalidResponse(detail: String)
    case serverError(statusCode: Int, message: String)
    case timeout
    case modelUnavailable
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Add your API key in Settings \u{2192} AI Providers."
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .rateLimited(let retry):
            if let retry {
                return "Rate limited. Retry after \(Int(retry)) seconds."
            }
            return "Rate limited. Please try again later."
        case .invalidResponse(let detail):
            return "Invalid AI response: \(detail)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .timeout:
            return "Request timed out."
        case .modelUnavailable:
            return "AI model is not available on this device."
        case .cancelled:
            return "Request was cancelled."
        }
    }
}

/// Protocol for AI service implementations.
///
/// Both GeminiAIService and FoundationModelsAIService conform to this protocol,
/// enabling service selection based on user preference or availability.
protocol AIService: Sendable {
    /// Analyze inputs and produce a structured project plan.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages including system prompt (persona) and user content.
    /// - Returns: The raw text response from the AI model.
    func analyze(messages: [AIMessage]) async throws -> String

    /// Send a chat message for interrogation mode.
    ///
    /// - Parameters:
    ///   - messages: The full conversation history including system prompt.
    /// - Returns: The assistant's text response.
    func chat(messages: [AIMessage]) async throws -> String

    /// Whether this service is currently available.
    var isAvailable: Bool { get async }
}
