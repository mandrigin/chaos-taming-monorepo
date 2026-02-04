import SwiftUI

/// Chat-style interrogation interface for refining the project plan via AI Q&A.
struct InterrogationView: View {
    @Bindable var document: InputForgeDocument
    @Environment(\.forgeTheme) private var theme
    @State private var viewModel: InterrogationViewModel?

    let onDismiss: () -> Void

    var body: some View {
        Group {
            if let viewModel {
                InterrogationContent(viewModel: viewModel, theme: theme, onDismiss: onDismiss)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if viewModel == nil {
                let vm = InterrogationViewModel(document: document)
                viewModel = vm
                await vm.startInterrogation()
            }
        }
    }
}

// MARK: - Main Layout

private struct InterrogationContent: View {
    @Bindable var viewModel: InterrogationViewModel
    let theme: ForgeTheme
    let onDismiss: () -> Void

    @State private var showErrorDetail = false

    var body: some View {
        HSplitView {
            // Chat panel (primary)
            chatPanel
                .frame(minWidth: 400)

            // Summary panel (secondary)
            summaryPanel
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 320)
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.07))
    }

    // MARK: - Chat Panel

    private var chatPanel: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider().background(theme.accent.opacity(0.3))
            chatMessages
            Divider().background(theme.accent.opacity(0.3))
            chatInputBar
        }
    }

    private var chatHeader: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.accent)

            Text("INTERROGATION")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(theme.accent)

            Spacer()

            // Persona badge
            Text(viewModel.personaName.uppercased())
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    }

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            theme: theme,
                            imageDataProvider: { viewModel.imageData(forInputId: $0) }
                        )
                        .id(message.id)
                    }

                    if viewModel.isSending || viewModel.isStarting {
                        typingIndicator
                    }
                }
                .padding(16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text("ANALYZING INPUTS")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))

            Text("The AI is reviewing your project to identify gaps")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var typingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(theme.accent.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: typingBounce(index: i))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
    }

    private func typingBounce(index: Int) -> CGFloat {
        // Static offset for each dot to suggest animation without actual animation
        // (SwiftUI will handle re-render timing naturally)
        [0, -3, 0][index]
    }

    private var chatInputBar: some View {
        HStack(spacing: 10) {
            TextField("Your answer...", text: $viewModel.userInput, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...4)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.1, green: 0.1, blue: 0.11))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(
                            viewModel.canSend ? theme.accent.opacity(0.5) : Color(red: 0.2, green: 0.2, blue: 0.2),
                            lineWidth: 1
                        )
                }
                .onSubmit {
                    if viewModel.canSend {
                        Task { await viewModel.sendMessage() }
                    }
                }

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(viewModel.canSend ? theme.accent : Color(red: 0.25, green: 0.25, blue: 0.25))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend)
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    }

    // MARK: - Summary Panel

    private var summaryPanel: some View {
        VStack(spacing: 0) {
            summaryHeader
            Divider().background(theme.accent.opacity(0.3))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    clarityGauge
                    uncertaintySection
                    summarySection
                }
                .padding(16)
            }

            Divider().background(theme.accent.opacity(0.3))
            doneRefiningBar
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    private var summaryHeader: some View {
        HStack {
            Image(systemName: "gauge.medium")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.accent)

            Text("STATUS")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(theme.accent)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    }

    private var clarityGauge: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CLARITY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))

            HStack(spacing: 10) {
                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(red: 0.15, green: 0.15, blue: 0.15))

                        RoundedRectangle(cornerRadius: 1)
                            .fill(clarityColor)
                            .frame(width: geo.size.width * viewModel.clarityScore)
                            .animation(.easeInOut(duration: 0.4), value: viewModel.clarityScore)
                    }
                }
                .frame(height: 8)

                Text(String(format: "%.0f%%", viewModel.clarityScore * 100))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(clarityColor)
                    .frame(width: 44, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.4), value: viewModel.clarityScore)
            }
        }
    }

    private var clarityColor: Color {
        let score = viewModel.clarityScore
        if score >= 0.7 { return theme.accent }
        if score >= 0.4 { return Color(hue: 0.12, saturation: 0.8, brightness: 0.9) } // amber
        return Color(hue: 0.0, saturation: 0.7, brightness: 0.8) // red
    }

    private var uncertaintySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UNCERTAINTIES")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))

            if viewModel.uncertaintyFlags.isEmpty {
                Text("None remaining")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.35))
            } else {
                ForEach(viewModel.uncertaintyFlags, id: \.self) { flag in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hue: 0.12, saturation: 0.8, brightness: 0.9))
                            .padding(.top, 2)

                        Text(flag)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(red: 0.6, green: 0.6, blue: 0.6))
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUMMARY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))

            if viewModel.summary.isEmpty {
                Text("Summary will appear as conversation progresses")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
            } else {
                Text(viewModel.summary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.65, green: 0.65, blue: 0.65))
                    .lineSpacing(3)
            }
        }
    }

    private var doneRefiningBar: some View {
        VStack(spacing: 8) {
            if viewModel.error != nil {
                Button {
                    showErrorDetail = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ForgeColors.error)

                        Text("ERROR — TAP FOR DETAILS")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(ForgeColors.error)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ForgeColors.error.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ForgeColors.errorDim.opacity(0.5))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(ForgeColors.error.opacity(0.4), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await viewModel.doneRefining() }
                onDismiss()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isReanalyzing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                    }

                    Text("DONE REFINING")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.accentDim.opacity(0.4))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(theme.accent, lineWidth: 2)
                }
                .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isReanalyzing)
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .sheet(isPresented: $showErrorDetail) {
            if let error = viewModel.error {
                ErrorDetailSheet(errorMessage: error)
            }
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: InterrogationMessage
    let theme: ForgeTheme
    var imageDataProvider: ((UUID) -> Data?)?

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !isUser {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.accent.opacity(0.6))
                    }

                    Text(isUser ? "YOU" : "AI")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(
                            isUser
                                ? Color(red: 0.5, green: 0.5, blue: 0.5)
                                : theme.accent.opacity(0.6)
                        )

                    if isUser {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(message.content)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(
                            isUser
                                ? Color(red: 0.85, green: 0.85, blue: 0.85)
                                : Color(red: 0.75, green: 0.75, blue: 0.75)
                        )
                        .lineSpacing(3)

                    // Display referenced images inline
                    if !message.imageReferences.isEmpty {
                        ForEach(message.imageReferences) { ref in
                            inlineImage(for: ref)
                        }
                    }
                }
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            isUser
                                ? Color(red: 0.12, green: 0.12, blue: 0.13)
                                : theme.accentDim.opacity(0.15)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(
                            isUser
                                ? Color(red: 0.18, green: 0.18, blue: 0.18)
                                : theme.accent.opacity(0.2),
                            lineWidth: 1
                        )
                }
                .textSelection(.enabled)

                Text(message.timestamp, style: .time)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private func inlineImage(for ref: ImageReference) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let data = imageDataProvider?(ref.inputId), let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(theme.accent.opacity(0.3), lineWidth: 1)
                    }
            }

            if let filename = ref.filename {
                Text(filename)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.accent.opacity(0.5))
            }
        }
    }
}

// MARK: - Error Detail Sheet

private struct ErrorDetailSheet: View {
    let errorMessage: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ForgeColors.error)

                Text("ERROR DETAILS")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(ForgeColors.error)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(ForgeColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))

            Divider().background(ForgeColors.error.opacity(0.3))

            // Error content
            ScrollView {
                Text(errorMessage)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(ForgeColors.textPrimary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }

            Divider().background(ForgeColors.border)

            // Copy button
            HStack {
                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(errorMessage, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))

                        Text(copied ? "COPIED" : "COPY ERROR")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ForgeColors.errorDim.opacity(0.5))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(ForgeColors.error.opacity(0.4), lineWidth: 1)
                    }
                    .foregroundStyle(ForgeColors.error)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        }
        .background(ForgeColors.background)
        .frame(minWidth: 400, idealWidth: 500, minHeight: 250, idealHeight: 350)
    }
}
