import Foundation

/// Claude Code (local binary) AI service implementing the AIService protocol.
///
/// Invokes the locally installed Claude Code CLI (`claude --print`).
/// No API key required; relies on the user's existing Claude Code authentication.
/// Supports multi-modal input via temp files for image data.
final class ClaudeCodeAIService: AIService, @unchecked Sendable {
    private let model: String
    private let fileManager = FileManager.default

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

    /// Result of formatting messages, including any temp directory with images.
    private struct FormattedPrompt {
        let text: String
        let imageTempDir: URL?
    }

    private func invokeClaudeCode(messages: [AIMessage]) async throws -> String {
        guard let binaryPath = AIBackend.claudeCodePath else {
            throw AIServiceError.modelUnavailable
        }

        let formatted = try formatPrompt(from: messages)

        // Claude Code CLI requires a non-empty prompt
        guard !formatted.text.isEmpty else {
            throw AIServiceError.invalidResponse(detail: "Cannot invoke Claude Code with empty prompt - no messages with content provided")
        }

        defer {
            // Clean up temp directory after request completes
            if let tempDir = formatted.imageTempDir {
                try? fileManager.removeItem(at: tempDir)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.runProcess(
                        binaryPath: binaryPath,
                        prompt: formatted.text,
                        imageTempDir: formatted.imageTempDir
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func formatPrompt(from messages: [AIMessage]) throws -> FormattedPrompt {
        var promptParts: [String] = []
        var imagePaths: [String] = []
        var tempDir: URL?

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

            var contentParts: [String] = []

            for part in message.parts {
                switch part {
                case .text(let text):
                    contentParts.append(text)
                case .imageData(let data, let mimeType):
                    // Create temp directory on first image
                    if tempDir == nil {
                        let baseTempDir = fileManager.temporaryDirectory
                        let sessionDir = baseTempDir.appendingPathComponent("claude-code-images-\(UUID().uuidString)")
                        try fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)
                        tempDir = sessionDir
                    }

                    let ext = fileExtension(for: mimeType)
                    let filename = "image-\(imagePaths.count + 1)\(ext)"
                    let imagePath = tempDir!.appendingPathComponent(filename)

                    try data.write(to: imagePath)
                    imagePaths.append(imagePath.path)
                    contentParts.append("See attached image: \(imagePath.path)")
                }
            }

            if !contentParts.isEmpty {
                promptParts.append(rolePrefix + contentParts.joined(separator: "\n"))
            }
        }

        return FormattedPrompt(
            text: promptParts.joined(separator: "\n\n"),
            imageTempDir: tempDir
        )
    }

    /// Map MIME type to file extension.
    private func fileExtension(for mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "image/png":
            return ".png"
        case "image/jpeg", "image/jpg":
            return ".jpg"
        case "image/gif":
            return ".gif"
        case "image/webp":
            return ".webp"
        case "image/heic":
            return ".heic"
        case "image/heif":
            return ".heif"
        case "image/tiff":
            return ".tiff"
        case "image/bmp":
            return ".bmp"
        default:
            // Default to png for unknown image types
            return ".png"
        }
    }

    private func runProcess(binaryPath: String, prompt: String, imageTempDir: URL?) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)

        var arguments = ["--print", "--model", model]

        // Add --add-dir flag if images are present to give Claude access to the temp directory
        if let tempDir = imageTempDir {
            arguments.append("--add-dir")
            arguments.append(tempDir.path)
        }

        process.arguments = arguments

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Write prompt to stdin then close to signal EOF
        if let data = prompt.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }
        stdinPipe.fileHandleForWriting.closeFile()

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
