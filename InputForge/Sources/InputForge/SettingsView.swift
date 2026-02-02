import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("AI Providers", systemImage: "cpu") {
                AIProvidersSettingsView()
            }
            Tab("Personas", systemImage: "person.2.fill") {
                PersonasSettingsView()
            }
        }
        .frame(width: 560, height: 520)
        .preferredColorScheme(.dark)
    }
}

// MARK: - AI Providers (per-context)

struct AIProvidersSettingsView: View {
    @State private var selectedTab: ProjectContext = .work

    var body: some View {
        VStack(spacing: 0) {
            // Context tab selector
            Picker("Context", selection: $selectedTab) {
                ForEach(ProjectContext.allCases) { context in
                    Text(context.displayName).tag(context)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ContextProviderSettingsView(context: selectedTab)
        }
    }
}

/// Provider + model + API key configuration for a single context.
private struct ContextProviderSettingsView: View {
    let context: ProjectContext

    @State private var selectedProvider: AIBackend = .gemini
    @State private var apiKey = ""
    @State private var keyStored = false
    @State private var errorMessage: String?
    @State private var modelStore = GeminiModelStore.shared
    @State private var selectedModelID = ""
    @State private var claudeCodeAvailable = false

    var body: some View {
        Form {
            Section("Provider") {
                ForEach(AIBackend.allCases, id: \.self) { backend in
                    Button {
                        selectedProvider = backend
                        AIBackend.setSelectedProvider(backend, for: context)
                        refreshState()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(backend.displayName)
                                        .font(.system(.body, design: .monospaced, weight: .semibold))
                                    if backend == .claudeCode {
                                        Text(claudeCodeAvailable ? "DETECTED" : "NOT FOUND")
                                            .font(.system(.caption2, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(claudeCodeAvailable ? ForgeColors.success.opacity(0.2) : ForgeColors.error.opacity(0.2))
                                            .foregroundStyle(claudeCodeAvailable ? ForgeColors.success : ForgeColors.error)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(backend.subtitle)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(ForgeColors.textTertiary)
                            }
                            Spacer()
                            if selectedProvider == backend {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if selectedProvider.requiresAPIKey {
                Section("\(context.displayName) \u{2014} \(selectedProvider.displayName) API Key") {
                    HStack {
                        SecureField("Enter API key", text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                        if keyStored {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ForgeColors.success)
                                .help("Key stored in Keychain")
                        }
                    }
                    HStack(spacing: 8) {
                        Button("Save") { saveKey() }
                            .buttonStyle(ForgeButtonStyle(compact: true))
                            .disabled(apiKey.isEmpty)
                        Button("Clear") { clearKey() }
                            .buttonStyle(ForgeButtonStyle(variant: .destructive, compact: true))
                            .disabled(!keyStored)
                    }
                }
            }

            if selectedProvider == .gemini {
                Section("\(context.displayName) \u{2014} Gemini Model") {
                    DynamicGeminiModelPicker(
                        selectedID: $selectedModelID,
                        models: modelStore.availableModels,
                        isLoading: modelStore.isLoading
                    ) { id in
                        ModelSelection.setSelectedModelID(id, provider: .gemini, context: context)
                    }
                }

                if let error = modelStore.lastError {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ForgeColors.error)
                            Text(error)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(ForgeColors.error)
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ForgeColors.error)
                        Text(error)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(ForgeColors.error)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshState() }
        .onChange(of: context) { refreshState() }
        .task(id: selectedProvider) {
            if selectedProvider == .gemini {
                await modelStore.fetchModelsIfNeeded(for: context)
            }
        }
    }

    private func saveKey() {
        do {
            try KeychainService.save(apiKey: apiKey, provider: selectedProvider, context: context)
            apiKey = ""
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
        }
        refreshState()
    }

    private func clearKey() {
        KeychainService.delete(provider: selectedProvider, context: context)
        errorMessage = nil
        refreshState()
    }

    private func refreshState() {
        selectedProvider = AIBackend.selectedProvider(for: context)
        keyStored = KeychainService.hasAPIKey(provider: selectedProvider, context: context)
        selectedModelID = ModelSelection.selectedModelID(provider: selectedProvider, context: context)
        claudeCodeAvailable = AIBackend.isClaudeCodeAvailable
    }
}

// MARK: - Personas

struct PersonasSettingsView: View {
    @State private var store = PersonaStore.shared
    @State private var sheetState: PersonaSheetState?

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Built-in") {
                    ForEach(Persona.builtIn) { persona in
                        SettingsPersonaRow(persona: persona, isBuiltIn: true)
                    }
                }

                Section("Custom") {
                    if store.customPersonas.isEmpty {
                        Text("No custom personas")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(ForgeColors.textMuted)
                    } else {
                        ForEach(store.customPersonas) { persona in
                            SettingsPersonaRow(persona: persona, isBuiltIn: false)
                                .contextMenu {
                                    Button("Edit") { sheetState = .edit(persona) }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        store.delete(persona)
                                    }
                                }
                        }
                    }
                }
            }

            Divider()
                .overlay(ForgeColors.border)

            HStack {
                Spacer()
                Button("Add Persona") {
                    sheetState = .addNew
                }
                .buttonStyle(ForgeButtonStyle(compact: true))
                .padding(12)
            }
        }
        .sheet(item: $sheetState) { state in
            switch state {
            case .addNew:
                PersonaEditorSheet { persona in
                    store.add(persona)
                }
            case .edit(let persona):
                PersonaEditorSheet(persona: persona) { updated in
                    store.update(updated)
                }
            }
        }
    }
}

private enum PersonaSheetState: Identifiable {
    case addNew
    case edit(Persona)

    var id: String {
        switch self {
        case .addNew: return "new"
        case .edit(let p): return p.id.uuidString
        }
    }
}

private struct SettingsPersonaRow: View {
    let persona: Persona
    let isBuiltIn: Bool

    private var displayPrompt: String {
        persona.isNeutral
            ? "No flavor \u{2014} just a competent project planning assistant"
            : persona.systemPrompt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(persona.name)
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                if isBuiltIn {
                    Text("BUILT-IN")
                        .font(.system(.caption2, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ForgeColors.surface)
                        .clipShape(Capsule())
                }
            }
            Text(displayPrompt)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(ForgeColors.textTertiary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

private struct PersonaEditorSheet: View {
    let onSave: (Persona) -> Void

    @State private var name: String
    @State private var systemPrompt: String
    @Environment(\.dismiss) private var dismiss

    private let existingId: UUID?
    private let isNew: Bool

    init(persona: Persona? = nil, onSave: @escaping (Persona) -> Void) {
        self.onSave = onSave
        self.existingId = persona?.id
        self.isNew = persona == nil
        _name = State(initialValue: persona?.name ?? "")
        _systemPrompt = State(initialValue: persona?.systemPrompt ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isNew ? "NEW PERSONA" : "EDIT PERSONA")
                .font(.system(.headline, design: .monospaced, weight: .bold))
                .tracking(2)
                .padding(.top, 16)

            Form {
                TextField("Name", text: $name)
                    .font(.system(.body, design: .monospaced))

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(ForgeButtonStyle(variant: .secondary, compact: true))
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    let persona = Persona(
                        id: existingId ?? UUID(),
                        name: name,
                        systemPrompt: systemPrompt
                    )
                    onSave(persona)
                    dismiss()
                }
                .buttonStyle(ForgeButtonStyle(compact: true))
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || systemPrompt.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 440, height: 360)
    }
}

// MARK: - Gemini Model Picker (reusable)

private struct DynamicGeminiModelPicker: View {
    @Binding var selectedID: String
    let models: [GeminiModelInfo]
    let isLoading: Bool
    var onChange: (String) -> Void

    var body: some View {
        if isLoading && models.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading models\u{2026}")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ForgeColors.textTertiary)
            }
        } else if models.isEmpty {
            Text("No models available. Check your API key.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(ForgeColors.textMuted)
        } else {
            ForEach(models) { model in
                Button {
                    selectedID = model.id
                    onChange(model.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(.system(.body, design: .monospaced, weight: .medium))
                            Text(model.description)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(ForgeColors.textTertiary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if selectedID == model.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
