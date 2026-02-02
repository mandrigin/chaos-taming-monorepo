import Foundation

// MARK: - Analysis Service Protocol

/// Backend-agnostic analysis service. Implementations may call Gemini API,
/// Apple Foundation Models, or return mock data for testing.
protocol AnalysisService: Sendable {
    /// Analyze the given inputs with the active persona and produce a structured plan.
    func analyze(
        inputs: [InputItem],
        persona: Persona,
        projectName: String,
        onProgress: @Sendable (Double) -> Void
    ) async throws -> AnalysisResult
}

// MARK: - Analysis Errors

enum AnalysisError: LocalizedError {
    case noInputs
    case cancelled
    case serviceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .noInputs: return "No inputs to analyze. Add inputs before running analysis."
        case .cancelled: return "Analysis was cancelled."
        case .serviceUnavailable(let reason): return "Analysis service unavailable: \(reason)"
        }
    }
}

// MARK: - Prompt Builder

/// Constructs the analysis prompt from inputs, annotations, and persona.
enum AnalysisPromptBuilder {
    static func buildPrompt(inputs: [InputItem], persona: Persona, projectName: String) -> String {
        var prompt = """
        You are \(persona.name). \(persona.systemPrompt)

        Analyze the following project inputs and produce a structured project plan.

        Project: \(projectName)

        ## Inputs

        """

        for (index, input) in inputs.enumerated() {
            prompt += "### Input \(index + 1): \(input.type.rawValue)"
            if let filename = input.filename {
                prompt += " — \(filename)"
            }
            prompt += "\n"

            if let text = input.textContent {
                prompt += "Content: \(text)\n"
            } else if let path = input.assetPath {
                prompt += "[File: \(path)]\n"
            }
            if let extracted = input.extractedText {
                prompt += "Extracted content: \(extracted)\n"
            }

            if !input.annotations.isEmpty {
                prompt += "Annotations:\n"
                for annotation in input.annotations {
                    prompt += "  - \(annotation.text)\n"
                }
            }
            prompt += "\n"
        }

        prompt += """

        ## Output Requirements

        Produce a structured project plan with:
        1. A concise project description
        2. Milestones with deliverables, tasks, and GTD next-actions
        3. For each task: estimate, context, type, due/defer dates where appropriate
        4. A clarity score (0.0–1.0) reflecting how well-defined the project is
        5. Uncertainty flags — list anything ambiguous, missing, or risky

        Respond as structured JSON matching the AnalysisResult schema.
        """

        return prompt
    }
}

// MARK: - Mock Analysis Service

/// Returns realistic mock analysis results for UI development and testing.
/// Will be replaced by Gemini API / Foundation Models in Phase 4.
struct MockAnalysisService: AnalysisService {
    func analyze(
        inputs: [InputItem],
        persona: Persona,
        projectName: String,
        onProgress: @Sendable (Double) -> Void
    ) async throws -> AnalysisResult {
        guard !inputs.isEmpty else { throw AnalysisError.noInputs }

        // Simulate processing time with progress updates
        let steps = 8
        for step in 1...steps {
            try await Task.sleep(for: .milliseconds(200))
            try Task.checkCancellation()
            onProgress(Double(step) / Double(steps))
        }

        let plan = buildMockPlan(inputs: inputs, persona: persona, projectName: projectName)
        let uncertaintyFlags = buildUncertaintyFlags(inputs: inputs)
        let clarityScore = computeClarityScore(inputs: inputs)

        return AnalysisResult(
            plan: plan,
            clarityScore: clarityScore,
            uncertaintyFlags: uncertaintyFlags,
            version: 0 // Caller sets the actual version number
        )
    }

