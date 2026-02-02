import Foundation

/// OpenAI API client implementing the AIService protocol.
///
/// Stub implementation — the full service will be provided by another contributor.
/// API key is retrieved from macOS Keychain based on project context.
final class OpenAIAIService: AIService, @unchecked Sendable {
    private let context: ProjectContext
    private let model: String

    init(context: ProjectContext, model: String = "gpt-4o") {
        self.context = context
        self.model = model
    }

    var isAvailable: Bool {
        get async {
            KeychainService.hasAPIKey(provider: .openai, context: context)
        }
    }

    func analyze(messages: [AIMessage]) async throws -> String {
        guard KeychainService.hasAPIKey(provider: .openai, context: context) else {
            throw AIServiceError.noAPIKey
        }
        throw AIServiceError.modelUnavailable
    }

    func chat(messages: [AIMessage]) async throws -> String {
        guard KeychainService.hasAPIKey(provider: .openai, context: context) else {
            throw AIServiceError.noAPIKey
        }
        throw AIServiceError.modelUnavailable
    }
}
