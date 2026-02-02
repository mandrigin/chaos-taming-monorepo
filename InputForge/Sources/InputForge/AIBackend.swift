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
