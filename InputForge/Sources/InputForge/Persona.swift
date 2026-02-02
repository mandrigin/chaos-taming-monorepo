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
    static let neutral = Persona(
        name: "None",
        systemPrompt: "",
        isBuiltIn: true
    )

    var isNeutral: Bool { systemPrompt.isEmpty }

    static let builtIn: [Persona] = [
        neutral,
        Persona(
            name: "CPO",
            systemPrompt: """
            Emphasize product strategy, user outcomes, market fit, and prioritization. \
            Structure plans around business impact and flag unclear user needs.
            """,
            isBuiltIn: true
        ),
        Persona(
            name: "Engineer",
            systemPrompt: """
            Emphasize technical feasibility, architecture, implementation complexity, \
            and dependencies. Structure plans around technical milestones and flag technical risks.
            """,
            isBuiltIn: true
        ),
        Persona(
            name: "Parent",
            systemPrompt: """
            Emphasize practical logistics, family scheduling, safety considerations, \
            and age-appropriate planning. Structure plans around family routines and realistic time windows.
            """,
            isBuiltIn: true
        ),
        Persona(
            name: "Homeowner",
            systemPrompt: """
            Emphasize maintenance schedules, contractor coordination, permits, budgeting, \
            and seasonal planning. Structure plans around project phases and dependencies between trades.
            """,
            isBuiltIn: true
        ),
    ]
}
