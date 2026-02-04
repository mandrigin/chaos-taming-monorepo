import Foundation

/// Root data structure serialized to project.json inside the .inputforge package.
struct ProjectData: Codable {
    var id: UUID
    var name: String
    var context: ProjectContext
    var createdAt: Date
    var modifiedAt: Date
    var persona: Persona
    var goalText: String
    var inputs: [InputItem]
    var currentAnalysis: AnalysisResult?
    var interrogation: InterrogationState?

    init(
        id: UUID = UUID(),
        name: String = "Untitled Project",
        context: ProjectContext = .work,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        persona: Persona = .neutral,
        goalText: String = "",
        inputs: [InputItem] = [],
        currentAnalysis: AnalysisResult? = nil,
        interrogation: InterrogationState? = nil
    ) {
        self.id = id
        self.name = name
        self.context = context
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.persona = persona
        self.goalText = goalText
        self.inputs = inputs
        self.currentAnalysis = currentAnalysis
        self.interrogation = interrogation
    }
}
