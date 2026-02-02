import AppKit
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
            ForgeColors.background
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
                        .foregroundStyle(ForgeColors.textPrimary)

                    Rectangle()
                        .frame(width: 120, height: 2)
                        .foregroundStyle(ForgeColors.separator)

                    Text("SELECT CONTEXT")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(ForgeColors.textTertiary)
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
                    .foregroundStyle(ForgeColors.textDim)
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
                    .foregroundStyle(isHovered ? theme.accent : ForgeColors.textSecondary)

                Text(context.displayName.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(isHovered ? theme.accent : ForgeColors.textSecondary)

                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(
                        isHovered
                            ? theme.accent.opacity(0.7)
                            : ForgeColors.textMuted
                    )
            }
            .frame(width: 220, height: 200)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isHovered ? theme.accentDim.opacity(0.3) : ForgeColors.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        isHovered ? theme.accent : ForgeColors.border,
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
    @State private var modelStore = GeminiModelStore.shared
    @State private var isInterrogating = false
    @State private var showingExport = false
    @State private var showVersionHistory = false
    @State private var errorMessage: String?
    @State private var showPersonaPicker = false
    @State private var showExportSheet = false
    @State private var glitchTrigger = false

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if isInterrogating {
                    InterrogationView(document: document) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isInterrogating = false
                        }
                    }
                    .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        NavigationSplitView {
                            InputSidebarView(document: document)
                                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                        } detail: {
                            VStack(spacing: 0) {
                                // Error banner from coordinator
                                if case .error(let message) = coordinator.state {
                                    AnalysisErrorBanner(message: message) {
                                        coordinator.dismissError()
                                    }
                                    .padding(.top, 8)
                                }

                                // Main content
                                ZStack {
                                    if showingExport, document.projectData.currentAnalysis != nil {
                                        TaskPaperPreviewView(document: document)
                                    } else if let analysis = document.projectData.currentAnalysis {
                                        AnalysisResultView(
                                            analysis: analysis,
                                            personaName: document.projectData.persona.name,
                                            onReanalyze: { coordinator.runAnalysis(document: document) }
                                        )
                                    } else {
                                        InputStageView(document: document, audioService: audioService)
                                    }
                                }
                                .forgeGlitch(glitchTrigger)
                            }
                        }

                        if audioService.isRecording {
                            AudioRecordingBar(
                                duration: audioService.recordingDuration,
                                audioLevels: audioService.audioLevels
                            ) {
                                finishRecording()
                            }
                        }
                    }
                    .overlay {
                        ScanLineOverlay()
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
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
                            glitchTrigger.toggle()
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

                        ForgeBadge(text: document.projectData.context.displayName.uppercased())

                        ForgeBadge(text: document.projectData.persona.name.uppercased(), style: .muted)

                        if AIBackend.current == .gemini {
                            GeminiModelPickerMenu(
                                context: document.projectData.context,
                                modelStore: modelStore
                            )
                        }

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

            // Error banner at the top
            if let error = errorMessage {
                ErrorBanner(message: error) {
                    errorMessage = nil
                }
                .padding(.top, 4)
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
            glitchTrigger.toggle()
        }
        // MARK: - Keyboard shortcut handlers
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
        .onReceive(NotificationCenter.default.publisher(for: .switchPersona)) { _ in
            showPersonaPicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showVersionHistory)) { _ in
            showVersionHistory = true
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
        .onChange(of: document.projectData.inputs.count) {
            Task { await InputProcessor.processInputs(document: document) }
        }
        .sheet(isPresented: $showPersonaPicker) {
            PersonaPickerSheet(document: document)
        }
        .sheet(isPresented: $showVersionHistory) {
            VersionHistoryView(document: document)
                .environment(\.forgeTheme, theme)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(document: document)
        }
        .task {
            if AIBackend.current == .gemini {
                await modelStore.fetchModelsIfNeeded(for: document.projectData.context)
            }
        }
    }

    private func finishRecording() {
        guard let url = audioService.toggle() else { return }
        guard let data = try? Data(contentsOf: url) else {
            showError("Failed to read recorded audio file.")
            return
        }

        let filename = url.lastPathComponent
        let item = InputItem(
            type: .audio,
            filename: filename,
            assetPath: filename
        )
        document.addInput(item, assetData: data)

        try? FileManager.default.removeItem(at: url)
    }

    private func showError(_ message: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            errorMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if errorMessage == message {
                    errorMessage = nil
                }
            }
        }
    }
}

// MARK: - Sidebar

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
                                .background(ForgeColors.surface)
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
                ForgeSectionHeader(title: "INPUTS (\(document.projectData.inputs.count))")
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

// MARK: - Model Picker Menu

struct GeminiModelPickerMenu: View {
    let context: ProjectContext
    @Bindable var modelStore: GeminiModelStore
    @Environment(\.forgeTheme) private var theme

    @State private var selectedID = ""

