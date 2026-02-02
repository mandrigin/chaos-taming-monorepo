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
    @State private var isInterrogating = false

    var body: some View {
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
                    if document.projectData.currentAnalysis != nil {
                        AnalysisPreviewPlaceholder()
                    } else {
                        InputStageView(document: document)
                    }
                }
                .transition(.opacity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
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
        .onReceive(NotificationCenter.default.publisher(for: .enterInterrogation)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isInterrogating = true
            }
        }
    }
}

struct InputSidebarView: View {
    @Bindable var document: InputForgeDocument
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(document.projectData.inputs) { input in
                    Label(
                        input.filename ?? input.type.rawValue,
                        systemImage: iconName(for: input.type)
                    )
                    .font(.system(.body, design: .monospaced))
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
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 32))
                .foregroundStyle(theme.accent.opacity(0.5))
            Text("DROP INPUTS HERE")
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text("Screenshots, documents, audio, video, mindmaps, text")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [10, 5]),
                    antialiased: true
                )
                .foregroundStyle(theme.accent.opacity(0.2))
                .padding()
        }
    }
}

struct AnalysisPreviewPlaceholder: View {
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        Text("ANALYSIS RESULTS")
            .font(.system(.body, design: .monospaced, weight: .medium))
            .tracking(2)
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
