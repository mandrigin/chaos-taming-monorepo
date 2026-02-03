import Foundation

/// Claude Code (local binary) AI service implementing the AIService protocol.
///
/// Invokes the locally installed Claude Code CLI (`claude --print`).
/// No API key required; relies on the user's existing Claude Code authentication.
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
        try await invokeClaudeCode(messages: messages)
    }

    func chat(messages: [AIMessage]) async throws -> String {
        try await invokeClaudeCode(messages: messages)
    }

    // MARK: - Private

    private func invokeClaudeCode(messages: [AIMessage]) async throws -> String {
        guard let binaryPath = AIBackend.claudeCodePath else {
            throw AIServiceError.modelUnavailable
        }

        let prompt = formatPrompt(from: messages)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.runProcess(binaryPath: binaryPath, prompt: prompt)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func formatPrompt(from messages: [AIMessage]) -> String {
        var parts: [String] = []

        for message in messages {
            let rolePrefix: String
            switch message.role {
            case .system:
                rolePrefix = "[System]\n"
            case .user:
                rolePrefix = "[User]\n"
            case .assistant:
                rolePrefix = "[Assistant]\n"
            }

            let textContent = message.parts.compactMap { part -> String? in
                if case .text(let text) = part {
                    return text
                }
                return nil
            }.joined(separator: "\n")

            if !textContent.isEmpty {
                parts.append(rolePrefix + textContent)
            }
        }

        return parts.joined(separator: "\n\n")
    }

    private func runProcess(binaryPath: String, prompt: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["--print", prompt]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errorMessage = stderr.isEmpty ? "Claude Code exited with status \(process.terminationStatus)" : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw AIServiceError.serverError(statusCode: Int(process.terminationStatus), message: errorMessage)
        }

        let result = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty {
            throw AIServiceError.invalidResponse(detail: "Claude Code returned empty response")
        }

        return result
    }
}
