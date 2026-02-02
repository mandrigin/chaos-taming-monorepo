import SwiftUI

// MARK: - Diff Model

enum DiffStatus {
    case added, removed, modified, unchanged

    var color: Color {
        switch self {
        case .added: return .green
        case .removed: return .red
        case .modified: return .orange
        case .unchanged: return Color(white: 0.4)
        }
    }

    var prefix: String {
        switch self {
        case .added: return "+"
        case .removed: return "\u{2212}"
        case .modified: return "~"
        case .unchanged: return " "
        }
    }
}

struct MilestoneDiff: Identifiable {
    let id = UUID()
    let status: DiffStatus
    let old: Milestone?
    let new: Milestone?
    let deliverableDiffs: [DeliverableDiff]
}

struct DeliverableDiff: Identifiable {
    let id = UUID()
    let status: DiffStatus
    let old: Deliverable?
    let new: Deliverable?
    let taskDiffs: [TaskDiff]
}

struct TaskDiff: Identifiable {
    let id = UUID()
    let status: DiffStatus
    let old: PlanTask?
    let new: PlanTask?
}

// MARK: - Diff Computation

func computeMilestoneDiffs(old: [Milestone], new: [Milestone]) -> [MilestoneDiff] {
    var result: [MilestoneDiff] = []
    var unmatchedNew = new

    for oldMs in old {
        // Match by title (AI regenerates UUIDs each analysis)
        if let matchIdx = unmatchedNew.firstIndex(where: {
            $0.title.lowercased() == oldMs.title.lowercased()
        }) {
            let newMs = unmatchedNew.remove(at: matchIdx)
            let delDiffs = computeDeliverableDiffs(old: oldMs.deliverables, new: newMs.deliverables)
            let status: DiffStatus = delDiffs.allSatisfy({ $0.status == .unchanged })
                ? .unchanged : .modified
            result.append(MilestoneDiff(status: status, old: oldMs, new: newMs, deliverableDiffs: delDiffs))
        } else {
            result.append(MilestoneDiff(status: .removed, old: oldMs, new: nil, deliverableDiffs: []))
        }
    }

    for newMs in unmatchedNew {
        result.append(MilestoneDiff(status: .added, old: nil, new: newMs, deliverableDiffs: []))
    }

    return result
}

func computeDeliverableDiffs(old: [Deliverable], new: [Deliverable]) -> [DeliverableDiff] {
    var result: [DeliverableDiff] = []
    var unmatchedNew = new

    for oldDel in old {
        if let matchIdx = unmatchedNew.firstIndex(where: {
            $0.title.lowercased() == oldDel.title.lowercased()
        }) {
            let newDel = unmatchedNew.remove(at: matchIdx)
            let taskDiffs = computeTaskDiffs(old: oldDel.tasks, new: newDel.tasks)
            let status: DiffStatus = taskDiffs.allSatisfy({ $0.status == .unchanged })
                ? .unchanged : .modified
            result.append(DeliverableDiff(status: status, old: oldDel, new: newDel, taskDiffs: taskDiffs))
        } else {
            result.append(DeliverableDiff(status: .removed, old: oldDel, new: nil, taskDiffs: []))
        }
    }

    for newDel in unmatchedNew {
        result.append(DeliverableDiff(status: .added, old: nil, new: newDel, taskDiffs: []))
    }

    return result
}

func computeTaskDiffs(old: [PlanTask], new: [PlanTask]) -> [TaskDiff] {
    var result: [TaskDiff] = []
    var unmatchedNew = new

    for oldTask in old {
        if let matchIdx = unmatchedNew.firstIndex(where: {
            $0.title.lowercased() == oldTask.title.lowercased()
        }) {
            let newTask = unmatchedNew.remove(at: matchIdx)
            let changed = oldTask.isFlagged != newTask.isFlagged
                || oldTask.notes != newTask.notes
                || oldTask.estimate != newTask.estimate
                || oldTask.nextActions.count != newTask.nextActions.count
            result.append(TaskDiff(status: changed ? .modified : .unchanged, old: oldTask, new: newTask))
        } else {
            result.append(TaskDiff(status: .removed, old: oldTask, new: nil))
        }
    }

    for newTask in unmatchedNew {
        result.append(TaskDiff(status: .added, old: nil, new: newTask))
    }

    return result
}

