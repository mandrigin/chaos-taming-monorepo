import Foundation
import FoundationModels

/// Apple Foundation Models (on-device) implementation of AIService.
///
/// Uses the Foundation Models framework available on macOS 26+ for local AI inference.
/// Serves as a fallback when offline or when the user prefers local processing.
final class FoundationModelsAIService: AIService, @unchecked Sendable {
    // MARK: - AIService

    var isAvailable: Bool {
        get async {
            SystemLanguageModel.default.isAvailable
        }
    }

    func analyze(messages: [AIMessage]) async throws -> String {
        try await sendRequest(messages: messages)
    }

    func chat(messages: [AIMessage]) async throws -> String {
        try await sendRequest(messages: messages)
    }

    // MARK: - Private

    private func sendRequest(messages: [AIMessage]) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            throw AIServiceError.modelUnavailable
        }

        let systemPrompt = messages
            .filter { $0.role == .system }
            .compactMap { msg -> String? in
                msg.parts.compactMap { part in
                    if case .text(let text) = part { return text }
                    return nil
                }.joined(separator: "\n")
            }
            .joined(separator: "\n")

        let session = LanguageModelSession(
            model: .default,
            instructions: systemPrompt
        )

        // Build the conversation by replaying history, then get final response
        let conversationParts = messages.filter { $0.role != .system }

        // Combine all user/assistant messages into the prompt for the session
        var prompt = ""
        for message in conversationParts {
            let textContent = message.parts.compactMap { part -> String? in
                if case .text(let text) = part { return text }
                return nil
            }.joined(separator: "\n")

            switch message.role {
            case .user:
                prompt += "User: \(textContent)\n\n"
            case .assistant:
                prompt += "Assistant: \(textContent)\n\n"
            case .system:
                break
            }
        }

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch is CancellationError {
            throw AIServiceError.cancelled
        } catch {
            throw AIServiceError.networkError(underlying: error)
        }
    }
}
