import SwiftUI

struct ContentView: View {
    @Bindable var document: InputForgeDocument

    var body: some View {
        Group {
            if !document.hasChosenContext {
                ContextForkView(document: document)
            } else {
                ProjectWorkspaceView(document: document)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

/// Placeholder for the context fork selection screen.
struct ContextForkView: View {
    @Bindable var document: InputForgeDocument

    var body: some View {
        VStack(spacing: 32) {
            Text("INPUTFORGE")
                .font(.system(.largeTitle, design: .monospaced, weight: .black))
                .tracking(4)

            Text("Choose your context. This is permanent for this project.")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                ForEach(ProjectContext.allCases) { context in
                    ContextButton(context: context) {
                        document.setContext(context)
                    }
                }
            }
        }
        .padding(48)
    }
}

struct ContextButton: View {
    let context: ProjectContext
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: context == .work ? "briefcase.fill" : "house.fill")
                    .font(.system(size: 40))
                Text(context.displayName)
                    .font(.system(.title2, design: .monospaced, weight: .bold))
            }
            .frame(width: 180, height: 160)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Main project workspace shown after context fork.
struct ProjectWorkspaceView: View {
    @Bindable var document: InputForgeDocument
    @State private var audioService = AudioRecordingService()

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                InputSidebarView(document: document)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            } detail: {
                if document.projectData.currentAnalysis != nil {
                    AnalysisPreviewPlaceholder()
                } else {
                    InputStageView(document: document)
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Text(document.projectData.persona.name)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }

            if audioService.isRecording {
                AudioRecordingBar(duration: audioService.recordingDuration) {
                    finishRecording()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleAudioRecording)) { _ in
            if audioService.isRecording {
                finishRecording()
            } else {
                _ = audioService.toggle()
            }
        }
        .onPasteCommand(of: [.image, .png, .tiff, .utf8PlainText]) { providers in
            if let result = ClipboardHandler.importFromClipboard() {
                if let data = result.1 {
                    document.addInput(result.0, assetData: data)
                } else {
                    document.addInput(result.0)
                }
            }
        }
    }

    private func finishRecording() {
        guard let url = audioService.toggle() else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        let filename = url.lastPathComponent
        let item = InputItem(
            type: .audio,
            filename: filename,
            assetPath: filename
        )
        document.addInput(item, assetData: data)

        try? FileManager.default.removeItem(at: url)
    }
}

struct InputSidebarView: View {
    @Bindable var document: InputForgeDocument

    var body: some View {
        List {
            Section("Inputs (\(document.projectData.inputs.count))") {
                ForEach(document.projectData.inputs) { input in
                    HStack {
                        Label(
                            input.filename ?? input.type.rawValue,
                            systemImage: iconName(for: input.type)
                        )
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)

                        Spacer()

                        if !input.annotations.isEmpty {
                            Text("\(input.annotations.count)")
                                .font(.system(.caption2, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { document.projectData.inputs[$0].id }
                    for id in ids {
                        document.removeInput(id: id)
                    }
                }
                .onMove { from, to in
                    document.projectData.inputs.move(fromOffsets: from, toOffset: to)
                    document.projectData.modifiedAt = .now
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func iconName(for type: InputType) -> String {
        switch type {
        case .document: return "doc.text"
        case .image, .screenshot: return "photo"
        case .audio: return "waveform"
        case .video: return "film"
        case .text: return "text.alignleft"
        case .mindmap: return "brain"
        case .wardleyMap: return "map"
        case .chat: return "bubble.left.and.bubble.right"
        }
    }
}

struct InputStageView: View {
    @Bindable var document: InputForgeDocument

    var body: some View {
        if document.projectData.inputs.isEmpty {
            InputDropZone(document: document)
        } else {
            InputTrayView(document: document)
        }
    }
}

struct AnalysisPreviewPlaceholder: View {
    var body: some View {
        Text("Analysis results will appear here")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.system(.body, design: .monospaced))
            .padding()
            .frame(width: 400, height: 300)
    }
}