// MARK: - Version History View

struct VersionHistoryView: View {
    @Bindable var document: InputForgeDocument
    @Environment(\.forgeTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var selectedVersion: VersionSnapshot.ID?
    @State private var compareVersion: VersionSnapshot.ID?
    @State private var isCompareMode = false
    @State private var showRestoreConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider().background(theme.accent.opacity(0.3))

            if document.versions.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    versionList
                        .frame(width: 320)

                    Divider().background(Color(red: 0.15, green: 0.15, blue: 0.15))

                    detailPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 550)
        .background(Color(red: 0.06, green: 0.06, blue: 0.07))
        .confirmationDialog(
            "Restore Version?",
            isPresented: $showRestoreConfirmation,
            presenting: selectedVersionSnapshot
        ) { version in
            Button("Restore as V\(String(format: "%03d", nextVersionNumber))") {
                document.restoreVersion(version)
            }
            Button("Cancel", role: .cancel) {}
        } message: { version in
            Text("Creates a new version from V\(String(format: "%03d", version.versionNumber)). Current state is preserved.")
        }
    }

    private var nextVersionNumber: Int {
        (document.versions.map(\.versionNumber).max() ?? 0) + 1
    }

    private var selectedVersionSnapshot: VersionSnapshot? {
        guard let id = selectedVersion else { return nil }
        return document.versions.first { $0.id == id }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("VERSION HISTORY")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(theme.accent)

            Spacer()

            if document.versions.count >= 2 {
                Toggle(isOn: $isCompareMode) {
                    Text("COMPARE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: isCompareMode) { _, newValue in
                    if !newValue {
                        compareVersion = nil
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Text("CLOSE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(white: 0.15))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Color(white: 0.25), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundStyle(theme.accent.opacity(0.4))
            Text("NO VERSIONS YET")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text("Versions are created on each Analyze run")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Version List

    private var versionList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(document.versions.reversed()) { version in
                    VersionRowView(
                        version: version,
                        isSelected: selectedVersion == version.id,
                        isCompareTarget: compareVersion == version.id,
                        isCompareMode: isCompareMode
                    ) {
                        handleVersionTap(version)
                    }
                }
            }
            .padding(8)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if isCompareMode,
           let leftId = selectedVersion,
           let rightId = compareVersion,
           let left = document.versions.first(where: { $0.id == leftId }),
           let right = document.versions.first(where: { $0.id == rightId })
        {
            let older = left.versionNumber < right.versionNumber ? left : right
            let newer = left.versionNumber < right.versionNumber ? right : left
            VersionDiffView(older: older, newer: newer)
        } else if let version = selectedVersionSnapshot {
            VersionDetailView(version: version) {
                showRestoreConfirmation = true
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text(isCompareMode ? "SELECT TWO VERSIONS" : "SELECT A VERSION")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Selection

    private func handleVersionTap(_ version: VersionSnapshot) {
        if isCompareMode {
            if selectedVersion == nil {
                selectedVersion = version.id
            } else if compareVersion == nil && version.id != selectedVersion {
                compareVersion = version.id
            } else if version.id == selectedVersion {
                selectedVersion = compareVersion
                compareVersion = nil
            } else if version.id == compareVersion {
                compareVersion = nil
            } else {
                compareVersion = version.id
            }
        } else {
            selectedVersion = version.id
            compareVersion = nil
        }
    }
}

// MARK: - Version Row

struct VersionRowView: View {
    let version: VersionSnapshot
    let isSelected: Bool
    let isCompareTarget: Bool
    let isCompareMode: Bool
    let action: () -> Void

    @Environment(\.forgeTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(String(format: "V%03d", version.versionNumber))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected || isCompareTarget ? theme.accent : .primary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(version.timestamp.formatted(
                        .dateTime.month(.abbreviated).day().hour().minute()
                    ))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                    Text(version.personaName.uppercased())
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                ClarityBadge(score: version.clarityScore)

                if isCompareMode {
                    if isSelected {
                        compareBadge("A")
                    } else if isCompareTarget {
                        compareBadge("B")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        isSelected || isCompareTarget
                            ? theme.accentDim.opacity(0.3)
                            : Color.clear
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        isSelected || isCompareTarget
                            ? theme.accent.opacity(0.5)
                            : Color(red: 0.15, green: 0.15, blue: 0.15),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func compareBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.black)
            .frame(width: 20, height: 20)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Clarity Badge

struct ClarityBadge: View {
    let score: Double
    @Environment(\.forgeTheme) private var theme

    private var color: Color {
        if score >= 0.8 { return .green }
        if score >= 0.5 { return theme.accent }
        return .red
    }

    var body: some View {
        Text("\(Int(score * 100))%")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.15))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            }
    }
}

// MARK: - Version Detail

struct VersionDetailView: View {
    let version: VersionSnapshot
    let onRestore: () -> Void

    @Environment(\.forgeTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with restore button
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "VERSION %03d", version.versionNumber))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(theme.accent)

                        Text(version.timestamp.formatted(
                            .dateTime.year().month(.wide).day().hour().minute().second()
                        ))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onRestore) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("RESTORE")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
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

                Divider().background(Color(white: 0.2))

                // Metadata
                HStack(spacing: 24) {
                    VersionMetadataItem(label: "PERSONA", value: version.personaName)
                    VersionMetadataItem(label: "CLARITY", value: "\(Int(version.clarityScore * 100))%")
                    VersionMetadataItem(label: "INPUTS", value: "\(version.inputRefs.count)")
                }

                // Uncertainty flags
                if !version.uncertaintyFlags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UNCERTAINTY FLAGS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.secondary)

                        TagFlowLayout(spacing: 6) {
                            ForEach(version.uncertaintyFlags, id: \.self) { flag in
                                Text(flag)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.orange.opacity(0.1))
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 2)
                                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                                    }
                            }
                        }
                    }
                }

                Divider().background(Color(white: 0.2))

                // Plan tree
                PlanTreeView(plan: version.plan)
            }
            .padding(20)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }
}

