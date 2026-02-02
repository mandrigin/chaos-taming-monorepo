import SwiftUI

struct InputForgeCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
        }

        CommandMenu("Forge") {
            Button("Analyze") {
                NotificationCenter.default.post(name: .runAnalysis, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button("Interrogation Mode") {
                NotificationCenter.default.post(name: .enterInterrogation, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Export TaskPaper") {
                NotificationCenter.default.post(name: .exportTaskPaper, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Record Audio") {
                NotificationCenter.default.post(name: .toggleAudioRecording, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Switch Persona") {
                NotificationCenter.default.post(name: .switchPersona, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("Version History") {
                NotificationCenter.default.post(name: .showVersionHistory, object: nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        }
    }
}

extension Notification.Name {
    static let runAnalysis = Notification.Name("runAnalysis")
    static let enterInterrogation = Notification.Name("enterInterrogation")
    static let exportTaskPaper = Notification.Name("exportTaskPaper")
    static let toggleAudioRecording = Notification.Name("toggleAudioRecording")
    static let switchPersona = Notification.Name("switchPersona")
    static let showVersionHistory = Notification.Name("showVersionHistory")
}
