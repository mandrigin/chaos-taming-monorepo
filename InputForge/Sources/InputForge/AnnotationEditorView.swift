import SwiftUI

/// Sheet view for managing annotations on an input item.
struct AnnotationEditorView: View {
    @Bindable var document: InputForgeDocument
    let inputId: UUID
    @State private var newAnnotationText = ""
    @State private var editingAnnotationId: UUID?
    @State private var editText = ""
    @Environment(\.dismiss) private var dismiss

    private var input: InputItem? {
        document.projectData.inputs.first { $0.id == inputId }
    }

    private var inputIndex: Int? {
        document.projectData.inputs.firstIndex { $0.id == inputId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Annotations")
                    .font(.system(.headline, design: .monospaced))
                if let input {
                    Text("— \(input.filename ?? input.type.rawValue)")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            // Annotation list
            if let input, !input.annotations.isEmpty {
                List {
                    ForEach(input.annotations) { annotation in
                        annotationRow(annotation)
                    }
                    .onDelete { offsets in
                        deleteAnnotations(at: offsets)
                    }
                }
                .listStyle(.plain)
            } else {
                ContentUnavailableView {
                    Label("No Annotations", systemImage: "note.text")
                } description: {
                    Text("Add a sticky note to this input.")
                }
                .frame(maxHeight: .infinity)
            }

            Divider()

            // Add new annotation
            HStack {
                TextField("Add annotation...", text: $newAnnotationText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addAnnotation() }

                Button(action: addAnnotation) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(newAnnotationText.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.plain)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    @ViewBuilder
    private func annotationRow(_ annotation: InputAnnotation) -> some View {
        if editingAnnotationId == annotation.id {
            HStack {
                TextField("Annotation", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { saveEdit(for: annotation.id) }

                Button("Save") { saveEdit(for: annotation.id) }
                    .buttonStyle(.plain)
                Button("Cancel") { editingAnnotationId = nil }
                    .buttonStyle(.plain)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(annotation.text)
                    .font(.system(.body, design: .monospaced))
                Text(annotation.createdAt, style: .relative)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                editingAnnotationId = annotation.id
                editText = annotation.text
            }
        }
    }

    private func addAnnotation() {
        let trimmed = newAnnotationText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let annotation = InputAnnotation(text: trimmed)
        document.addAnnotation(annotation, toInputId: inputId)
        newAnnotationText = ""
    }

    private func saveEdit(for annotationId: UUID) {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let idx = inputIndex else { return }

        if let aIdx = document.projectData.inputs[idx].annotations.firstIndex(where: { $0.id == annotationId }) {
            document.projectData.inputs[idx].annotations[aIdx].text = trimmed
            document.projectData.modifiedAt = .now
        }
        editingAnnotationId = nil
    }

    private func deleteAnnotations(at offsets: IndexSet) {
        guard let idx = inputIndex else { return }
        document.projectData.inputs[idx].annotations.remove(atOffsets: offsets)
        document.projectData.modifiedAt = .now
    }
}
