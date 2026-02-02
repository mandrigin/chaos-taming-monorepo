import SwiftUI

// MARK: - Analysis Result View

/// Displays the structured analysis output: plan hierarchy, clarity score,
/// and uncertainty flags. Cyberdeck aesthetic.
struct AnalysisResultView: View {
    let analysis: AnalysisResult
    let personaName: String
    let onReanalyze: () -> Void

    @Environment(\.forgeTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header bar
                analysisHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .background(theme.accent.opacity(0.3))

                // Metrics row
                metricsRow
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()
                    .background(theme.accent.opacity(0.3))

                // Uncertainty flags
                if !analysis.uncertaintyFlags.isEmpty {
                    uncertaintySection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                    Divider()
                        .background(theme.accent.opacity(0.3))
                }

                // Plan description
                if !analysis.plan.description.isEmpty {
                    descriptionSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                    Divider()
                        .background(theme.accent.opacity(0.3))
                }

                // Plan hierarchy
                planHierarchy
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Header

    private var analysisHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ANALYSIS OUTPUT")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(theme.accent)

                Text("v\(analysis.version) \u{00b7} \(personaName)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onReanalyze) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text("RE-ANALYZE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.accentDim.opacity(0.3))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(theme.accent.opacity(0.5), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: 24) {
            clarityGauge
            metricItem(label: "MILESTONES", value: "\(analysis.plan.milestones.count)")
            metricItem(label: "TASKS", value: "\(totalTaskCount)")
            metricItem(label: "FLAGS", value: "\(analysis.uncertaintyFlags.count)")
        }
    }

    private var clarityGauge: some View {
        HStack(spacing: 8) {
            // Score label
            VStack(alignment: .leading, spacing: 2) {
                Text("CLARITY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.0f%%", analysis.clarityScore * 100))
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(clarityColor)
            }

            // Bar gauge
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(white: 0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(clarityColor)
                            .frame(width: geo.size.width * analysis.clarityScore, height: 6)
                    }
                }
                .frame(width: 80, height: 6)
            }
        }
    }

    private var clarityColor: Color {
        if analysis.clarityScore >= 0.7 { return .green }
        if analysis.clarityScore >= 0.4 { return .yellow }
        return .red
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private var totalTaskCount: Int {
        analysis.plan.milestones.flatMap(\.deliverables).flatMap(\.tasks).count
    }

    // MARK: - Uncertainty Flags

    private var uncertaintySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UNCERTAINTY FLAGS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.orange)

            ForEach(Array(analysis.uncertaintyFlags.enumerated()), id: \.offset) { _, flag in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .frame(width: 14)

                    Text(flag)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.85))
                }
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DESCRIPTION")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)

            Text(analysis.plan.description)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)
        }
    }

    // MARK: - Plan Hierarchy

    private var planHierarchy: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PROJECT PLAN")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(theme.accent)

            ForEach(analysis.plan.milestones) { milestone in
                MilestoneRow(milestone: milestone, theme: theme)
            }
        }
    }
}

// MARK: - Milestone Row

private struct MilestoneRow: View {
    let milestone: Milestone
    let theme: ForgeTheme
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Milestone header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 12)

                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)

                    Text(milestone.title.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.primary)

                    Spacer()

                    let taskCount = milestone.deliverables.flatMap(\.tasks).count
                    Text("\(taskCount) tasks")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(milestone.deliverables) { deliverable in
                    DeliverableRow(deliverable: deliverable, theme: theme)
                        .padding(.leading, 24)
                }
            }
        }
    }
}

// MARK: - Deliverable Row

private struct DeliverableRow: View {
    let deliverable: Deliverable
    let theme: ForgeTheme
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: "cube.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    Text(deliverable.title)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.9))

                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(deliverable.tasks) { task in
                    TaskRow(task: task, theme: theme)
                        .padding(.leading, 24)
                }
            }
        }
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: PlanTask
    let theme: ForgeTheme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                guard !task.nextActions.isEmpty || task.notes != nil else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    if !task.nextActions.isEmpty || task.notes != nil {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)
                    } else {
                        Spacer().frame(width: 10)
                    }

                    Circle()
                        .fill(task.isFlagged ? theme.accent : Color(white: 0.3))
                        .frame(width: 5, height: 5)

                    Text(task.title)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(2)

                    Spacer()

                    taskTags
                }
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let notes = task.notes {
                        Text(notes)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                    }

                    ForEach(task.nextActions) { action in
                        NextActionRow(action: action)
                            .padding(.leading, 24)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var taskTags: some View {
        HStack(spacing: 4) {
            if let estimate = task.estimate {
                tagPill(estimate, color: .blue)
            }
            if let context = task.context {
                tagPill("@\(context)", color: .purple)
            }
            if let type = task.type {
                tagPill(type, color: .gray)
            }
        }
    }

    private func tagPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(color.opacity(0.8))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.1))
            }
    }
}

// MARK: - Next Action Row

private struct NextActionRow: View {
    let action: NextAction

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.tertiary)

            Text(action.title)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.7))

            Spacer()

            if let context = action.context {
                Text("@\(context)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.purple.opacity(0.6))
            }
            if let estimate = action.estimate {
                Text(estimate)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.blue.opacity(0.6))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Analysis Progress View

/// Full-screen overlay shown during analysis processing.
struct AnalysisProgressView: View {
    let progress: Double
    let onCancel: () -> Void

    @Environment(\.forgeTheme) private var theme

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Spinner
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.accent)
                    .rotationEffect(.degrees(progress * 360))
                    .animation(.linear(duration: 0.3), value: progress)

                VStack(spacing: 8) {
                    Text("ANALYZING")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(theme.accent)

                    Text("Processing inputs through persona...")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(white: 0.15))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.accent)
                                .frame(width: geo.size.width * progress, height: 4)
                                .animation(.easeInOut(duration: 0.2), value: progress)
                        }
                    }
                    .frame(width: 200, height: 4)

                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Button(action: onCancel) {
                    Text("CANCEL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .overlay {
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(Color(white: 0.3), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(40)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(theme.accent.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

// MARK: - Analysis Error Banner

/// Dismissable error banner shown when analysis fails.
struct AnalysisErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 14))
                .foregroundStyle(.red)

            Text(message)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red.opacity(0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }
}
