import Foundation

// MARK: - Analysis State

enum AnalysisState: Sendable {
    case idle
    case analyzing(progress: Double)
    case completed
    case error(String)

    var isAnalyzing: Bool {
        if case .analyzing = self { return true }
        return false
    }

    var progress: Double {
        if case .analyzing(let p) = self { return p }
        return 0
    }
}

// MARK: - Analysis Coordinator

/// Manages the analysis lifecycle: validates inputs, invokes the analysis service,
/// stores results with auto-versioning, and tracks progress.
///
/// Resolves the correct AI backend (Gemini / Foundation Models) based on
/// `AIBackend.current` and the document's project context. An override service
/// can be injected for testing.
@Observable
@MainActor
final class AnalysisCoordinator {
    private(set) var state: AnalysisState = .idle
    private var analysisTask: Task<Void, Never>?
    private let overrideService: (any AnalysisService)?

    init(service: (any AnalysisService)? = nil) {
        self.overrideService = service
    }

    /// Run analysis on the document's current inputs with the active persona.
    /// Auto-versions the result and stores it in the document.
    func runAnalysis(document: InputForgeDocument) {
        // Cancel any in-flight analysis
        analysisTask?.cancel()

        let inputs = document.projectData.inputs
        let persona = document.projectData.persona
        let projectName = document.projectData.name
        let nextVersion = (document.versions.map(\.versionNumber).max() ?? 0) + 1
        let service = overrideService ?? Self.resolveService(for: document.projectData.context)

        state = .analyzing(progress: 0)

        analysisTask = Task {
            do {
                let result = try await service.analyze(
                    inputs: inputs,
                    persona: persona,
                    projectName: projectName,
                    onProgress: { [weak self] progress in
                        Task { @MainActor in
                            guard let self, self.state.isAnalyzing else { return }
                            self.state = .analyzing(progress: progress)
                        }
                    }
                )

                guard !Task.isCancelled else {
                    state = .idle
                    return
                }

                // Stamp the version number and store
                let versionedResult = AnalysisResult(
                    plan: result.plan,
                    clarityScore: result.clarityScore,
                    uncertaintyFlags: result.uncertaintyFlags,
                    version: nextVersion
                )
                document.setAnalysisResult(versionedResult)
                state = .completed
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func cancel() {
        analysisTask?.cancel()
        analysisTask = nil
        state = .idle
    }

    func dismissError() {
        if case .error = state {
            state = .idle
        }
    }

    // MARK: - Backend Resolution

    private static func resolveService(for context: ProjectContext) -> any AnalysisService {
        let aiService: any AIService = switch AIBackend.current {
        case .gemini:
            GeminiAIService(context: context, model: GeminiModelSelection.selectedModelID(for: context))
        case .foundationModels:
            FoundationModelsAIService()
        }
        return LiveAnalysisService(aiService: aiService)
    }
}