    private func buildMockPlan(inputs: [InputItem], persona: Persona, projectName: String) -> ProjectPlan {
        let inputSummary = inputs.map { input -> String in
            let name = input.filename ?? input.textContent?.prefix(40).description ?? input.type.rawValue
            let annotationCount = input.annotations.count
            return annotationCount > 0 ? "\(name) (+\(annotationCount) notes)" : name
        }.joined(separator: ", ")

        let description = "Project plan for \(projectName) based on \(inputs.count) input(s): \(inputSummary). Analyzed through \(persona.name) perspective."

        // Generate milestones based on input types present
        var milestones: [Milestone] = []

        milestones.append(Milestone(
            title: "Discovery & Requirements",
            deliverables: [
                Deliverable(title: "Input Analysis", tasks: [
                    PlanTask(
                        title: "Review and catalogue all \(inputs.count) inputs",
                        estimate: "1h",
                        context: "mac",
                        type: "research",
                        nextActions: [
                            NextAction(title: "Open each input and take notes", context: "mac", estimate: "30m"),
                            NextAction(title: "Identify cross-references between inputs", context: "mac", estimate: "30m"),
                        ]
                    ),
                    PlanTask(
                        title: "Consolidate requirements from annotations",
                        estimate: "45m",
                        context: "mac",
                        type: "research",
                        notes: "Review all \(inputs.flatMap(\.annotations).count) annotation(s) across inputs"
                    ),
                ]),
                Deliverable(title: "Gap Analysis", tasks: [
                    PlanTask(
                        title: "Identify missing information",
                        estimate: "30m",
                        context: "mac",
                        type: "research",
                        isFlagged: true,
                        notes: "Flag any ambiguities for interrogation mode"
                    ),
                ]),
            ]
        ))

        milestones.append(Milestone(
            title: "Planning & Design",
            deliverables: [
                Deliverable(title: "Architecture", tasks: [
                    PlanTask(
                        title: "Define project structure and milestones",
                        estimate: "2h",
                        context: "mac",
                        type: "design",
                        nextActions: [
                            NextAction(title: "Draft milestone breakdown", context: "mac", estimate: "1h"),
                            NextAction(title: "Review with stakeholders", context: "calls", estimate: "30m"),
                        ]
                    ),
                ]),
                Deliverable(title: "Resource Planning", tasks: [
                    PlanTask(
                        title: "Estimate resource requirements",
                        estimate: "1h",
                        context: "mac",
                        type: "coordination"
                    ),
                    PlanTask(
                        title: "Create timeline with dependencies",
                        estimate: "1h",
                        context: "mac",
                        type: "coordination",
                        nextActions: [
                            NextAction(title: "Map task dependencies", context: "mac", estimate: "30m"),
                            NextAction(title: "Set target dates", context: "mac", estimate: "30m"),
                        ]
                    ),
                ]),
            ]
        ))

        milestones.append(Milestone(
            title: "Execution",
            deliverables: [
                Deliverable(title: "Core Implementation", tasks: [
                    PlanTask(
                        title: "Execute primary deliverables",
                        estimate: "8h",
                        context: "mac",
                        type: "development",
                        isFlagged: true,
                        nextActions: [
                            NextAction(title: "Begin first deliverable", context: "mac", estimate: "4h"),
                            NextAction(title: "Checkpoint review", context: "calls", estimate: "30m"),
                        ]
                    ),
                ]),
                Deliverable(title: "Validation", tasks: [
                    PlanTask(
                        title: "Review outputs against requirements",
                        estimate: "2h",
                        context: "mac",
                        type: "research"
                    ),
                ]),
            ]
        ))

        return ProjectPlan(description: description, milestones: milestones)
    }

    private func buildUncertaintyFlags(inputs: [InputItem]) -> [String] {
        var flags: [String] = []

        let hasText = inputs.contains { $0.type == .text }
        let hasImages = inputs.contains { $0.type == .image || $0.type == .screenshot }
        let hasAnnotations = inputs.contains { !$0.annotations.isEmpty }

        if inputs.count < 3 {
            flags.append("Limited inputs — consider adding more context")
        }
        if !hasText && !hasAnnotations {
            flags.append("No text descriptions — project scope may be unclear")
        }
        if hasImages && !hasAnnotations {
            flags.append("Images lack annotations — unclear what aspects are relevant")
        }
        if !inputs.contains(where: { $0.type == .document }) {
            flags.append("No documents provided — requirements may be incomplete")
        }

        // Always include at least one flag
        if flags.isEmpty {
            flags.append("Timeline not specified — dates are estimated")
        }

        return flags
    }

    private func computeClarityScore(inputs: [InputItem]) -> Double {
        var score = 0.3 // Base score

        // More inputs = more clarity
        score += min(Double(inputs.count) * 0.08, 0.3)

        // Annotations boost clarity
        let totalAnnotations = inputs.flatMap(\.annotations).count
        score += min(Double(totalAnnotations) * 0.05, 0.2)

        // Text inputs provide direct context
        let textInputs = inputs.filter { $0.type == .text || $0.textContent != nil }
        score += min(Double(textInputs.count) * 0.06, 0.15)

        // Diverse input types = better coverage
        let uniqueTypes = Set(inputs.map(\.type))
        score += min(Double(uniqueTypes.count) * 0.03, 0.1)

        return min(score, 0.95) // Cap below 1.0
    }
}