// MARK: - Metadata Item

struct VersionMetadataItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Plan Tree

struct PlanTreeView: View {
    let plan: ProjectPlan
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PLAN")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)

            if !plan.description.isEmpty {
                Text(plan.description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.09, green: 0.09, blue: 0.1))
                    }
            }

            if plan.milestones.isEmpty {
                Text("No milestones")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(plan.milestones) { milestone in
                    MilestoneTreeRow(milestone: milestone)
                }
            }
        }
    }
}

struct MilestoneTreeRow: View {
    let milestone: Milestone
    @State private var isExpanded = true
    @Environment(\.forgeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            milestoneHeader
            if isExpanded {
                milestoneContent
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color(red: 0.15, green: 0.15, blue: 0.15), lineWidth: 1)
        }
    }

    private var milestoneHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 12)

                Text(milestone.title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private var milestoneContent: some View {
        ForEach(milestone.deliverables) { deliverable in
            DeliverableTreeRow(deliverable: deliverable)
        }
    }
}

struct DeliverableTreeRow: View {
    let deliverable: Deliverable

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deliverable.title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.leading, 20)

            ForEach(deliverable.tasks) { task in
                taskRow(task)
            }
        }
    }

    private func taskRow(_ task: PlanTask) -> some View {
        HStack(spacing: 6) {
            Image(systemName: task.isFlagged ? "flag.fill" : "circle")
                .font(.system(size: 8))
                .foregroundStyle(task.isFlagged ? Color.orange : Color(white: 0.35))
            Text(task.title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 36)
    }
}

// MARK: - Version Diff View

struct VersionDiffView: View {
    let older: VersionSnapshot
    let newer: VersionSnapshot

    @Environment(\.forgeTheme) private var theme
    @State private var diffMode: DiffDisplayMode = .sideBySide

    enum DiffDisplayMode: String, CaseIterable {
        case sideBySide = "Side-by-Side"
        case inline = "Inline"
    }

