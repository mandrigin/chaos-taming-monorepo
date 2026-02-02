import Foundation

enum AIBackend: String, Codable, CaseIterable, Identifiable, Sendable {
    case gemini
    case foundationModels

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .foundationModels: return "Foundation Models"
        }
    }

    var subtitle: String {
        switch self {
        case .gemini: return "Cloud \u{2014} requires API key per context"
        case .foundationModels: return "On-device \u{2014} macOS 26+ Apple Silicon"
        }
    }

    private static let defaultsKey = "selectedAIBackend"

    static var current: AIBackend {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
                  let backend = AIBackend(rawValue: raw) else {
                return .gemini
            }
            return backend
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }
}

// MARK: - Gemini Model Info

struct GeminiModelInfo: Identifiable, Sendable, Hashable {
    let id: String          // API model name, e.g. "gemini-2.0-flash"
    let displayName: String
    let description: String
}

// MARK: - Gemini Model Selection Persistence

enum GeminiModelSelection {
    static let defaultModelID = "gemini-2.0-flash"

    private static func defaultsKey(for context: ProjectContext) -> String {
        "selectedGeminiModel-\(context.rawValue)"
    }

    static func selectedModelID(for context: ProjectContext) -> String {
        UserDefaults.standard.string(forKey: defaultsKey(for: context)) ?? defaultModelID
    }

    static func setSelectedModelID(_ id: String, for context: ProjectContext) {
        UserDefaults.standard.set(id, forKey: defaultsKey(for: context))
    }
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
        guard let apiKey = KeychainService.retrieveAPIKey(for: context) else {
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
        let id = GeminiModelSelection.selectedModelID(for: context)
        return availableModels.first { $0.id == id }
            ?? GeminiModelInfo(id: id, displayName: id, description: "")
    }
}
