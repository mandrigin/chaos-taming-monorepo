import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("API Keys", systemImage: "key.fill") {
                APIKeysSettingsView()
            }
            Tab("Personas", systemImage: "person.2.fill") {
                PersonasSettingsView()
            }
            Tab("AI Backend", systemImage: "cpu") {
                AIBackendSettingsView()
            }
        }
        .frame(width: 520, height: 420)
        .preferredColorScheme(.dark)
    }
}

// MARK: - API Keys

struct APIKeysSettingsView: View {
    @State private var workKey = ""
    @State private var personalKey = ""
    @State private var workKeyStored = false
    @State private var personalKeyStored = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text("API keys are stored in the macOS Keychain. They are never saved in project files.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ForgeColors.textTertiary)
            }

            Section("Work \u{2014} Gemini API Key") {
                HStack {
                    SecureField("Enter API key", text: $workKey)
                        .font(.system(.body, design: .monospaced))
                    if workKeyStored {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ForgeColors.success)
                            .help("Key stored in Keychain")
                    }
                }
                HStack(spacing: 8) {
                    Button("Save") { saveKey(.work) }
                        .buttonStyle(ForgeButtonStyle(compact: true))
                        .disabled(workKey.isEmpty)
                    Button("Clear") { clearKey(.work) }
                        .buttonStyle(ForgeButtonStyle(variant: .destructive, compact: true))
                        .disabled(!workKeyStored)
                }
            }

            Section("Personal \u{2014} Gemini API Key") {
                HStack {
                    SecureField("Enter API key", text: $personalKey)
                        .font(.system(.body, design: .monospaced))
                    if personalKeyStored {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ForgeColors.success)
                            .help("Key stored in Keychain")
                    }
                }
                HStack(spacing: 8) {
                    Button("Save") { saveKey(.personal) }
                        .buttonStyle(ForgeButtonStyle(compact: true))
                        .disabled(personalKey.isEmpty)
                    Button("Clear") { clearKey(.personal) }
                        .buttonStyle(ForgeButtonStyle(variant: .destructive, compact: true))
                        .disabled(!personalKeyStored)
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
        .onAppear { refreshStatus() }
    }

    private func saveKey(_ context: ProjectContext) {
        let key = context == .work ? workKey : personalKey
        do {
            try KeychainService.save(apiKey: key, for: context)
            if context == .work { workKey = "" } else { personalKey = "" }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
        }
        refreshStatus()
    }

    private func clearKey(_ context: ProjectContext) {
        KeychainService.delete(for: context)
        errorMessage = nil
        refreshStatus()
    }

    private func refreshStatus() {
        workKeyStored = KeychainService.retrieve(for: .work) != nil
        personalKeyStored = KeychainService.retrieve(for: .personal) != nil
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
                        PersonaRow(persona: persona, isBuiltIn: true)
                    }
                }

                Section("Custom") {
                    if store.customPersonas.isEmpty {
                        Text("No custom personas")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(ForgeColors.textMuted)
                    } else {
                        ForEach(store.customPersonas) { persona in
                            PersonaRow(persona: persona, isBuiltIn: false)
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

private struct PersonaRow: View {
    let persona: Persona
    let isBuiltIn: Bool

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
            Text(persona.systemPrompt)
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

// MARK: - AI Backend

struct AIBackendSettingsView: View {
    @State private var selected: AIBackend = .current
    @State private var workModel: GeminiModel = .current(for: .work)
    @State private var personalModel: GeminiModel = .current(for: .personal)

    var body: some View {
        Form {
            Section {
                Text("Choose the AI backend for processing inputs and generating plans.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ForgeColors.textTertiary)
            }

            Section("Backend") {
                ForEach(AIBackend.allCases, id: \.self) { (backend: AIBackend) in
                    Button {
                        selected = backend
                        AIBackend.current = backend
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(backend.displayName)
                                    .font(.system(.body, design: .monospaced, weight: .semibold))
                                Text(backend.subtitle)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(ForgeColors.textTertiary)
                            }
                            Spacer()
                            if selected == backend {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if selected == .gemini {
                Section("Work \u{2014} Gemini Model") {
                    GeminiModelPicker(selection: $workModel) { model in
                        GeminiModel.setCurrent(model, for: .work)
                    }
                }

                Section("Personal \u{2014} Gemini Model") {
                    GeminiModelPicker(selection: $personalModel) { model in
                        GeminiModel.setCurrent(model, for: .personal)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct GeminiModelPicker: View {
    @Binding var selection: GeminiModel
    var onChange: (GeminiModel) -> Void

    var body: some View {
        ForEach(GeminiModel.allCases) { model in
            Button {
                selection = model
                onChange(model)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.displayName)
                            .font(.system(.body, design: .monospaced, weight: .medium))
                        Text(model.description)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(ForgeColors.textTertiary)
                    }
                    Spacer()
                    if selection == model {
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
