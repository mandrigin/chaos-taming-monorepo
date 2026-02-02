import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let inputForge = UTType(exportedAs: "com.inputforge.project", conformingTo: .package)
}

/// SwiftUI document backed by a .inputforge package bundle.
///
/// Package structure:
/// ```
/// MyProject.inputforge/
/// ├── project.json
/// ├── assets/
/// │   ├── screenshot-1.png
/// │   └── ...
/// └── versions/
///     ├── v001.json
///     └── ...
/// ```
@Observable
final class InputForgeDocument: ReferenceFileDocument, @unchecked Sendable {
    // MARK: - State

    var projectData: ProjectData
    var versions: [VersionSnapshot]

    /// Tracks whether the user has completed the context fork (new projects only).
    var hasChosenContext: Bool

    // MARK: - File keys

    private static let projectFilename = "project.json"
    private static let assetsDirname = "assets"
    private static let versionsDirname = "versions"

    // MARK: - Init

    init() {
        self.projectData = ProjectData()
        self.versions = []
        self.hasChosenContext = false
    }

    init(projectData: ProjectData, versions: [VersionSnapshot] = []) {
        self.projectData = projectData
        self.versions = versions
        self.hasChosenContext = true
    }

    // MARK: - ReferenceFileDocument

    static var readableContentTypes: [UTType] { [.inputForge] }
    static var writableContentTypes: [UTType] { [.inputForge] }

    typealias Snapshot = DocumentSnapshot

    struct DocumentSnapshot: Sendable {
        let projectData: ProjectData
        let versions: [VersionSnapshot]
        let assetFiles: [String: Data]
    }

    required init(configuration: ReadConfiguration) throws {
        guard let wrapper = configuration.file.fileWrappers else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard let projectWrapper = wrapper[Self.projectFilename],
              let projectJsonData = projectWrapper.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.projectData = try decoder.decode(ProjectData.self, from: projectJsonData)
        self.hasChosenContext = true

        var loadedVersions: [VersionSnapshot] = []
        if let versionsDir = wrapper[Self.versionsDirname],
           let versionFiles = versionsDir.fileWrappers {
            for (_, vWrapper) in versionFiles {
                if let data = vWrapper.regularFileContents {
                    if let snapshot = try? decoder.decode(VersionSnapshot.self, from: data) {
                        loadedVersions.append(snapshot)
                    }
                }
            }
        }
        self.versions = loadedVersions.sorted { $0.versionNumber < $1.versionNumber }
    }

    func snapshot(contentType: UTType) throws -> DocumentSnapshot {
        DocumentSnapshot(
            projectData: projectData,
            versions: versions,
            assetFiles: [:]
        )
    }

    func fileWrapper(snapshot: DocumentSnapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let root = FileWrapper(directoryWithFileWrappers: [:])

        // project.json
        let projectJsonData = try encoder.encode(snapshot.projectData)
        root.addRegularFile(withContents: projectJsonData, preferredFilename: Self.projectFilename)

        // assets/
        let assetsDir = FileWrapper(directoryWithFileWrappers: [:])
        if let existing = configuration.existingFile?.fileWrappers?[Self.assetsDirname]?.fileWrappers {
            for (name, wrapper) in existing {
                assetsDir.addFileWrapper(wrapper)
                if let added = assetsDir.fileWrappers?[name] {
                    added.preferredFilename = name
                }
            }
        }
        for (filename, data) in snapshot.assetFiles {
            assetsDir.addRegularFile(withContents: data, preferredFilename: filename)
        }
        assetsDir.preferredFilename = Self.assetsDirname
        root.addFileWrapper(assetsDir)

        // versions/
        let versionsDir = FileWrapper(directoryWithFileWrappers: [:])
        for version in snapshot.versions {
            let vData = try encoder.encode(version)
            let vFilename = String(format: "v%03d.json", version.versionNumber)
            versionsDir.addRegularFile(withContents: vData, preferredFilename: vFilename)
        }
        versionsDir.preferredFilename = Self.versionsDirname
        root.addFileWrapper(versionsDir)

        return root
    }

    // MARK: - Mutations

    func addInput(_ item: InputItem) {
        projectData.inputs.append(item)
        projectData.modifiedAt = .now
    }

    func removeInput(id: UUID) {
        projectData.inputs.removeAll { $0.id == id }
        projectData.modifiedAt = .now
    }

    func addAnnotation(_ annotation: InputAnnotation, toInputId inputId: UUID) {
        guard let idx = projectData.inputs.firstIndex(where: { $0.id == inputId }) else { return }
        projectData.inputs[idx].annotations.append(annotation)
        projectData.modifiedAt = .now
    }

    func setContext(_ context: ProjectContext) {
        guard !hasChosenContext else { return }
        projectData.context = context
        hasChosenContext = true
        projectData.modifiedAt = .now
    }

    func setPersona(_ persona: Persona) {
        projectData.persona = persona
        projectData.modifiedAt = .now
    }

    func setAnalysisResult(_ result: AnalysisResult) {
        projectData.currentAnalysis = result
        projectData.modifiedAt = .now

        let versionSnapshot = VersionSnapshot(
            versionNumber: result.version,
            personaName: projectData.persona.name,
            clarityScore: result.clarityScore,
            plan: result.plan,
            uncertaintyFlags: result.uncertaintyFlags,
            inputRefs: projectData.inputs.map(\.id)
        )
        versions.append(versionSnapshot)
    }

    func restoreVersion(_ versionSnapshot: VersionSnapshot) {
        let newVersion = (versions.map(\.versionNumber).max() ?? 0) + 1
        let result = AnalysisResult(
            plan: versionSnapshot.plan,
            clarityScore: versionSnapshot.clarityScore,
            uncertaintyFlags: versionSnapshot.uncertaintyFlags,
            version: newVersion
        )
        setAnalysisResult(result)
    }
}
