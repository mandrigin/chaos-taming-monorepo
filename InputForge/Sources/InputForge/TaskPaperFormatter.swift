import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let taskPaper: UTType =
        UTType(tag: "taskpaper", tagClass: .filenameExtension, conformingTo: .plainText)
        ?? .plainText
}

/// Converts a ``ProjectPlan`` to OmniFocus-compatible TaskPaper format.
///
/// TaskPaper syntax:
/// - Projects end with `:`
/// - Tasks start with `- `
/// - Notes are plain indented text (no prefix)
/// - Tags are inline after the item title
/// - Indentation uses tabs
struct TaskPaperFormatter {
    let projectName: String
    let plan: ProjectPlan
    let personaName: String

    func format() -> String {
        var lines: [String] = []

        // Project header
        lines.append("\(projectName):")

        // Description as note
        if !plan.description.isEmpty {
            for line in plan.description.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("\t\(line)")
            }
        }

        // Milestones → Deliverables → Tasks → Next Actions
        for milestone in plan.milestones {
            lines.append("\t\(milestone.title):")

            for deliverable in milestone.deliverables {
                lines.append("\t\t\(deliverable.title):")

                for task in deliverable.tasks {
                    lines.append(formatTask(task, depth: 3))
                    appendNotes(task.notes, depth: 4, to: &lines)

                    for action in task.nextActions {
                        lines.append(formatNextAction(action, depth: 4))
                        appendNotes(action.notes, depth: 5, to: &lines)
                    }
                }
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Internal

    static func formatDate(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Private

    private func formatTask(_ task: PlanTask, depth: Int) -> String {
        let indent = String(repeating: "\t", count: depth)
        var tags: [String] = []

        if let due = task.dueDate {
            tags.append("@due(\(Self.formatDate(due)))")
        }
        if let deferDate = task.deferDate {
            tags.append("@defer(\(Self.formatDate(deferDate)))")
        }
        if let estimate = task.estimate {
            tags.append("@estimate(\(estimate))")
        }
        if let context = task.context {
            tags.append("@context(\(context))")
        }
        if task.isFlagged {
            tags.append("@flagged")
        }
        if let type = task.type {
            tags.append("@type(\(type))")
        }
        tags.append("@persona(\(personaName))")

        let tagString = tags.isEmpty ? "" : " " + tags.joined(separator: " ")
        return "\(indent)- \(task.title)\(tagString)"
    }

    private func formatNextAction(_ action: NextAction, depth: Int) -> String {
        let indent = String(repeating: "\t", count: depth)
        var tags: [String] = []

        if let context = action.context {
            tags.append("@context(\(context))")
        }
        if let estimate = action.estimate {
            tags.append("@estimate(\(estimate))")
        }

        let tagString = tags.isEmpty ? "" : " " + tags.joined(separator: " ")
        return "\(indent)- \(action.title)\(tagString)"
    }

    private func appendNotes(_ notes: String?, depth: Int, to lines: inout [String]) {
        guard let notes, !notes.isEmpty else { return }
        let indent = String(repeating: "\t", count: depth)
        for line in notes.split(separator: "\n", omittingEmptySubsequences: false) {
            lines.append("\(indent)\(line)")
        }
    }
}
