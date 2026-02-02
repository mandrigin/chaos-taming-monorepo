import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var inputForge: UTType {
        UTType(exportedAs: "com.inputforge.project")
    }
}

struct InputForgeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.inputForge] }

    var projectJSON: Data

    init() {
        let initial: [String: Any] = [
            "version": 1,
            "name": "Untitled",
            "assets": []
        ]
        self.projectJSON = (try? JSONSerialization.data(
            withJSONObject: initial,
            options: [.prettyPrinted, .sortedKeys]
        )) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        guard let wrapper = configuration.file.fileWrappers,
              let projectWrapper = wrapper["project.json"],
              let data = projectWrapper.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.projectJSON = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let projectWrapper = FileWrapper(regularFileWithContents: projectJSON)
        projectWrapper.preferredFilename = "project.json"

        let assetsWrapper = FileWrapper(directoryWithFileWrappers: [:])
        assetsWrapper.preferredFilename = "assets"

        let packageWrapper = FileWrapper(directoryWithFileWrappers: [
            "project.json": projectWrapper,
            "assets": assetsWrapper
        ])
        return packageWrapper
    }
}
