import Foundation
import OSLog

// MARK: - OnboardingViewModel

/// View model for the first-run onboarding experience.
///
/// Manages a step-based flow that introduces new users to Fig,
/// checks filesystem access, discovers existing Claude Code projects,
/// and provides a brief feature tour.
@MainActor
@Observable
final class OnboardingViewModel {
    // MARK: Lifecycle

    init(
        discoveryService: ProjectDiscoveryService = ProjectDiscoveryService(),
        onComplete: @escaping @MainActor () -> Void
    ) {
        self.discoveryService = discoveryService
        self.onComplete = onComplete
    }

    // MARK: Internal

    /// The steps in the onboarding flow.
    enum Step: Int, CaseIterable, Sendable {
        case welcome = 0
        case permissions = 1
        case discovery = 2
        case tour = 3
        case completion = 4
    }

    /// The current onboarding step.
    private(set) var currentStep: Step = .welcome

    /// Whether project discovery is in progress.
    private(set) var isDiscovering = false

    /// Projects found during discovery.
    private(set) var discoveredProjects: [DiscoveredProject] = []

    /// Error message from discovery, if any.
    private(set) var discoveryError: String?

    /// Current page index within the feature tour (0-based).
    var currentTourPage: Int = 0

    /// Total number of tour pages.
    static let tourPageCount = 4

    /// Whether the current step is the first step.
    var isFirstStep: Bool {
        self.currentStep == .welcome
    }

    /// Whether the current step is the last step.
    var isLastStep: Bool {
        self.currentStep == .completion
    }

    /// Progress fraction (0.0 to 1.0) for the progress indicator.
    var progress: Double {
        guard let maxRaw = Step.allCases.last?.rawValue, maxRaw > 0 else {
            return 0
        }
        return Double(self.currentStep.rawValue) / Double(maxRaw)
    }

    /// Advances to the next step, or completes onboarding if on the last step.
    func advance() {
        guard let next = Step(rawValue: self.currentStep.rawValue + 1) else {
            self.completeOnboarding()
            return
        }
        Log.ui.info("Onboarding advancing to step: \(next.rawValue)")
        self.currentStep = next
    }

    /// Goes back to the previous step.
    func goBack() {
        guard let previous = Step(rawValue: self.currentStep.rawValue - 1) else {
            return
        }
        self.currentStep = previous
    }

    /// Skips the entire onboarding flow and enters the main app.
    func skipToEnd() {
        Log.ui.info("Onboarding skipped entirely")
        self.completeOnboarding()
    }

    /// Skips only the feature tour, jumping to the completion screen.
    func skipTour() {
        Log.ui.info("Onboarding tour skipped")
        self.currentStep = .completion
    }

    /// Runs project discovery, scanning the filesystem for Claude Code projects.
    func runDiscovery() async {
        self.isDiscovering = true
        self.discoveryError = nil

        do {
            self.discoveredProjects = try await self.discoveryService.discoverProjects(
                scanDirectories: true
            )
            Log.ui.info("Onboarding discovered \(self.discoveredProjects.count) projects")
        } catch {
            self.discoveryError = error.localizedDescription
            Log.ui.error("Onboarding discovery failed: \(error.localizedDescription)")
        }

        self.isDiscovering = false
    }

    // MARK: Private

    private let discoveryService: ProjectDiscoveryService
    private let onComplete: @MainActor () -> Void

    private func completeOnboarding() {
        Log.ui.info("Onboarding completed")
        self.onComplete()
    }
}
