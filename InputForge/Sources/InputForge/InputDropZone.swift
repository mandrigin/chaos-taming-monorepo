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
    var onAddText: () -> Void
    var audioService: AudioRecordingService
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

            HStack(spacing: 12) {
                Button(action: onAddText) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 10))
                        Text("ADD TEXT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1)
                    }
                }
                .buttonStyle(ForgeButtonStyle(variant: .secondary, compact: true))

                RecordAudioButton(isRecording: audioService.isRecording)
            }
            .padding(.top, 8)
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

/// Toggle button for starting/stopping audio recording.
/// Posts `.toggleAudioRecording` notification so `ProjectWorkspaceView` handles the lifecycle.
struct RecordAudioButton: View {
    let isRecording: Bool
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .toggleAudioRecording, object: nil)
        } label: {
            HStack(spacing: 4) {
                if isRecording {
                    Circle()
                        .fill(ForgeColors.error)
                        .frame(width: 8, height: 8)
                    Text("STOP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10))
                    Text("RECORD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
            }
        }
        .buttonStyle(ForgeButtonStyle(variant: isRecording ? .destructive : .secondary, compact: true))
    }
}