    var body: some View {
        VStack(spacing: 0) {
            diffHeader

            Divider().background(theme.accent.opacity(0.3))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metadataComparison
                    Divider().background(Color(white: 0.2))
                    planDiff
                }
                .padding(20)
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    // MARK: - Diff Header

    private var diffHeader: some View {
        HStack {
            Text(String(format: "V%03d", older.versionNumber))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.red.opacity(0.8))

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            Text(String(format: "V%03d", newer.versionNumber))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.green.opacity(0.8))

            Spacer()

            Picker("", selection: $diffMode) {
                ForEach(DiffDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }

    // MARK: - Metadata Comparison

    private var metadataComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("METADATA")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                DiffFieldView(
                    label: "CLARITY",
                    oldValue: "\(Int(older.clarityScore * 100))%",
                    newValue: "\(Int(newer.clarityScore * 100))%"
                )
                DiffFieldView(
                    label: "PERSONA",
                    oldValue: older.personaName,
                    newValue: newer.personaName
                )
                DiffFieldView(
                    label: "INPUTS",
                    oldValue: "\(older.inputRefs.count)",
                    newValue: "\(newer.inputRefs.count)"
                )
            }

            uncertaintyFlagsDiff
        }
    }

    @ViewBuilder
    private var uncertaintyFlagsDiff: some View {
        let removedFlags = Set(older.uncertaintyFlags).subtracting(newer.uncertaintyFlags)
        let addedFlags = Set(newer.uncertaintyFlags).subtracting(older.uncertaintyFlags)
        let keptFlags = Set(older.uncertaintyFlags).intersection(newer.uncertaintyFlags)

        if !removedFlags.isEmpty || !addedFlags.isEmpty || !keptFlags.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("UNCERTAINTY FLAGS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.tertiary)

                TagFlowLayout(spacing: 6) {
                    ForEach(Array(keptFlags).sorted(), id: \.self) { flag in
                        DiffTagView(text: flag, status: .unchanged)
                    }
                    ForEach(Array(removedFlags).sorted(), id: \.self) { flag in
                        DiffTagView(text: flag, status: .removed)
                    }
                    ForEach(Array(addedFlags).sorted(), id: \.self) { flag in
                        DiffTagView(text: flag, status: .added)
                    }
                }
            }
        }
    }

    // MARK: - Plan Diff

    private var planDiff: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PLAN")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)

            // Description diff
            if older.plan.description != newer.plan.description {
                switch diffMode {
                case .sideBySide:
                    HStack(alignment: .top, spacing: 8) {
                        DiffBlockView(text: older.plan.description, status: .removed)
                        DiffBlockView(text: newer.plan.description, status: .added)
                    }
                case .inline:
                    VStack(spacing: 2) {
                        DiffBlockView(text: older.plan.description, status: .removed)
                        DiffBlockView(text: newer.plan.description, status: .added)
                    }
                }
            } else if !older.plan.description.isEmpty {
                DiffBlockView(text: older.plan.description, status: .unchanged)
            }

            // Milestone diffs
            let diffs = computeMilestoneDiffs(old: older.plan.milestones, new: newer.plan.milestones)

            ForEach(diffs) { entry in
                MilestoneDiffRow(entry: entry, mode: diffMode)
            }
        }
    }
}

// MARK: - Diff Field

struct DiffFieldView: View {
    let label: String
    let oldValue: String
    let newValue: String

    private var changed: Bool { oldValue != newValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.tertiary)

