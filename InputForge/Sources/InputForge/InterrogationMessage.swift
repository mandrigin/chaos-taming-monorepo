import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
}

/// A single message in the interrogation chat.
struct InterrogationMessage: Codable, Identifiable {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
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
