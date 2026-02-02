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
    }
}

// MARK: - API Keys

struct APIKeysSettingsView: View {
    @State private var workKey = ""
    @State private var personalKey = ""
    @State private var workKeyStored = false
    @State private var personalKeyStored = false

    var body: some View {
        Form {
            Section {
                Text("API keys are stored in the macOS Keychain. They are never saved in project files.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Section("Work \u{2014} Gemini API Key") {
                HStack {
                    SecureField("Enter API key", text: $workKey)
                        .font(.system(.body, design: .monospaced))
                    if workKeyStored {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .help("Key stored in Keychain")
                    }
                }
                HStack(spacing: 8) {
                    Button("Save") { saveKey(.work) }
                        .disabled(workKey.isEmpty)
                    Button("Clear", role: .destructive) { clearKey(.work) }
                        .disabled(!workKeyStored)
                }
            }

            Section("Personal \u{2014} Gemini API Key") {
                HStack {
                    SecureField("Enter API key", text: $personalKey)
                        .font(.system(.body, design: .monospaced))
                    if personalKeyStored {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .help("Key stored in Keychain")
                    }
                }
                HStack(spacing: 8) {
                    Button("Save") { saveKey(.personal) }
                        .disabled(personalKey.isEmpty)
                    Button("Clear", role: .destructive) { clearKey(.personal) }
                        .disabled(!personalKeyStored)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshStatus() }
    }

    private func saveKey(_ context: ProjectContext) {
        let key = context == .work ? workKey : personalKey
        try? KeychainService.save(apiKey: key, for: context)
        if context == .work { workKey = "" } else { personalKey = "" }
        refreshStatus()
    }

    private func clearKey(_ context: ProjectContext) {
        KeychainService.delete(for: context)
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
                            .foregroundStyle(.tertiary)
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

            HStack {
                Spacer()
                Button("Add Persona") {
                    sheetState = .addNew
                }
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
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            Text(persona.systemPrompt)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
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
            Text(isNew ? "New Persona" : "Edit Persona")
                .font(.system(.headline, design: .monospaced))
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
                Button("Cancel", role: .cancel) { dismiss() }
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

    var body: some View {
        Form {
            Section {
                Text("Choose the AI backend for processing inputs and generating plans.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
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
                                    .foregroundStyle(.secondary)
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
        }
        .formStyle(.grouped)
    }
}
