import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
}

/// A reference to an input image displayed inline in a chat message.
struct ImageReference: Codable, Identifiable {
    var id: UUID
    /// The input item ID this image comes from.
    var inputId: UUID
    /// The filename for display.
    var filename: String?
    /// MIME type (e.g. "image/png").
    var mimeType: String

    init(id: UUID = UUID(), inputId: UUID, filename: String? = nil, mimeType: String = "image/png") {
        self.id = id
        self.inputId = inputId
        self.filename = filename
        self.mimeType = mimeType
    }
}

/// A single message in the interrogation chat.
struct InterrogationMessage: Codable, Identifiable {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    /// Images referenced or attached to this message.
    var imageReferences: [ImageReference]

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = .now, imageReferences: [ImageReference] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.imageReferences = imageReferences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        imageReferences = try container.decodeIfPresent([ImageReference].self, forKey: .imageReferences) ?? []
    }
}

/// State of the interrogation session.
struct InterrogationState: Codable {
    var messages: [InterrogationMessage]
    var summary: String

    init(messages: [InterrogationMessage] = [], summary: String = "") {
        self.messages = messages
        self.summary = summary
    }
}
