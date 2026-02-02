import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var document: InputForgeDocument

    @State private var showingExport = false

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
        .onReceive(NotificationCenter.default.publisher(for: .exportTaskPaper)) { _ in
            if document.projectData.currentAnalysis != nil {
                showingExport = true
            }
        }
    }
}
