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
@Observable
@MainActor
final class AnalysisCoordinator {
    private(set) var state: AnalysisState = .idle
    private var analysisTask: Task<Void, Never>?
    private let service: any AnalysisService

    init(service: any AnalysisService = MockAnalysisService()) {
        self.service = service
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
}
