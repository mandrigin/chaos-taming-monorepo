import SwiftUI
import UniformTypeIdentifiers

/// Scrollable grid layout showing input items with thumbnails and annotation counts.
/// Supports drag-to-reorder and has a compact drop zone for adding more files.
struct InputTrayView: View {
    @Bindable var document: InputForgeDocument
    @State private var selectedInputId: UUID?
    @State private var isDragTargeted = false

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(document.projectData.inputs) { input in
                        InputTrayItemView(
                            input: input,
                            isSelected: selectedInputId == input.id,
                            onSelect: { selectedInputId = input.id },
                            onDelete: { document.removeInput(id: input.id) },
                            onAnnotate: { selectedInputId = input.id }
                        )
                        .draggable(input.id.uuidString)
                    }
                }
                .padding()
            }

            // Compact drop zone at the bottom
            compactDropZone
        }
        .onDrop(of: InputTypeDetector.acceptedTypes, isTargeted: $isDragTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .sheet(item: annotationBinding) { input in
            AnnotationEditorView(document: document, inputId: input.id)
        }
    }

    private var annotationBinding: Binding<InputItem?> {
        Binding(
            get: {
                guard let id = selectedInputId else { return nil }
                return document.projectData.inputs.first { $0.id == id }
            },
            set: { newValue in
                if newValue == nil { selectedInputId = nil }
            }
        )
    }

    private var compactDropZone: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.dashed")
                .foregroundStyle(.secondary)
            Text("Drop more files here")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 3]))
                .foregroundStyle(isDragTargeted ? .primary : .quaternary)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let urlData = data as? Data,
                      let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
                    return
                }
                guard let inputType = InputTypeDetector.detect(url: url) else { return }
                let filename = url.lastPathComponent
                let assetFilename = "\(UUID().uuidString)-\(filename)"
                guard let fileData = try? Data(contentsOf: url) else { return }
                let item = InputItem(
                    type: inputType,
                    filename: filename,
                    assetPath: assetFilename
                )
                Task { @MainActor in
                    document.addInput(item, assetData: fileData)
                }
            }
        }
    }
}

/// Individual item in the input tray grid.
struct InputTrayItemView: View {
    let input: InputItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onAnnotate: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail area
            thumbnailView
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Label
            HStack {
                Text(input.filename ?? input.type.rawValue)
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if !input.annotations.isEmpty {
                    Label("\(input.annotations.count)", systemImage: "note.text")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Add Annotation") { onAnnotate() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        switch input.type {
        case .image, .screenshot:
            Image(systemName: "photo.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        case .audio:
            Image(systemName: "waveform")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        case .video:
            Image(systemName: "film")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        case .document:
            Image(systemName: "doc.text.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        case .text:
            Text(input.textContent?.prefix(80) ?? "Text")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.quaternary)
        case .mindmap:
            Image(systemName: "brain")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        case .wardleyMap:
            Image(systemName: "map")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        case .chat:
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        }
    }
}