    var body: some View {
        Menu {
            if modelStore.isLoading && modelStore.availableModels.isEmpty {
                Text("Loading models\u{2026}")
            } else if modelStore.availableModels.isEmpty {
                Text("No models available")
                Button("Refresh") {
                    Task { await modelStore.fetchModels(for: context) }
                }
            } else {
                ForEach(modelStore.availableModels) { model in
                    Button {
                        selectedID = model.id
                        GeminiModelSelection.setSelectedModelID(model.id, for: context)
                    } label: {
                        HStack {
                            Text(model.displayName)
                            if selectedID == model.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button("Refresh Models") {
                    Task { await modelStore.fetchModels(for: context) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 9))
                Text(currentDisplayName.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundStyle(ForgeColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(ForgeColors.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(ForgeColors.border, lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onAppear {
            selectedID = GeminiModelSelection.selectedModelID(for: context)
        }
    }

    private var currentDisplayName: String {
        if let model = modelStore.availableModels.first(where: { $0.id == selectedID }) {
            return model.displayName
        }
        return selectedID.isEmpty ? "Select Model" : selectedID
    }
}

// MARK: - Input Stage

struct InputStageView: View {
    @Bindable var document: InputForgeDocument
    var audioService: AudioRecordingService
    @State private var isAddingText = false

    var body: some View {
        Group {
            if document.projectData.inputs.isEmpty {
                InputDropZone(document: document, onAddText: { isAddingText = true }, audioService: audioService)
            } else {
                InputTrayView(document: document, onAddText: { isAddingText = true }, audioService: audioService)
            }
        }
        .sheet(isPresented: $isAddingText) {
            TextInputSheet { text in
                let item = InputItem(type: .text, textContent: text)
                document.addInput(item)
            }
        }
    }
}

// MARK: - Text Input Sheet

struct TextInputSheet: View {
    let onCommit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.forgeTheme) private var theme
    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ADD TEXT INPUT")
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .tracking(2)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(ForgeButtonStyle(variant: .secondary, compact: true))
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()
                .overlay(ForgeColors.border)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding()
                .background(ForgeColors.background)

            Divider()
                .overlay(ForgeColors.border)

            HStack {
                Spacer()
                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onCommit(trimmed)
                    dismiss()
                } label: {
                    Label("ADD", systemImage: "text.badge.plus")
                }
                .buttonStyle(ForgeButtonStyle(compact: true))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 520, height: 380)
    }
}

// MARK: - Persona Picker Sheet

struct PersonaPickerSheet: View {
    @Bindable var document: InputForgeDocument
    @State private var store = PersonaStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SWITCH PERSONA")
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .tracking(2)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(ForgeButtonStyle(variant: .secondary, compact: true))
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()
                .overlay(ForgeColors.border)

            List {
                Section {
                    ForEach(store.allPersonas) { persona in
                        Button {
                            document.setPersona(persona)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(persona.name)
                                        .font(.system(.body, design: .monospaced, weight: .semibold))
                                        .foregroundStyle(ForgeColors.textPrimary)
                                    Text(persona.systemPrompt)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(ForgeColors.textTertiary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if document.projectData.persona.id == persona.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    ForgeSectionHeader(title: "AVAILABLE PERSONAS")
                }
            }
        }
        .frame(width: 480, height: 400)
    }
}

// MARK: - Clarity Score Badge

struct ClarityScoreBadge: View {
    let score: Double
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ForgeColors.surface)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.accent)
                        .frame(width: geo.size.width * score)
                }
            }
            .frame(width: 40, height: 6)

            Text("\(Int(score * 100))%")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(ForgeColors.textSecondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    @Bindable var document: InputForgeDocument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.forgeTheme) private var theme
    @State private var exportText = ""
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("EXPORT TASKPAPER")
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .tracking(2)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(ForgeButtonStyle(variant: .secondary, compact: true))
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()
                .overlay(ForgeColors.border)

            ScrollView {
                Text(exportText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ForgeColors.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(ForgeColors.background)

            Divider()
                .overlay(ForgeColors.border)

            HStack(spacing: 12) {
                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportText, forType: .string)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "COPIED" : "COPY", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(ForgeButtonStyle(variant: .secondary, compact: true))

                Button {
                    saveTaskPaperFile()
                } label: {
                    Label("SAVE FILE", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(ForgeButtonStyle(compact: true))
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            exportText = generateTaskPaper()
        }
    }

    private func generateTaskPaper() -> String {
        guard let analysis = document.projectData.currentAnalysis else { return "" }
        let plan = analysis.plan
        let persona = document.projectData.persona.name

        var lines: [String] = []
        lines.append("\(document.projectData.name):")
        if !plan.description.isEmpty {
            lines.append("\t\(plan.description)")
        }

        for milestone in plan.milestones {
            lines.append("\t\(milestone.title):")
            for deliverable in milestone.deliverables {
                lines.append("\t\t\(deliverable.title):")
                for task in deliverable.tasks {
                    var tags = ""
                    if let due = task.dueDate {
                        tags += " @due(\(ISO8601DateFormatter().string(from: due)))"
                    }
                    if let defer_ = task.deferDate {
                        tags += " @defer(\(ISO8601DateFormatter().string(from: defer_)))"
                    }
                    if let est = task.estimate {
                        tags += " @estimate(\(est))"
                    }
                    if let ctx = task.context {
                        tags += " @context(\(ctx))"
                    }
                    if let type = task.type {
                        tags += " @type(\(type))"
                    }
                    if task.isFlagged {
                        tags += " @flagged"
                    }
                    tags += " @persona(\(persona))"

                    lines.append("\t\t\t- \(task.title)\(tags)")
                    if let notes = task.notes {
                        lines.append("\t\t\t\t\(notes)")
                    }

                    for action in task.nextActions {
                        var aTags = ""
                        if let ctx = action.context {
                            aTags += " @context(\(ctx))"
                        }
                        if let est = action.estimate {
                            aTags += " @estimate(\(est))"
                        }
                        lines.append("\t\t\t\t- \(action.title)\(aTags)")
                        if let notes = action.notes {
                            lines.append("\t\t\t\t\t\(notes)")
                        }
                    }
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func saveTaskPaperFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(document.projectData.name).taskpaper"
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? exportText.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

