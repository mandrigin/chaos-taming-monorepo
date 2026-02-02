import SwiftUI
import UniformTypeIdentifiers

/// Maps file UTTypes to InputForge InputType categories.
enum InputTypeDetector {
    // Supported document extensions
    private static let documentTypes: Set<UTType> = [
        .pdf, .plainText, .rtf,
        UTType("com.microsoft.word.doc") ?? .data,
        UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
        UTType("com.apple.iwork.pages.sffpages") ?? .data,
        .init("net.daringfireball.markdown") ?? .plainText,
    ]

    private static let imageTypes: Set<UTType> = [
        .png, .jpeg, .heic, .webP, .tiff,
    ]

    private static let audioTypes: Set<UTType> = [
        .mpeg4Audio, .mp3, .wav,
        UTType("public.aac-audio") ?? .audio,
    ]

    private static let videoTypes: Set<UTType> = [
        .mpeg4Movie, .quickTimeMovie,
    ]

    private static let mindmapExtensions: Set<String> = [
        "mindnode", "mm", "opml",
    ]

    static func detect(url: URL) -> InputType? {
        let ext = url.pathExtension.lowercased()

        // Check mindmap by extension first (no standard UTType)
        if mindmapExtensions.contains(ext) {
            return .mindmap
        }

        guard let uttype = UTType(filenameExtension: ext) else { return nil }

        if imageTypes.contains(where: { uttype.conforms(to: $0) }) {
            return .image
        }
        if audioTypes.contains(where: { uttype.conforms(to: $0) }) {
            return .audio
        }
        if videoTypes.contains(where: { uttype.conforms(to: $0) }) {
            return .video
        }
        if documentTypes.contains(where: { uttype.conforms(to: $0) }) {
            return .document
        }

        return nil
    }

    /// All UTTypes accepted by the drop zone.
    static var acceptedTypes: [UTType] {
        [.fileURL]
    }
}

/// The main drop zone view that accepts files and shows drag feedback.
struct InputDropZone: View {
    @Bindable var document: InputForgeDocument
    @Environment(\.forgeTheme) private var theme
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isDragTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundStyle(isDragTargeted ? theme.accent : ForgeColors.textTertiary)
                .symbolEffect(.bounce, value: isDragTargeted)

            Text(isDragTargeted ? "Release to add" : "Drop inputs here")
                .font(.system(.title, design: .monospaced))
                .foregroundStyle(isDragTargeted ? theme.accent : ForgeColors.textTertiary)

            Text("Documents, images, audio, video, mindmaps")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(ForgeColors.textMuted)

            Text("Or paste from clipboard with \u{2318}V")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(ForgeColors.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: isDragTargeted ? 3 : 2, dash: [8, 4])
                )
                .foregroundStyle(isDragTargeted ? theme.accent : ForgeColors.border)
                .padding()
        }
        .onDrop(of: InputTypeDetector.acceptedTypes, isTargeted: $isDragTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let urlData = data as? Data,
                      let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
                    return
                }
                guard let inputType = InputTypeDetector.detect(url: url) else { return }
                let filename = url.lastPathComponent
                let assetFilename = "\(UUID().uuidString)-\(filename)"
                guard let fileData = try? Data(contentsOf: url) else { return }
                let item = InputItem(
                    type: inputType,
                    filename: filename,
                    assetPath: assetFilename
                )
                Task { @MainActor in
                    document.addInput(item, assetData: fileData)
                }
            }
        }
    }
}
