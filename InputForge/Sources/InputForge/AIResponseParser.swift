import Foundation

/// Parses AI text responses into structured AnalysisResult objects.
///
/// Handles JSON extraction from AI output, clarity score computation,
/// and uncertainty flag detection.
struct AIResponseParser: Sendable {
    /// Parse an AI response string into an AnalysisResult.
    ///
    /// The AI is instructed to return raw JSON, but this parser also handles
    /// responses wrapped in markdown code fences.
    ///
    /// - Parameters:
    ///   - response: The raw text response from the AI service.
    ///   - version: The version number to assign to this analysis.
    /// - Returns: A fully populated AnalysisResult.
    static func parseAnalysisResponse(_ response: String, version: Int) throws -> AnalysisResult {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw AIServiceError.invalidResponse(detail: "Response is not valid UTF-8")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try parsing the full response format (with clarityScore and uncertaintyFlags)
        if let fullResponse = try? decoder.decode(FullAIResponse.self, from: data) {
            let plan = ProjectPlan(
                description: fullResponse.description,
                milestones: fullResponse.milestones.map { parseMilestone($0) }
            )

            let clarityScore = clamp(fullResponse.clarityScore, min: 0.0, max: 1.0)

            return AnalysisResult(
                plan: plan,
                clarityScore: clarityScore,
                uncertaintyFlags: fullResponse.uncertaintyFlags,
                version: version
            )
        }

        // Fallback: try parsing just the plan structure
        if let planResponse = try? decoder.decode(PlanOnlyResponse.self, from: data) {
            let plan = ProjectPlan(
                description: planResponse.description,
                milestones: planResponse.milestones.map { parseMilestone($0) }
            )

            let clarityScore = computeClarityScore(plan: plan, uncertaintyFlags: [])

            return AnalysisResult(
                plan: plan,
                clarityScore: clarityScore,
                uncertaintyFlags: [],
                version: version
            )
        }

        throw AIServiceError.invalidResponse(detail: "Could not parse AI response as structured plan")
    }

    /// Compute a clarity score based on plan completeness.
    ///
    /// Factors:
    /// - Has description
    /// - Has milestones
    /// - Milestones have deliverables
    /// - Tasks have estimates and contexts
    /// - Fewer uncertainty flags = higher score
    static func computeClarityScore(
        plan: ProjectPlan,
        uncertaintyFlags: [String]
    ) -> Double {
        var score = 0.0
        var factors = 0.0

        // Has a description
        factors += 1
        if !plan.description.isEmpty { score += 1 }

        // Has milestones
        factors += 1
        if !plan.milestones.isEmpty { score += 1 }

        let allTasks = plan.milestones
            .flatMap(\.deliverables)
            .flatMap(\.tasks)

        if !allTasks.isEmpty {
            // Tasks have estimates
            factors += 1
            let withEstimates = allTasks.filter { $0.estimate != nil }.count
            score += Double(withEstimates) / Double(allTasks.count)

            // Tasks have context
            factors += 1
            let withContext = allTasks.filter { $0.context != nil }.count
            score += Double(withContext) / Double(allTasks.count)

            // Tasks have next actions
            factors += 1
            let withActions = allTasks.filter { !$0.nextActions.isEmpty }.count
            score += Double(withActions) / Double(allTasks.count)
        }

        // Penalty for uncertainty flags
        factors += 1
        let flagPenalty = min(Double(uncertaintyFlags.count) * 0.15, 1.0)
        score += (1.0 - flagPenalty)

        return factors > 0 ? clamp(score / factors, min: 0.0, max: 1.0) : 0.0
    }

    // MARK: - Private

    /// Extract JSON from a response that might be wrapped in markdown code fences.
    private static func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to extract from ```json ... ``` or ``` ... ```
        if let jsonRange = extractCodeFenceContent(from: trimmed) {
            return String(trimmed[jsonRange])
        }

        // Find the first { and last } to extract the JSON object
        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}") {
            return String(trimmed[firstBrace...lastBrace])
        }

        return trimmed
    }

    private static func extractCodeFenceContent(from text: String) -> Range<String.Index>? {
        // Match ```json\n...\n``` or ```\n...\n```
        guard let fenceStart = text.range(of: "```") else { return nil }

        let afterFence = fenceStart.upperBound
        // Skip optional language identifier on the same line
        guard let newlineAfterFence = text[afterFence...].firstIndex(of: "\n") else { return nil }
        let contentStart = text.index(after: newlineAfterFence)

        // Find closing fence
        guard let closingFence = text.range(of: "```", range: contentStart..<text.endIndex) else {
            return nil
        }

        return contentStart..<closingFence.lowerBound
    }

    private static func parseMilestone(_ raw: RawMilestone) -> Milestone {
        Milestone(
            title: raw.title,
            deliverables: raw.deliverables.map { parseDeliverable($0) }
        )
    }

    private static func parseDeliverable(_ raw: RawDeliverable) -> Deliverable {
        Deliverable(
            title: raw.title,
            tasks: raw.tasks.map { parseTask($0) }
        )
    }

    private static func parseTask(_ raw: RawTask) -> PlanTask {
        PlanTask(
            title: raw.title,
            dueDate: raw.dueDate,
            deferDate: raw.deferDate,
            estimate: raw.estimate,
            context: raw.context,
            type: raw.type,
            isFlagged: raw.isFlagged ?? false,
            notes: raw.notes,
            nextActions: raw.nextActions?.map { parseNextAction($0) } ?? []
        )
    }

    private static func parseNextAction(_ raw: RawNextAction) -> NextAction {
        NextAction(
            title: raw.title,
            context: raw.context,
            estimate: raw.estimate,
            notes: raw.notes
        )
    }

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Raw Response Types (for JSON decoding)

private struct FullAIResponse: Codable {
    var description: String
    var milestones: [RawMilestone]
    var uncertaintyFlags: [String]
    var clarityScore: Double
}

private struct PlanOnlyResponse: Codable {
    var description: String
    var milestones: [RawMilestone]
}

private struct RawMilestone: Codable {
    var title: String
    var deliverables: [RawDeliverable]
}

private struct RawDeliverable: Codable {
    var title: String
    var tasks: [RawTask]
}

private struct RawTask: Codable {
    var title: String
    var dueDate: Date?
    var deferDate: Date?
    var estimate: String?
    var context: String?
    var type: String?
    var isFlagged: Bool?
    var notes: String?
    var nextActions: [RawNextAction]?
}

private struct RawNextAction: Codable {
    var title: String
    var context: String?
    var estimate: String?
    var notes: String?
}
