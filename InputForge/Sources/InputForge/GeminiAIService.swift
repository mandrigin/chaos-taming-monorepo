import Foundation

/// Google Gemini API client implementing the AIService protocol.
///
/// Supports multi-modal input (text + images), retry logic, and timeout handling.
/// API key is retrieved from macOS Keychain based on project context.
final class GeminiAIService: AIService, @unchecked Sendable {
    private let context: ProjectContext
    private let session: URLSession
    private let model: String
    private let maxRetries: Int

    private static let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private static let defaultTimeout: TimeInterval = 120

    init(
        context: ProjectContext,
        model: String = "gemini-2.0-flash",
        maxRetries: Int = 3,
        timeout: TimeInterval = defaultTimeout
    ) {
        self.context = context
        self.model = model
        self.maxRetries = maxRetries

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }

    // MARK: - AIService

    var isAvailable: Bool {
        get async {
            KeychainService.hasAPIKey(provider: .gemini, context: context)
        }
    }

    func analyze(messages: [AIMessage]) async throws -> String {
        try await sendRequest(messages: messages)
    }

    func chat(messages: [AIMessage]) async throws -> String {
        try await sendRequest(messages: messages)
    }

    // MARK: - Model Discovery

    static func listModels(apiKey: String) async throws -> [GeminiModelInfo] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1/models?key=\(apiKey)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIServiceError.invalidResponse(detail: "Failed to fetch model list")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw AIServiceError.invalidResponse(detail: "Invalid models response format")
        }

        return models.compactMap { entry -> GeminiModelInfo? in
            guard let name = entry["name"] as? String,
                  let displayName = entry["displayName"] as? String,
                  let methods = entry["supportedGenerationMethods"] as? [String],
                  methods.contains("generateContent") else {
                return nil
            }
            let id = name.hasPrefix("models/") ? String(name.dropFirst(7)) : name
            let description = entry["description"] as? String ?? ""
            return GeminiModelInfo(id: id, displayName: displayName, description: description)
        }
    }

    // MARK: - Private

    private func sendRequest(messages: [AIMessage]) async throws -> String {
        guard let apiKey = KeychainService.retrieveAPIKey(provider: .gemini, context: context) else {
            throw AIServiceError.noAPIKey
        }

        let url = URL(string: "\(Self.baseURL)/\(model):generateContent?key=\(apiKey)")!
        let body = buildRequestBody(messages: messages)

        var lastError: Error = AIServiceError.timeout

        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delay = pow(2.0, Double(attempt)) + Double.random(in: 0...1)
                try await Task.sleep(for: .seconds(delay))
            }

            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.invalidResponse(detail: "Non-HTTP response")
                }

                switch httpResponse.statusCode {
                case 200:
                    return try parseResponse(data: data)
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { TimeInterval($0) }
                    if attempt == maxRetries - 1 {
                        throw AIServiceError.rateLimited(retryAfter: retryAfter)
                    }
                    if let retryAfter {
                        try await Task.sleep(for: .seconds(retryAfter))
                    }
                    lastError = AIServiceError.rateLimited(retryAfter: retryAfter)
                    continue
                case 500...599:
                    let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    if attempt == maxRetries - 1 {
                        throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: message)
                    }
                    lastError = AIServiceError.serverError(statusCode: httpResponse.statusCode, message: message)
                    continue
                default:
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: message)
                }
            } catch let error as AIServiceError {
                throw error
            } catch is CancellationError {
                throw AIServiceError.cancelled
            } catch let error as URLError where error.code == .timedOut {
                if attempt == maxRetries - 1 {
                    throw AIServiceError.timeout
                }
                lastError = AIServiceError.timeout
            } catch {
                if attempt == maxRetries - 1 {
                    throw AIServiceError.networkError(underlying: error)
                }
                lastError = AIServiceError.networkError(underlying: error)
            }
        }

        throw lastError
    }

    private func buildRequestBody(messages: [AIMessage]) -> [String: Any] {
        var contents: [[String: Any]] = []
        var systemInstruction: [String: Any]?

        for message in messages {
            switch message.role {
            case .system:
                // Gemini uses systemInstruction at the top level
                let textParts = message.parts.compactMap { part -> String? in
                    if case .text(let text) = part { return text }
                    return nil
                }
                systemInstruction = [
                    "parts": textParts.map { ["text": $0] }
                ]
            case .user:
                contents.append([
                    "role": "user",
                    "parts": buildParts(message.parts),
                ])
            case .assistant:
                contents.append([
                    "role": "model",
                    "parts": buildParts(message.parts),
                ])
            }
        }

        var body: [String: Any] = ["contents": contents]
        if let systemInstruction {
            body["systemInstruction"] = systemInstruction
        }
        body["generationConfig"] = [
            "temperature": 0.7,
            "topP": 0.95,
            "maxOutputTokens": 8192,
        ]

        return body
    }

    private func buildParts(_ parts: [AIContentPart]) -> [[String: Any]] {
        parts.map { part in
            switch part {
            case .text(let text):
                return ["text": text]
            case .imageData(let data, let mimeType):
                return [
                    "inlineData": [
                        "mimeType": mimeType,
                        "data": data.base64EncodedString(),
                    ]
                ]
            }
        }
    }

    private func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.invalidResponse(detail: "Could not parse response JSON")
        }

        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            // Check for error in response
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIServiceError.serverError(statusCode: 0, message: message)
            }
            throw AIServiceError.invalidResponse(detail: "Missing text in response candidates")
        }

        return text
    }
}
