import Foundation

/// A snapshot of analysis output at a point in time.
struct VersionSnapshot: Codable, Identifiable {
    var id: UUID
    var versionNumber: Int
    var timestamp: Date
    var personaName: String
    var clarityScore: Double
    var plan: ProjectPlan
    var uncertaintyFlags: [String]
    /// References to input IDs at time of analysis (not copies).
    var inputRefs: [UUID]

    init(
        id: UUID = UUID(),
        versionNumber: Int,
        timestamp: Date = .now,
        personaName: String,
        clarityScore: Double,
        plan: ProjectPlan,
        uncertaintyFlags: [String],
        inputRefs: [UUID]
    ) {
        self.id = id
        self.versionNumber = versionNumber
        self.timestamp = timestamp
        self.personaName = personaName
        self.clarityScore = clarityScore
        self.plan = plan
        self.uncertaintyFlags = uncertaintyFlags
        self.inputRefs = inputRefs
    }
}
