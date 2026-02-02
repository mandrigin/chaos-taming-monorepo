import SwiftUI

@main
struct InputForgeApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { InputForgeDocument() }) { file in
            ContentView(document: file.document)
        }
        .commands {
            InputForgeCommands()
        }
    }
}
