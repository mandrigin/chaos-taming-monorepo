import Combine
import SwiftUI

struct ContentView: View {
    @Bindable var document: InputForgeDocument

    private var theme: ForgeTheme {
        document.hasChosenContext
            ? .forContext(document.projectData.context)
            : .neutral
    }

    var body: some View {
        Group {
            if !document.hasChosenContext {
                ContextForkView(document: document)
                    .transition(.opacity)
            } else {
                ProjectWorkspaceView(document: document)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .environment(\.forgeTheme, theme)
        .tint(theme.accent)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Context Fork

/// Full-screen context selection shown once per new project.
struct ContextForkView: View {
    @Bindable var document: InputForgeDocument

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.06)
                .ignoresSafeArea()

            ScanLineOverlay()
                .ignoresSafeArea()
            GrainOverlay()
                .ignoresSafeArea()

            VStack(spacing: 44) {
                // Title block
                VStack(spacing: 14) {
                    Text("INPUTFORGE")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .tracking(8)
                        .foregroundStyle(.white)

                    Rectangle()
                        .frame(width: 120, height: 2)
                        .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))

                    Text("SELECT CONTEXT")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.45))
                }

                // Context cards
                HStack(spacing: 32) {
                    ContextCard(context: .work) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            document.setContext(.work)
                        }
                    }
                    ContextCard(context: .personal) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            document.setContext(.personal)
                        }
                    }
                }

                // Permanence warning
                Text("THIS CHOICE IS PERMANENT")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
            }
        }
    }
}

/// Themed selection card for a project context.
struct ContextCard: View {
    let context: ProjectContext
    let action: () -> Void

    @State private var isHovered = false

    private var theme: ForgeTheme { .forContext(context) }

    private var subtitle: String {
        switch context {
        case .work: return "Orange theme \u{00b7} Work API"
        case .personal: return "Teal theme \u{00b7} Personal API"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: context == .work ? "briefcase.fill" : "house.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(isHovered ? theme.accent : Color(red: 0.5, green: 0.5, blue: 0.5))

                Text(context.displayName.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(isHovered ? theme.accent : Color(red: 0.7, green: 0.7, blue: 0.7))

                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(
                        isHovered
                            ? theme.accent.opacity(0.7)
                            : Color(red: 0.35, green: 0.35, blue: 0.35)
                    )
            }
            .frame(width: 220, height: 200)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isHovered ? theme.accentDim.opacity(0.3) : Color(red: 0.09, green: 0.09, blue: 0.09))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        isHovered ? theme.accent : Color(red: 0.2, green: 0.2, blue: 0.2),
                        lineWidth: isHovered ? 3 : 2
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Workspace

/// Main project workspace shown after context fork.
struct ProjectWorkspaceView: View {
    @Bindable var document: InputForgeDocument
    @Environment(\.forgeTheme) private var theme
    @State private var audioService = AudioRecordingService()
    @State private var coordinator = AnalysisCoordinator()
    @State private var isInterrogating = false
    @State private var showingExport = false
    @State private var showVersionHistory = false

    var body: some View {
        ZStack {
            Group {
                if isInterrogating {
                    InterrogationView(document: document) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isInterrogating = false
                        }
                    }
                    .transition(.opacity)
                } else {
                    NavigationSplitView {
                        InputSidebarView(document: document)
                            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                    } detail: {
                        VStack(spacing: 0) {
                            // Error banner
                            if case .error(let message) = coordinator.state {
                                AnalysisErrorBanner(message: message) {
                                    coordinator.dismissError()
                                }
                                .padding(.top, 8)
                            }

                            // Main content
                            if showingExport, document.projectData.currentAnalysis != nil {
                                TaskPaperPreviewView(document: document)
                            } else if let analysis = document.projectData.currentAnalysis {
                                AnalysisResultView(
                                    analysis: analysis,
                                    personaName: document.projectData.persona.name,
                                    onReanalyze: { coordinator.runAnalysis(document: document) }
                                )
                            } else {
                                InputStageView(document: document)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 8) {
                        // Analyze button
                        Button {
                            coordinator.runAnalysis(document: document)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("ANALYZE")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1)
                            }
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.accentDim.opacity(0.3))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(theme.accent.opacity(0.5), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(coordinator.state.isAnalyzing || document.projectData.inputs.isEmpty)

                        Text(document.projectData.context.displayName.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.accentDim.opacity(0.3))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(theme.accent.opacity(0.5), lineWidth: 1)
                            }

                        Text(document.projectData.persona.name.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 2))

                        if document.projectData.currentAnalysis != nil {
                            Button {
                                showingExport.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showingExport ? "xmark" : "square.and.arrow.up")
                                        .font(.system(size: 10))
                                    Text(showingExport ? "CLOSE" : "EXPORT")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .tracking(1)
                                }
                                .foregroundStyle(showingExport ? .white : theme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(showingExport ? theme.accent.opacity(0.3) : theme.accentDim.opacity(0.3))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(theme.accent.opacity(0.5), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isInterrogating.toggle()
                            }
                        } label: {
                            Image(systemName: isInterrogating
                                ? "bubble.left.and.bubble.right.fill"
                                : "bubble.left.and.bubble.right")
                                .font(.system(size: 12))
                                .foregroundStyle(isInterrogating ? theme.accent : .secondary)
                        }
                        .help(isInterrogating ? "Exit Interrogation" : "Enter Interrogation Mode")
                    }
                }
            }

            if audioService.isRecording {
                AudioRecordingBar(duration: audioService.recordingDuration) {
                    finishRecording()
                }
            }

            // Progress overlay
            if coordinator.state.isAnalyzing {
                AnalysisProgressView(
                    progress: coordinator.state.progress,
                    onCancel: { coordinator.cancel() }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runAnalysis)) { _ in
            coordinator.runAnalysis(document: document)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleAudioRecording)) { _ in
            if audioService.isRecording {
                finishRecording()
            } else {
                _ = audioService.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .enterInterrogation)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isInterrogating = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportTaskPaper)) { _ in
            if document.projectData.currentAnalysis != nil {
                showingExport = true
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
        .onReceive(NotificationCenter.default.publisher(for: .showVersionHistory)) { _ in
            showVersionHistory = true
        }
        .sheet(isPresented: $showVersionHistory) {
            VersionHistoryView(document: document)
                .environment(\.forgeTheme, theme)
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
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        List {
            Section {
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
            } header: {
                Text("INPUTS (\(document.projectData.inputs.count))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(theme.accent)
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
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        if document.projectData.inputs.isEmpty {
            InputDropZone(document: document)
        } else {
            InputTrayView(document: document)
        }
    }
}

