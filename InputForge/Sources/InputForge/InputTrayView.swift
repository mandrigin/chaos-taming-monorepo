import SwiftUI
import UniformTypeIdentifiers

/// Scrollable grid layout showing input items with thumbnails and annotation counts.
/// Supports drag-to-reorder and has a compact drop zone for adding more files.
struct InputTrayView: View {
    @Bindable var document: InputForgeDocument
    var onAddText: () -> Void
    @Environment(\.forgeTheme) private var theme
    @State private var selectedInputId: UUID?
    @State private var isDragTargeted = false
    @State private var thumbnailCache: [UUID: NSImage] = [:]

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
                            thumbnail: thumbnailCache[input.id],
                            onSelect: { selectedInputId = input.id },
                            onDelete: { document.removeInput(id: input.id) },
                            onAnnotate: { selectedInputId = input.id }
                        )
                        .draggable(input.id.uuidString)
                        .task(id: input.id) {
                            await generateThumbnail(for: input)
                        }
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
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.dashed")
                    .foregroundStyle(isDragTargeted ? theme.accent : ForgeColors.textTertiary)
                Text("Drop more files here")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isDragTargeted ? theme.accent : ForgeColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 3]))
                    .foregroundStyle(isDragTargeted ? theme.accent : ForgeColors.border)
            }

            Button(action: onAddText) {
                HStack(spacing: 4) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 10))
                    Text("ADD TEXT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
            }
            .buttonStyle(ForgeButtonStyle(variant: .secondary, compact: true))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func generateThumbnail(for input: InputItem) async {
        guard thumbnailCache[input.id] == nil else { return }
        guard let data = document.assetData(for: input) else { return }
        if let thumb = await InputProcessor.generateThumbnail(for: input, data: data) {
            thumbnailCache[input.id] = thumb
        }
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
    let thumbnail: NSImage?
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onAnnotate: () -> Void

    @Environment(\.forgeTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail area
            thumbnailView
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 2))

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
                        .foregroundStyle(theme.accent.opacity(0.8))
                }
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    isSelected
                        ? theme.accentDim.opacity(0.3)
                        : (isHovered ? ForgeColors.surfaceHover : Color.clear)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(
                    isSelected ? theme.accent.opacity(0.6) : (isHovered ? ForgeColors.border : Color.clear),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Add Annotation") { onAnnotate() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ForgeColors.surface)
        } else {
            let iconSize: CGFloat = 36
            switch input.type {
            case .image, .screenshot:
                thumbnailPlaceholder(systemName: "photo.fill", iconSize: iconSize)
            case .audio:
                audioWaveformPlaceholder
            case .video:
                thumbnailPlaceholder(systemName: "film", iconSize: iconSize)
            case .document:
                thumbnailPlaceholder(systemName: "doc.text.fill", iconSize: iconSize)
            case .text:
                Text(input.textContent?.prefix(80) ?? "Text")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(ForgeColors.textTertiary)
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(ForgeColors.surface)
            case .mindmap:
                thumbnailPlaceholder(systemName: "brain", iconSize: iconSize)
            case .wardleyMap:
                thumbnailPlaceholder(systemName: "map", iconSize: iconSize)
            case .chat:
                thumbnailPlaceholder(systemName: "bubble.left.and.bubble.right", iconSize: iconSize)
            }
        }
    }

    private var audioWaveformPlaceholder: some View {
        HStack(spacing: 2) {
            ForEach(0..<16, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accent.opacity(0.4))
                    .frame(width: 3, height: audioBarHeight(for: i))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ForgeColors.surface)
    }

    private func audioBarHeight(for index: Int) -> CGFloat {
        // Simple static waveform shape for audio thumbnail
        let pattern: [CGFloat] = [6, 12, 18, 24, 30, 36, 30, 24, 36, 30, 18, 24, 12, 18, 8, 6]
        return pattern[index % pattern.count]
    }

    private func thumbnailPlaceholder(systemName: String, iconSize: CGFloat) -> some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize))
            .foregroundStyle(ForgeColors.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ForgeColors.surface)
    }
}
