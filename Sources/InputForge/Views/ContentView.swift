import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var document: InputForgeDocument

    @State private var showingExport = false
    @State private var isInterrogating = false
    @State private var showPersonaPicker = false
    @State private var showVersionHistory = false
    @State private var isRecordingAudio = false

    private var theme: ForgeTheme {
        document.hasChosenContext
            ? .forContext(document.projectData.context)
            : .neutral
    }

    var body: some View {
        ZStack {
            ForgeColors.background
                .ignoresSafeArea()

            ScanLineOverlay()
                .ignoresSafeArea()
            GrainOverlay()
                .ignoresSafeArea()

            if showingExport, document.projectData.currentAnalysis != nil {
                TaskPaperPreviewView(document: document)
            } else if !document.projectData.inputs.isEmpty {
                InputTrayView(document: document)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(theme.accent.opacity(0.5))

                    Text("INPUTFORGE")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(ForgeColors.textPrimary)

                    Text(document.projectData.name)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(ForgeColors.textSecondary)

                    if document.projectData.currentAnalysis != nil {
                        Text("Analysis available — press \u{2318}\u{21e7}E to export")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(ForgeColors.textTertiary)
                    } else {
                        Text("No analysis yet")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(ForgeColors.textMuted)
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .environment(\.forgeTheme, theme)
        .tint(theme.accent)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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
                                .strokeBorder(
                                    showingExport ? theme.accent : theme.accent.opacity(0.5),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runAnalysis)) { _ in
            // Analysis trigger — handled when analysis pipeline is connected
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
        .onReceive(NotificationCenter.default.publisher(for: .toggleAudioRecording)) { _ in
            isRecordingAudio.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchPersona)) { _ in
            showPersonaPicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showVersionHistory)) { _ in
            showVersionHistory = true
        }
        .sheet(isPresented: $showPersonaPicker) {
            PersonaPickerSheet(document: document)
        }
        .sheet(isPresented: $showVersionHistory) {
            VersionHistorySheet(document: document)
        }
    }
}

// MARK: - Persona Picker Sheet

struct PersonaPickerSheet: View {
    @Bindable var document: InputForgeDocument
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
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            List {
                ForEach(Persona.builtIn) { persona in
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
            HStack {
                Text("VERSION HISTORY")
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .tracking(2)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            if document.versions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundStyle(ForgeColors.textTertiary)
                    Text("No versions yet")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(ForgeColors.textMuted)
                    Text("Run an analysis to create the first version")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(ForgeColors.textDim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(document.versions.reversed()) { version in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Version \(version.versionNumber)")
                                    .font(.system(.body, design: .monospaced, weight: .semibold))
                                    .foregroundStyle(ForgeColors.textPrimary)
                                Text(version.personaName)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(ForgeColors.textTertiary)
                            }
                            Spacer()
                            Text("\(Int(version.clarityScore * 100))%")
                                .font(.system(.caption, design: .monospaced, weight: .medium))
                                .foregroundStyle(theme.accent)
                            Button("Restore") {
                                document.restoreVersion(version)
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
