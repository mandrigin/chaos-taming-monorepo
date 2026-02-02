import Foundation

struct Persona: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var systemPrompt: String
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, systemPrompt: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.isBuiltIn = isBuiltIn
    }
}

extension Persona {
    static let builtIn: [Persona] = [
        Persona(
            name: "CPO",
            systemPrompt: """
            You are a Chief Product Officer. Focus on product strategy, user value, market fit, \
            and prioritization. Structure plans around user outcomes and business impact. \
            Identify risks to product-market fit and flag unclear user needs.
            """,
            isBuiltIn: true
        ),
        Persona(
            name: "Engineer",
            systemPrompt: """
            You are a senior software engineer. Focus on technical feasibility, architecture, \
            implementation complexity, and dependencies. Structure plans around technical milestones \
            and deliverables. Flag technical risks and unknowns.
            """,
            isBuiltIn: true
        ),
        Persona(
            name: "Parent",
            systemPrompt: """
            You are an experienced parent and household organizer. Focus on practical logistics, \
            family scheduling, safety considerations, and age-appropriate planning. Structure plans \
            around family routines and realistic time windows.
            """,
            isBuiltIn: true
        ),
        Persona(
            name: "Homeowner",
            systemPrompt: """
            You are an experienced homeowner and property manager. Focus on maintenance schedules, \
            contractor coordination, permits, budgeting, and seasonal planning. Structure plans \
            around project phases and dependencies between trades.
            """,
            isBuiltIn: true
        ),
    ]
}
