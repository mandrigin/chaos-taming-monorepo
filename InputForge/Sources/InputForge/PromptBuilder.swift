import Foundation

/// Builds AI prompts with persona injection and structured output instructions.
struct PromptBuilder: Sendable {
    /// Build messages for an analysis request.
    ///
    /// Constructs a message array with:
    /// 1. System message: persona prompt + output format instructions
    /// 2. User message: input descriptions and content
    ///
    /// - Parameters:
    ///   - persona: The active persona whose system prompt is prepended.
    ///   - inputs: The project inputs to analyze.
    ///   - projectName: The project name for context.
    ///   - version: The version number for this analysis pass.
    /// - Returns: An array of AIMessage for the AI service.
    static func buildAnalysisMessages(
        persona: Persona,
        inputs: [InputItem],
        projectName: String,
        version: Int
    ) -> [AIMessage] {
        let systemPrompt = buildSystemPrompt(persona: persona)
        let userContent = buildAnalysisUserContent(inputs: inputs, projectName: projectName, version: version)

        return [
            .system(systemPrompt),
            .user(userContent),
        ]
    }

    /// Build messages for the AI's opening interrogation turn (no user message yet).
    ///
    /// The AI analyzes inputs and uncertainty flags, then asks the first targeted question.
    ///
    /// - Parameters:
    ///   - persona: The active persona.
    ///   - inputs: The project inputs for context.
    ///   - currentAnalysis: The current analysis result, if any.
    ///   - imageDataProvider: Optional closure returning image data + mime type for an input.
    /// - Returns: An array of AIMessage for the AI service.
    static func buildInterrogationStartMessages(
        persona: Persona,
        inputs: [InputItem],
        currentAnalysis: AnalysisResult?,
        imageDataProvider: ((InputItem) -> (Data, String)?)? = nil
    ) -> [AIMessage] {
        var messages: [AIMessage] = []

        let systemPrompt = buildChatSystemPrompt(
            persona: persona,
            inputs: inputs,
            currentAnalysis: currentAnalysis
        )
        messages.append(.system(systemPrompt))

        // Trigger message with input images so the AI can see them
        var parts: [AIContentPart] = [.text("Begin interrogation. Review my inputs and analysis, then ask your first question.")]
        if let imageDataProvider {
            for input in inputs where input.type == .image || input.type == .screenshot {
                if let (data, mimeType) = imageDataProvider(input) {
                    parts.append(.imageData(data, mimeType: mimeType))
                }
            }
        }
        messages.append(.user(parts))

        return messages
    }

    /// Build messages for an interrogation chat turn (user answered, AI asks next question).
    ///
    /// - Parameters:
    ///   - persona: The active persona.
    ///   - history: The existing interrogation messages.
    ///   - newUserMessage: The user's answer to the AI's question.
    ///   - inputs: The project inputs for context.
    ///   - currentAnalysis: The current analysis result, if any.
    /// - Returns: An array of AIMessage for the AI service.
    static func buildChatMessages(
        persona: Persona,
        history: [InterrogationMessage],
        newUserMessage: String,
        inputs: [InputItem],
        currentAnalysis: AnalysisResult?,
        imageDataProvider: ((InputItem) -> (Data, String)?)? = nil
    ) -> [AIMessage] {
        var messages: [AIMessage] = []

        let systemPrompt = buildChatSystemPrompt(
            persona: persona,
            inputs: inputs,
            currentAnalysis: currentAnalysis
        )
        messages.append(.system(systemPrompt))

        // Add conversation history
        for msg in history {
            switch msg.role {
            case .user:
                messages.append(.user(msg.content))
            case .assistant:
                messages.append(.assistant(msg.content))
            }
        }

        messages.append(.user(newUserMessage))

        return messages
    }

    /// Build multi-modal user content parts for analysis, including image data.
    ///
    /// - Parameters:
    ///   - inputs: The project inputs.
    ///   - imageDataProvider: Closure that returns image data for a given input item.
    ///   - projectName: The project name.
    ///   - version: The analysis version number.
    /// - Returns: An array of AIContentPart for multi-modal input.
    static func buildMultiModalAnalysisContent(
        inputs: [InputItem],
        imageDataProvider: (InputItem) -> (Data, String)?,
        projectName: String,
        version: Int
    ) -> [AIContentPart] {
        var parts: [AIContentPart] = []

        let textDescription = buildInputDescriptions(inputs: inputs)
        parts.append(.text("""
        Project: \(projectName)
        Analysis Version: \(version)

        Inputs:
        \(textDescription)

        Analyze all inputs and produce a structured project plan as JSON.
        """))

        // Add image data for image-type inputs
        for input in inputs where input.type == .image || input.type == .screenshot {
            if let (data, mimeType) = imageDataProvider(input) {
                parts.append(.imageData(data, mimeType: mimeType))
            }
        }

        return parts
    }

