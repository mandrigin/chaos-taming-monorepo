import Foundation
import SwiftUI

/// Orchestrates the interrogation chat session: sends messages to AI,
/// updates clarity score, generates running summary, and handles re-analysis.
@Observable
@MainActor
final class InterrogationViewModel {
    private let document: InputForgeDocument
    private let aiService: any AIService

    var userInput: String = ""
    var isSending: Bool = false
    var isReanalyzing: Bool = false
    var error: String?

    var messages: [InterrogationMessage] {
        document.projectData.interrogation?.messages ?? []
    }

    var summary: String {
        document.projectData.interrogation?.summary ?? ""
    }

    var clarityScore: Double {
        document.projectData.currentAnalysis?.clarityScore ?? 0
    }

    var uncertaintyFlags: [String] {
        document.projectData.currentAnalysis?.uncertaintyFlags ?? []
    }

    var personaName: String {
        document.projectData.persona.name
    }

    var canSend: Bool {
        !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    /// Returns asset data for a given input ID, used by the view to display inline images.
    func imageData(forInputId inputId: UUID) -> Data? {
        guard let input = document.projectData.inputs.first(where: { $0.id == inputId }) else { return nil }
        return document.assetData(for: input)
    }

    init(document: InputForgeDocument, aiService: (any AIService)? = nil) {
        self.document = document
        self.aiService = aiService ?? Self.resolveAIService(for: document.projectData.context)

        // Initialize interrogation state if needed
        if document.projectData.interrogation == nil {
            document.projectData.interrogation = InterrogationState()
            document.projectData.modifiedAt = .now
        }
    }

    // MARK: - Actions

    func sendMessage() async {
        let text = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        userInput = ""
        error = nil
        isSending = true

        // Append user message
        let userMsg = InterrogationMessage(role: .user, content: text)
        document.projectData.interrogation?.messages.append(userMsg)
        document.projectData.modifiedAt = .now

        do {
            let imageDataProvider: ((InputItem) -> (Data, String)?)? = { [weak self] input in
                guard let self, let data = self.document.assetData(for: input) else { return nil }
                let mimeType = Self.mimeType(for: input.filename)
                return (data, mimeType)
            }

            let aiMessages = PromptBuilder.buildChatMessages(
                persona: document.projectData.persona,
                history: messages.dropLast().map { $0 }, // history before the new user msg
                newUserMessage: text,
                inputs: document.projectData.inputs,
                currentAnalysis: document.projectData.currentAnalysis,
                imageDataProvider: imageDataProvider
            )

            let response = try await aiService.chat(messages: aiMessages)

            // Detect image references in the AI response
            let imageRefs = detectImageReferences(in: response)

            let assistantMsg = InterrogationMessage(role: .assistant, content: response, imageReferences: imageRefs)
            document.projectData.interrogation?.messages.append(assistantMsg)

            // Update running summary from conversation
            updateSummary()

            // Update clarity score based on conversation progress
            updateClarityFromConversation()

            document.projectData.modifiedAt = .now
        } catch is CancellationError {
            // No error display on cancellation
        } catch {
            self.error = error.localizedDescription
        }

        isSending = false
    }

    func doneRefining() async {
        guard !isReanalyzing else { return }
        isReanalyzing = true
        error = nil

        do {
            let nextVersion = (document.projectData.currentAnalysis?.version ?? 0) + 1

            let analysisMessages = PromptBuilder.buildAnalysisMessages(
                persona: document.projectData.persona,
                inputs: document.projectData.inputs,
                projectName: document.projectData.name,
                version: nextVersion
            )

            // Append interrogation context to the analysis
            var enrichedMessages = analysisMessages
            if let interrogation = document.projectData.interrogation, !interrogation.messages.isEmpty {
                let conversationSummary = interrogation.messages.map { msg in
                    "\(msg.role == .user ? "User" : "Assistant"): \(msg.content)"
                }.joined(separator: "\n")

                enrichedMessages.append(.user("""
                Additional context from interrogation session:
                \(conversationSummary)

                Please incorporate these clarifications into the revised plan.
                """))
            }

            let response = try await aiService.analyze(messages: enrichedMessages)
            let result = try AIResponseParser.parseAnalysisResponse(response, version: nextVersion)
            document.setAnalysisResult(result)
        } catch is CancellationError {
            // Silent
        } catch {
            self.error = error.localizedDescription
        }

        isReanalyzing = false
    }

    // MARK: - Backend Resolution

    private static func resolveAIService(for context: ProjectContext) -> any AIService {
        switch AIBackend.current {
        case .gemini:
            return GeminiAIService(context: context, model: GeminiModel.current(for: context).apiName)
        case .foundationModels:
            return FoundationModelsAIService()
        }
    }

    // MARK: - Image Reference Detection

    private func detectImageReferences(in response: String) -> [ImageReference] {
        let lowered = response.lowercased()
        var refs: [ImageReference] = []
        var seen = Set<UUID>()

        for input in document.projectData.inputs {
            guard input.type == .image || input.type == .screenshot else { continue }
            guard let filename = input.filename else { continue }

            // Check if the AI response mentions this input's filename
            if lowered.contains(filename.lowercased()) && !seen.contains(input.id) {
                seen.insert(input.id)
                refs.append(ImageReference(
                    inputId: input.id,
                    filename: filename,
                    mimeType: Self.mimeType(for: filename)
                ))
            }
        }
        return refs
    }

    private static func mimeType(for filename: String?) -> String {
        let ext = filename?.split(separator: ".").last?.lowercased() ?? ""
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "heic": return "image/heic"
        case "webp": return "image/webp"
        case "tiff", "tif": return "image/tiff"
        default: return "image/png"
        }
    }

    // MARK: - Private

    private func updateSummary() {
        guard let interrogation = document.projectData.interrogation else { return }

        // Build a rolling summary from the last few exchanges
        let recentMessages = interrogation.messages.suffix(6)
        let keyPoints = recentMessages.compactMap { msg -> String? in
            guard msg.role == .assistant else { return nil }
            // Take first sentence of each assistant response as a summary point
            let firstSentence = msg.content.prefix(while: { $0 != "." && $0 != "\n" })
            return firstSentence.isEmpty ? nil : String(firstSentence)
        }

        if !keyPoints.isEmpty {
            document.projectData.interrogation?.summary = keyPoints.joined(separator: ". ") + "."
        }
    }

    private func updateClarityFromConversation() {
        guard var analysis = document.projectData.currentAnalysis else { return }

        // Each Q&A exchange incrementally improves clarity (diminishing returns)
        let messageCount = Double(messages.count) / 2.0 // pairs
        let clarityBoost = min(messageCount * 0.03, 0.15) // max 15% boost from conversation
        let newScore = min(analysis.clarityScore + clarityBoost, 1.0)

        // Remove uncertainty flags that may have been addressed
        // (simple heuristic: if a flag keyword appears in any assistant response)
        let assistantResponses = messages
            .filter { $0.role == .assistant }
            .map { $0.content.lowercased() }
            .joined(separator: " ")

        let remainingFlags = analysis.uncertaintyFlags.filter { flag in
            let keywords = flag.lowercased().split(separator: " ")
            let addressed = keywords.allSatisfy { assistantResponses.contains($0) }
            return !addressed
        }

        analysis.clarityScore = newScore
        analysis.uncertaintyFlags = remainingFlags
        document.projectData.currentAnalysis = analysis
        document.projectData.modifiedAt = .now
    }
}
