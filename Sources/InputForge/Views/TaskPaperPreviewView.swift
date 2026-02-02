import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Export View

/// Full export view with header controls and rendered plan hierarchy.
struct TaskPaperPreviewView: View {
    let document: InputForgeDocument
    @Environment(\.forgeTheme) private var theme
    @State private var copied = false

    private var analysis: AnalysisResult? {
        document.projectData.currentAnalysis
    }

    private var taskPaperText: String {
        guard let analysis else { return "" }
        return TaskPaperFormatter(
            projectName: document.projectData.name,
            plan: analysis.plan,
            personaName: document.projectData.persona.name
        ).format()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("TASKPAPER EXPORT")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(theme.accent)

                Spacer()

                HStack(spacing: 12) {
                    copyButton
                    saveButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))

            Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.accent.opacity(0.2))

            // Content
            if let analysis {
                ScrollView {
                    PlanHierarchyView(
                        projectName: document.projectData.name,
                        plan: analysis.plan,
                        personaName: document.projectData.persona.name
                    )
                    .padding(20)
                }
                .background(Color(red: 0.06, green: 0.06, blue: 0.07))
            } else {
                emptyState
            }
        }
    }

    // MARK: - Subviews

    private var copyButton: some View {
        Button {
            copyToClipboard()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                Text(copied ? "COPIED" : "COPY")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(copied ? .green : theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(copied ? Color.green.opacity(0.15) : theme.accentDim.opacity(0.3))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        copied ? Color.green.opacity(0.5) : theme.accent.opacity(0.5),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(analysis == nil)
    }

    private var saveButton: some View {
        Button {
            saveToFile()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 11, weight: .medium))
                Text("SAVE .TASKPAPER")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
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
        .disabled(analysis == nil)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(theme.accent.opacity(0.3))
            Text("NO ANALYSIS AVAILABLE")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.secondary)
            Text("Run analysis first to generate a plan for export")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.06, green: 0.06, blue: 0.07))
    }

    // MARK: - Actions

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(taskPaperText, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private func saveToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(document.projectData.name).taskpaper"
        panel.allowedContentTypes = [.taskPaper]
        panel.allowsOtherFileTypes = true
        let text = taskPaperText
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - Plan Hierarchy View

/// Rendered tree view of the project plan hierarchy.
struct PlanHierarchyView: View {
    let projectName: String
    let plan: ProjectPlan
    let personaName: String
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project header
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.accent)
                Text(projectName)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 4)

            // Description
            if !plan.description.isEmpty {
                Text(plan.description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.55))
                    .padding(.leading, 26)
                    .padding(.bottom, 12)
            }

            // Milestones
            ForEach(plan.milestones) { milestone in
                MilestoneRow(milestone: milestone, personaName: personaName)
                    .padding(.leading, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Milestone

private struct MilestoneRow: View {
    let milestone: Milestone
    let personaName: String
    @Environment(\.forgeTheme) private var theme
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(milestone.deliverables) { deliverable in
                DeliverableRow(deliverable: deliverable, personaName: personaName)
                    .padding(.leading, 16)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.accent.opacity(0.7))
                Text(milestone.title)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Deliverable

private struct DeliverableRow: View {
    let deliverable: Deliverable
    let personaName: String
    @Environment(\.forgeTheme) private var theme
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(deliverable.tasks) { task in
                TaskItemRow(task: task, personaName: personaName)
                    .padding(.leading, 16)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.accent.opacity(0.5))
                Text(deliverable.title)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.75, green: 0.75, blue: 0.75))
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Task

private struct TaskItemRow: View {
    let task: PlanTask
    let personaName: String
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(theme.accent)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(red: 0.9, green: 0.9, blue: 0.9))

                    TagFlowLayout(spacing: 4) {
                        if let due = task.dueDate {
                            TagPill(label: "due", value: TaskPaperFormatter.formatDate(due), color: .orange)
                        }
                        if let deferDate = task.deferDate {
                            TagPill(label: "defer", value: TaskPaperFormatter.formatDate(deferDate), color: .yellow)
                        }
                        if let estimate = task.estimate {
                            TagPill(label: "est", value: estimate, color: .green)
                        }
                        if let context = task.context {
                            TagPill(label: "ctx", value: context, color: .cyan)
                        }
                        if task.isFlagged {
                            TagPill(label: "flagged", value: nil, color: .red)
                        }
                        if let type = task.type {
                            TagPill(label: "type", value: type, color: .purple)
                        }
                        TagPill(label: "persona", value: personaName, color: .gray)
                    }
                }
            }
            .padding(.vertical, 3)

            // Notes
            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                    .padding(.leading, 18)
            }

            // Next actions
            ForEach(task.nextActions) { action in
                NextActionRow(action: action)
                    .padding(.leading, 18)
            }
        }
    }
}

// MARK: - Next Action

private struct NextActionRow: View {
    let action: NextAction
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "circle")
                    .font(.system(size: 4))
                    .foregroundStyle(theme.accent.opacity(0.6))
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(red: 0.8, green: 0.8, blue: 0.8))

                    if action.context != nil || action.estimate != nil {
                        HStack(spacing: 4) {
                            if let context = action.context {
                                TagPill(label: "ctx", value: context, color: .cyan)
                            }
                            if let estimate = action.estimate {
                                TagPill(label: "est", value: estimate, color: .green)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)

            if let notes = action.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.45))
                    .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Tag Pill

/// Small colored badge for a TaskPaper tag.
struct TagPill: View {
    let label: String
    let value: String?
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text("@\(label)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.9))
            if let value {
                Text(value)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(color.opacity(0.7))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        }
    }
}

// MARK: - Flow Layout

/// Horizontal wrapping layout for tag pills.
struct TagFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        computeLayout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: maxX, height: y + rowHeight)
        )
    }
}
