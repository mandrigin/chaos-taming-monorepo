import Foundation

enum AIBackend: String, Codable, CaseIterable, Identifiable, Sendable {
    case gemini
    case anthropic
    case claudeCode
    case openai
    case foundationModels

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic"
        case .claudeCode: return "Claude Code"
        case .openai: return "OpenAI"
        case .foundationModels: return "Foundation Models"
        }
    }

    var subtitle: String {
        switch self {
        case .gemini: return "Cloud \u{2014} requires API key"
        case .anthropic: return "Cloud \u{2014} requires API key"
        case .claudeCode: return "Local \u{2014} uses Claude Code binary"
        case .openai: return "Cloud \u{2014} requires API key"
        case .foundationModels: return "On-device \u{2014} macOS 26+ Apple Silicon"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .gemini, .anthropic, .openai: return true
        case .claudeCode, .foundationModels: return false
        }
    }

    var defaultModelID: String {
        switch self {
        case .gemini: return "gemini-2.0-flash"
        case .anthropic: return "claude-sonnet-4-20250514"
        case .claudeCode: return "claude-sonnet-4-20250514"
        case .openai: return "gpt-4o"
        case .foundationModels: return "default"
        }
    }

    // MARK: - Per-Context Provider Selection

    private static func providerDefaultsKey(for context: ProjectContext) -> String {
        "selectedAIBackend-\(context.rawValue)"
    }

    static func selectedProvider(for context: ProjectContext) -> AIBackend {
        if let raw = UserDefaults.standard.string(forKey: providerDefaultsKey(for: context)),
           let backend = AIBackend(rawValue: raw) {
            return backend
        }
        // Migration: fall back to old global key
        if let raw = UserDefaults.standard.string(forKey: "selectedAIBackend"),
           let backend = AIBackend(rawValue: raw) {
            return backend
        }
        return .gemini
    }

    static func setSelectedProvider(_ provider: AIBackend, for context: ProjectContext) {
        UserDefaults.standard.set(provider.rawValue, forKey: providerDefaultsKey(for: context))
    }

    // MARK: - Claude Code Detection

    static var claudeCodePath: String? {
        let paths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            NSHomeDirectory() + "/.local/bin/claude",
        ]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Fall back to PATH lookup
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let resolved = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !resolved.isEmpty {
                    return resolved
                }
            }
        } catch {}
        return nil
    }

    static var isClaudeCodeAvailable: Bool {
        claudeCodePath != nil
    }
}

// MARK: - Generalized Model Selection Persistence

enum ModelSelection {
    private static func defaultsKey(provider: AIBackend, context: ProjectContext) -> String {
        "selectedModel-\(provider.rawValue)-\(context.rawValue)"
    }

    static func selectedModelID(provider: AIBackend, context: ProjectContext) -> String {
        // Migration: check old Gemini-specific key
        if provider == .gemini {
            let legacyKey = "selectedGeminiModel-\(context.rawValue)"
            if let legacy = UserDefaults.standard.string(forKey: legacyKey) {
                return legacy
            }
        }
        return UserDefaults.standard.string(forKey: defaultsKey(provider: provider, context: context))
            ?? provider.defaultModelID
    }

    static func setSelectedModelID(_ id: String, provider: AIBackend, context: ProjectContext) {
        UserDefaults.standard.set(id, forKey: defaultsKey(provider: provider, context: context))
    }
}

// MARK: - Gemini Model Info

struct GeminiModelInfo: Identifiable, Sendable, Hashable {
    let id: String          // API model name, e.g. "gemini-2.0-flash"
    let displayName: String
    let description: String
}

// MARK: - Gemini Model Store (dynamic fetching)

@Observable
@MainActor
final class GeminiModelStore {
    static let shared = GeminiModelStore()

    private(set) var availableModels: [GeminiModelInfo] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private var lastFetchDate: Date?

    private static let cacheLifetime: TimeInterval = 300

    private init() {}

    var needsFetch: Bool {
        if availableModels.isEmpty { return true }
        guard let lastFetch = lastFetchDate else { return true }
        return Date().timeIntervalSince(lastFetch) > Self.cacheLifetime
    }

    func fetchModelsIfNeeded(for context: ProjectContext) async {
        guard needsFetch, !isLoading else { return }
        await fetchModels(for: context)
    }

    func fetchModels(for context: ProjectContext) async {
        guard let apiKey = KeychainService.retrieveAPIKey(provider: .gemini, context: context) else {
            lastError = "No API key for \(context.displayName)"
            return
        }

        isLoading = true
        lastError = nil

        do {
            availableModels = try await GeminiAIService.listModels(apiKey: apiKey)
            lastFetchDate = Date()
        } catch {
            lastError = error.localizedDescription
        }

        isLoading = false
    }

    func selectedModel(for context: ProjectContext) -> GeminiModelInfo {
        let id = ModelSelection.selectedModelID(provider: .gemini, context: context)
        return availableModels.first { $0.id == id }
            ?? GeminiModelInfo(id: id, displayName: id, description: "")
    }
}
