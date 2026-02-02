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
    @State private var errorMessage: String?
    @State private var showPersonaPicker = false
    @State private var showVersionHistory = false
    @State private var isAnalyzing = false
    @State private var showExportSheet = false
    @State private var showInterrogation = false
    @State private var glitchTrigger = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                NavigationSplitView {
                    InputSidebarView(document: document)
                        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                } detail: {
                    ZStack {
                        if isAnalyzing {
                            AnalysisProgressView()
                        } else if document.projectData.currentAnalysis != nil {
                            AnalysisPreviewPlaceholder()
                        } else {
                            InputStageView(document: document)
                        }
                    }
                    .forgeGlitch(glitchTrigger)
                }

                if audioService.isRecording {
                    AudioRecordingBar(duration: audioService.recordingDuration) {
                        finishRecording()
                    }
                }
            }
            .overlay {
                ScanLineOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Error banner at the top
            if let error = errorMessage {
                ErrorBanner(message: error) {
                    errorMessage = nil
                }
                .padding(.top, 4)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    ForgeBadge(text: document.projectData.context.displayName.uppercased())

                    ForgeBadge(text: document.projectData.persona.name.uppercased(), style: .muted)
                }
            }
        }
        // MARK: - Keyboard shortcut handlers
        .onReceive(NotificationCenter.default.publisher(for: .toggleAudioRecording)) { _ in
            if audioService.isRecording {
                finishRecording()
            } else {
                _ = audioService.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runAnalysis)) { _ in
            runAnalysis()
        }
        .onReceive(NotificationCenter.default.publisher(for: .enterInterrogation)) { _ in
            showInterrogation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportTaskPaper)) { _ in
            exportTaskPaper()
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
        .sheet(isPresented: $showPersonaPicker) {
            PersonaPickerSheet(document: document)
        }
        .sheet(isPresented: $showVersionHistory) {
            VersionHistorySheet(document: document)
        }
        .sheet(isPresented: $showInterrogation) {
            InterrogationPlaceholderSheet()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(document: document)
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

    private func runAnalysis() {
        guard !document.projectData.inputs.isEmpty else {
            showError("Add at least one input before running analysis.")
            return
        }

        guard !isAnalyzing else { return }
        isAnalyzing = true
        glitchTrigger.toggle()

        let context = document.projectData.context
        let persona = document.projectData.persona
        let inputs = document.projectData.inputs
        let name = document.projectData.name
        let version = (document.versions.map(\.versionNumber).max() ?? 0) + 1

        Task {
            defer {
                isAnalyzing = false
            }

            do {
                let service: any AIService = switch AIBackend.current {
                case .gemini: GeminiAIService(context: context)
                case .foundationModels: FoundationModelsAIService()
                }

                let messages = PromptBuilder.buildAnalysisMessages(
                    persona: persona,
                    inputs: inputs,
                    projectName: name,
                    version: version
                )

                let response = try await service.analyze(messages: messages)
                let result = try AIResponseParser.parseAnalysisResponse(response, version: version)
                document.setAnalysisResult(result)
                glitchTrigger.toggle()
            } catch let error as AIServiceError {
                showError(error.errorDescription ?? "Analysis failed.")
            } catch {
                showError("Analysis failed: \(error.localizedDescription)")
            }
        }
    }

    private func exportTaskPaper() {
        guard document.projectData.currentAnalysis != nil else {
            showError("Run analysis first to generate a plan for export.")
            return
        }
        showExportSheet = true
    }

    private func showError(_ message: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            errorMessage = message
        }
        // Auto-dismiss after 8 seconds
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

// MARK: - Input Stage

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

// MARK: - Analysis Progress

struct AnalysisProgressView: View {
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        ZStack {
            ForgeColors.background

            AnimatedScanLineOverlay()

            ScanLineOverlay()
            GrainOverlay()

            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)
                    .tint(theme.accent)

                Text("ANALYZING")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(theme.accent)

                Text("Processing inputs through AI")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ForgeColors.textTertiary)
            }
        }
    }
}

// MARK: - Analysis Preview Placeholder

struct AnalysisPreviewPlaceholder: View {
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        Text("ANALYSIS RESULTS")
            .font(.system(.body, design: .monospaced, weight: .medium))
            .tracking(2)
            .foregroundStyle(ForgeColors.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // Header
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

            // Persona list
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

// MARK: - Version History Sheet

struct VersionHistorySheet: View {
    @Bindable var document: InputForgeDocument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("VERSION HISTORY")
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

            if document.versions.isEmpty {
                ContentUnavailableView {
                    Label("No Versions", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Run analysis to create the first version.")
                        .font(.system(.caption, design: .monospaced))
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(document.versions.reversed()) { version in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("v\(version.versionNumber)")
                                    .font(.system(.body, design: .monospaced, weight: .bold))
                                    .foregroundStyle(ForgeColors.textPrimary)
                                HStack(spacing: 12) {
                                    Text(version.timestamp, style: .relative)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(ForgeColors.textTertiary)
                                    Text(version.personaName)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(ForgeColors.textTertiary)
                                }
                            }

                            Spacer()

                            // Clarity score bar
                            ClarityScoreBadge(score: version.clarityScore)

                            Button("Restore") {
                                document.restoreVersion(version)
                                dismiss()
                            }
                            .buttonStyle(ForgeButtonStyle(variant: .secondary, compact: true))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(width: 560, height: 420)
    }
}

/// Compact clarity score display.
struct ClarityScoreBadge: View {
    let score: Double
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            // Mini bar
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
            // Header
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

            // TaskPaper preview
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

            // Actions
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

// MARK: - Interrogation Placeholder

struct InterrogationPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("INTERROGATION MODE")
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

            ContentUnavailableView {
                Label("Interrogation Mode", systemImage: "bubble.left.and.text.bubble.right")
            } description: {
                Text("Chat-style Q&A with AI to refine the plan.")
                    .font(.system(.caption, design: .monospaced))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 560, height: 480)
    }
}
