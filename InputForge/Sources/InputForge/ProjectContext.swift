import Foundation

/// Work vs Personal context — permanent per project, determines API key routing and theme.
enum ProjectContext: String, Codable, CaseIterable, Identifiable {
    case work
    case personal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .personal: return "Personal"
        }
    }
}
