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

// MARK: - Gemini Model Selection

enum GeminiModel: String, CaseIterable, Identifiable, Sendable {
    case gemini25Pro = "gemini-2.5-pro-preview-05-06"
    case gemini20Flash = "gemini-2.0-flash"
    case gemini20FlashLite = "gemini-2.0-flash-lite"
    case gemini15Pro = "gemini-1.5-pro"
    case gemini15Flash = "gemini-1.5-flash"

    var id: String { rawValue }

    /// The model identifier sent to the Gemini API.
    var apiName: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini25Pro: return "Gemini 2.5 Pro"
        case .gemini20Flash: return "Gemini 2.0 Flash"
        case .gemini20FlashLite: return "Gemini 2.0 Flash Lite"
        case .gemini15Pro: return "Gemini 1.5 Pro"
        case .gemini15Flash: return "Gemini 1.5 Flash"
        }
    }

    var description: String {
        switch self {
        case .gemini25Pro: return "Most capable \u{2014} best for complex analysis"
        case .gemini20Flash: return "Fast and capable \u{2014} good default"
        case .gemini20FlashLite: return "Fastest \u{2014} lower cost, simpler tasks"
        case .gemini15Pro: return "Previous generation \u{2014} strong reasoning"
        case .gemini15Flash: return "Previous generation \u{2014} fast and light"
        }
    }

    // MARK: - Per-Context Persistence

    private static func defaultsKey(for context: ProjectContext) -> String {
        "selectedGeminiModel-\(context.rawValue)"
    }

    static func current(for context: ProjectContext) -> GeminiModel {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey(for: context)),
              let model = GeminiModel(rawValue: raw) else {
            return .gemini20Flash
        }
        return model
    }

    static func setCurrent(_ model: GeminiModel, for context: ProjectContext) {
        UserDefaults.standard.set(model.rawValue, forKey: defaultsKey(for: context))
    }
}
