import Foundation

/// The type of input added to a project.
enum InputType: String, Codable, CaseIterable {
    case document
    case image
    case screenshot
    case audio
    case video
    case text
    case mindmap
    case wardleyMap
    case chat
}

/// A sticky-note annotation attached to an input.
struct InputAnnotation: Codable, Identifiable {
    var id: UUID
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = .now) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

/// A single input item in the project (file, recording, text, etc.).
struct InputItem: Codable, Identifiable {
    var id: UUID
    var type: InputType
    /// Original filename (nil for inline text inputs).
    var filename: String?
    /// Relative path within the package assets/ directory.
    var assetPath: String?
    /// Inline text content (for .text type inputs).
    var textContent: String?
    var annotations: [InputAnnotation]
    var addedAt: Date

    init(
        id: UUID = UUID(),
        type: InputType,
        filename: String? = nil,
        assetPath: String? = nil,
        textContent: String? = nil,
        annotations: [InputAnnotation] = [],
        addedAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.filename = filename
        self.assetPath = assetPath
        self.textContent = textContent
        self.annotations = annotations
        self.addedAt = addedAt
    }
}
