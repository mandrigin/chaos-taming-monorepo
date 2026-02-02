import Foundation

// MARK: - Structured Plan Hierarchy

/// A GTD next-action within a task.
struct NextAction: Codable, Identifiable {
    var id: UUID
    var title: String
    var context: String?
    var estimate: String?
    var notes: String?

    init(id: UUID = UUID(), title: String, context: String? = nil, estimate: String? = nil, notes: String? = nil) {
        self.id = id
        self.title = title
        self.context = context
        self.estimate = estimate
        self.notes = notes
    }
}

/// A task within a deliverable.
struct PlanTask: Codable, Identifiable {
    var id: UUID
    var title: String
    var dueDate: Date?
    var deferDate: Date?
    var estimate: String?
    var context: String?
    var type: String?
    var isFlagged: Bool
    var notes: String?
    var nextActions: [NextAction]

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        deferDate: Date? = nil,
        estimate: String? = nil,
        context: String? = nil,
        type: String? = nil,
        isFlagged: Bool = false,
        notes: String? = nil,
        nextActions: [NextAction] = []
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.deferDate = deferDate
        self.estimate = estimate
        self.context = context
        self.type = type
        self.isFlagged = isFlagged
        self.notes = notes
        self.nextActions = nextActions
    }
}

/// A deliverable within a milestone.
struct Deliverable: Codable, Identifiable {
    var id: UUID
    var title: String
    var tasks: [PlanTask]

    init(id: UUID = UUID(), title: String, tasks: [PlanTask] = []) {
        self.id = id
        self.title = title
        self.tasks = tasks
    }
}

/// A milestone within the project plan.
struct Milestone: Codable, Identifiable {
    var id: UUID
    var title: String
    var deliverables: [Deliverable]

    init(id: UUID = UUID(), title: String, deliverables: [Deliverable] = []) {
        self.id = id
        self.title = title
        self.deliverables = deliverables
    }
}

/// The full structured project plan produced by analysis.
struct ProjectPlan: Codable {
    var description: String
    var milestones: [Milestone]

    init(description: String = "", milestones: [Milestone] = []) {
        self.description = description
        self.milestones = milestones
    }
}

/// The result of an AI analysis pass.
struct AnalysisResult: Codable {
    var plan: ProjectPlan
    var clarityScore: Double
    var uncertaintyFlags: [String]
    var version: Int

    init(plan: ProjectPlan = ProjectPlan(), clarityScore: Double = 0, uncertaintyFlags: [String] = [], version: Int = 0) {
        self.plan = plan
        self.clarityScore = clarityScore
        self.uncertaintyFlags = uncertaintyFlags
        self.version = version
    }
}