    // MARK: - Private Helpers

    private static let basePrompt = """
        You are a project planning assistant. Analyze inputs and create structured, \
        actionable project plans. Be thorough, practical, and precise.
        """

    private static func buildSystemPrompt(persona: Persona) -> String {
        var prompt = basePrompt
        if !persona.isNeutral {
            prompt += "\n\n\(persona.systemPrompt)"
        }

        return """
        \(prompt)

        You are analyzing project inputs to produce a structured plan. \
        Your response MUST be valid JSON matching the following schema exactly.

        ## Output JSON Schema

        {
          "description": "A high-level summary of the project plan",
          "milestones": [
            {
              "title": "Milestone title",
              "deliverables": [
                {
                  "title": "Deliverable title",
                  "tasks": [
                    {
                      "title": "Task title",
                      "dueDate": "2025-01-15T00:00:00Z or null",
                      "deferDate": "2025-01-01T00:00:00Z or null",
                      "estimate": "2h or null",
                      "context": "@office or null",
                      "type": "development or null",
                      "isFlagged": false,
                      "notes": "Additional notes or null",
                      "nextActions": [
                        {
                          "title": "Next action title",
                          "context": "@mac or null",
                          "estimate": "30m or null",
                          "notes": "Notes or null"
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ],
          "uncertaintyFlags": ["List of areas where information is unclear or missing"],
          "clarityScore": 0.75
        }

        ## Rules
        - Output ONLY the JSON object, no markdown fencing, no explanation
        - clarityScore: 0.0 (no clarity) to 1.0 (completely clear)
        - uncertaintyFlags: list specific gaps, ambiguities, or missing information
        - All dates must be ISO 8601 format
        - Use null (not empty string) for absent optional fields
        """
    }

    private static func buildChatSystemPrompt(
        persona: Persona,
        inputs: [InputItem],
        currentAnalysis: AnalysisResult?
    ) -> String {
        var personaBlock = basePrompt
        if !persona.isNeutral {
            personaBlock += "\n\n\(persona.systemPrompt)"
        }

        var prompt = """
        \(personaBlock)

        You are in INTERROGATION mode. You are the interrogator — YOU ask the questions, \
        the user answers. Your job is to identify gaps, ambiguities, and missing information \
        in the project plan, then ask targeted questions to resolve them one at a time.

        ## Rules
        - Ask ONE focused question per turn (do not ask multiple questions at once)
        - Base your questions on the uncertainty flags, missing details, and ambiguities \
        you identify in the inputs and current analysis
        - When the user answers, acknowledge briefly, then ask the next question
        - Reference specific inputs by filename when relevant
        - Keep questions concrete and actionable (e.g. "What is the deadline for milestone 2?" \
        not "Tell me more about the timeline")
        - If all major uncertainties are resolved, tell the user they can click Done Refining
        """

        if !inputs.isEmpty {
            prompt += "\n\nProject inputs:\n\(buildInputDescriptions(inputs: inputs))"
        }

        if let analysis = currentAnalysis {
            prompt += "\n\nCurrent clarity score: \(String(format: "%.0f%%", analysis.clarityScore * 100))"
            if !analysis.uncertaintyFlags.isEmpty {
                prompt += "\nOpen uncertainties to resolve:\n"
                for (i, flag) in analysis.uncertaintyFlags.enumerated() {
                    prompt += "  \(i + 1). \(flag)\n"
                }
            }
        }

        return prompt
    }

    private static func buildAnalysisUserContent(
        inputs: [InputItem],
        projectName: String,
        version: Int
    ) -> String {
        let descriptions = buildInputDescriptions(inputs: inputs)
        return """
        Project: \(projectName)
        Analysis Version: \(version)

        Inputs:
        \(descriptions)

        Analyze all inputs and produce a structured project plan as JSON.
        """
    }

    private static func buildInputDescriptions(inputs: [InputItem]) -> String {
        if inputs.isEmpty {
            return "(no inputs provided)"
        }

        return inputs.enumerated().map { index, input in
            var desc = "\(index + 1). [\(input.type.rawValue)]"
            if let filename = input.filename {
                desc += " \(filename)"
            }
            if let text = input.textContent {
                let truncated = text.prefix(2000)
                desc += "\n   Content: \(truncated)"
                if text.count > 2000 {
                    desc += "... (truncated)"
                }
            }
            if let extracted = input.extractedText {
                let truncated = extracted.prefix(2000)
                desc += "\n   Extracted content: \(truncated)"
                if extracted.count > 2000 {
                    desc += "... (truncated)"
                }
            }
            if !input.annotations.isEmpty {
                let notes = input.annotations.map { "   - \($0.text)" }.joined(separator: "\n")
                desc += "\n   Annotations:\n\(notes)"
            }
            return desc
        }.joined(separator: "\n")
    }
}