            if changed {
                HStack(spacing: 4) {
                    Text(oldValue)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.8))
                        .strikethrough()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)

                    Text(newValue)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.8))
                }
            } else {
                Text(oldValue)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Diff Tag

struct DiffTagView: View {
    let text: String
    let status: DiffStatus

    var body: some View {
        HStack(spacing: 3) {
            if status != .unchanged {
                Text(status.prefix)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            Text(text)
                .font(.system(size: 10, design: .monospaced))
        }
        .foregroundStyle(status == .unchanged ? .secondary : status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 2)
                .fill(status.color.opacity(status == .unchanged ? 0.05 : 0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(status.color.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - Diff Block

struct DiffBlockView: View {
    let text: String
    let status: DiffStatus

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if status != .unchanged {
                Text(status.prefix)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(status.color)
                    .frame(width: 14)
            }

            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(status == .unchanged ? .secondary : status.color.opacity(0.9))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 2)
                .fill(status.color.opacity(status == .unchanged ? 0.03 : 0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(status.color.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - Milestone Diff Row

struct MilestoneDiffRow: View {
    let entry: MilestoneDiff
    let mode: VersionDiffView.DiffDisplayMode

    @Environment(\.forgeTheme) private var theme
    @State private var isExpanded = true

    private var title: String {
        entry.new?.title ?? entry.old?.title ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Milestone header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(entry.status.color)
                        .frame(width: 12)

                    if entry.status != .unchanged {
                        Text(entry.status.prefix)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(entry.status.color)
                    }

                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.status == .unchanged ? .primary : entry.status.color)

                    if entry.status == .modified {
                        Text("MODIFIED")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.orange.opacity(0.15))
                            }
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(entry.deliverableDiffs) { delDiff in
                    DeliverableDiffRow(entry: delDiff, mode: mode)
                }

                // For added/removed milestones, show full content
                if entry.status == .added, let ms = entry.new {
                    ForEach(ms.deliverables) { del in
                        deliverableContent(del, status: .added)
                    }
                } else if entry.status == .removed, let ms = entry.old {
                    ForEach(ms.deliverables) { del in
                        deliverableContent(del, status: .removed)
                    }
                }
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.status.color.opacity(entry.status == .unchanged ? 0.02 : 0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(entry.status.color.opacity(0.2), lineWidth: 1)
        }
    }

    private func deliverableContent(_ del: Deliverable, status: DiffStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(status.prefix)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(status.color)
                Text(del.title)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(status.color.opacity(0.8))
            }
            .padding(.leading, 20)

            ForEach(del.tasks) { task in
                HStack(spacing: 6) {
                    Text(status.prefix)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(status.color)
                    Image(systemName: task.isFlagged ? "flag.fill" : "circle")
                        .font(.system(size: 8))
                        .foregroundStyle(status.color.opacity(0.6))
                    Text(task.title)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(status.color.opacity(0.8))
                }
                .padding(.leading, 36)
            }
        }
    }
}

// MARK: - Deliverable Diff Row

struct DeliverableDiffRow: View {
    let entry: DeliverableDiff
    let mode: VersionDiffView.DiffDisplayMode

    private var title: String {
        entry.new?.title ?? entry.old?.title ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if entry.status != .unchanged {
                    Text(entry.status.prefix)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.status.color)
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(entry.status == .unchanged ? .secondary : entry.status.color.opacity(0.8))
            }
            .padding(.leading, 20)

            ForEach(entry.taskDiffs) { taskDiff in
                TaskDiffRow(entry: taskDiff)
            }

            // For added/removed deliverables, show full content
            if entry.status == .added, let del = entry.new {
                ForEach(del.tasks) { task in
                    taskRow(task, status: .added)
                }
            } else if entry.status == .removed, let del = entry.old {
                ForEach(del.tasks) { task in
                    taskRow(task, status: .removed)
                }
            }
        }
    }

    private func taskRow(_ task: PlanTask, status: DiffStatus) -> some View {
        HStack(spacing: 6) {
            Text(status.prefix)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(status.color)
            Image(systemName: task.isFlagged ? "flag.fill" : "circle")
                .font(.system(size: 8))
                .foregroundStyle(status.color.opacity(0.6))
            Text(task.title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(status.color.opacity(0.8))
        }
        .padding(.leading, 36)
    }
}

// MARK: - Task Diff Row

struct TaskDiffRow: View {
    let entry: TaskDiff

    private var title: String {
        entry.new?.title ?? entry.old?.title ?? ""
    }

    private var isFlagged: Bool {
        entry.new?.isFlagged ?? entry.old?.isFlagged ?? false
    }

    var body: some View {
        HStack(spacing: 6) {
            if entry.status != .unchanged {
                Text(entry.status.prefix)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(entry.status.color)
            }
            Image(systemName: isFlagged ? "flag.fill" : "circle")
                .font(.system(size: 8))
                .foregroundStyle(
                    entry.status == .unchanged
                        ? (isFlagged ? .orange : Color(white: 0.35))
                        : entry.status.color.opacity(0.6)
                )
            Text(title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(entry.status == .unchanged ? .secondary : entry.status.color.opacity(0.8))
        }
        .padding(.leading, 36)
    }
}

// MARK: - Tag Flow Layout

struct TagFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        computeLayout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
