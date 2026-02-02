import Foundation

/// Claude Code (local binary) AI service implementing the AIService protocol.
///
/// Stub implementation — the full service will be provided by another contributor.
/// No API key required; uses the locally installed Claude Code CLI.
final class ClaudeCodeAIService: AIService, @unchecked Sendable {
    private let model: String

    init(model: String = "claude-sonnet-4-20250514") {
        self.model = model
    }

    var isAvailable: Bool {
        get async {
            AIBackend.isClaudeCodeAvailable
        }
    }

    func analyze(messages: [AIMessage]) async throws -> String {
        guard AIBackend.isClaudeCodeAvailable else {
            throw AIServiceError.modelUnavailable
        }
        throw AIServiceError.modelUnavailable
    }

    func chat(messages: [AIMessage]) async throws -> String {
        guard AIBackend.isClaudeCodeAvailable else {
            throw AIServiceError.modelUnavailable
        }
        throw AIServiceError.modelUnavailable
    }
}
