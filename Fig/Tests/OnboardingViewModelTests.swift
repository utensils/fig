@testable import Fig
import Testing

@Suite("OnboardingViewModel Tests")
struct OnboardingViewModelTests {
    // MARK: - Step Navigation

    @Suite("Step Navigation")
    struct StepNavigation {
        @Test("Starts on welcome step")
        @MainActor
        func startsOnWelcome() {
            let viewModel = OnboardingViewModel {}
            #expect(viewModel.currentStep == .welcome)
        }

        @Test("Advance moves to next step")
        @MainActor
        func advanceMovesToNextStep() {
            let viewModel = OnboardingViewModel {}
            viewModel.advance()
            #expect(viewModel.currentStep == .permissions)
            viewModel.advance()
            #expect(viewModel.currentStep == .discovery)
            viewModel.advance()
            #expect(viewModel.currentStep == .tour)
            viewModel.advance()
            #expect(viewModel.currentStep == .completion)
        }

        @Test("GoBack moves to previous step")
        @MainActor
        func goBackMovesToPreviousStep() {
            let viewModel = OnboardingViewModel {}
            viewModel.advance() // permissions
            viewModel.advance() // discovery
            viewModel.goBack()
            #expect(viewModel.currentStep == .permissions)
        }

        @Test("GoBack on welcome does nothing")
        @MainActor
        func goBackOnWelcomeDoesNothing() {
            let viewModel = OnboardingViewModel {}
            viewModel.goBack()
            #expect(viewModel.currentStep == .welcome)
        }

        @Test("Advance on completion calls onComplete")
        @MainActor
        func advanceOnCompletionCallsOnComplete() {
            var completed = false
            let viewModel = OnboardingViewModel { completed = true }
            // Navigate to completion
            viewModel.advance() // permissions
            viewModel.advance() // discovery
            viewModel.advance() // tour
            viewModel.advance() // completion
            #expect(!completed)
            viewModel.advance() // past completion
            #expect(completed)
        }
    }

    // MARK: - Skip Mechanism

    @Suite("Skip Mechanism")
    struct SkipMechanism {
        @Test("SkipToEnd calls onComplete immediately")
        @MainActor
        func skipToEndCallsOnComplete() {
            var completed = false
            let viewModel = OnboardingViewModel { completed = true }
            viewModel.skipToEnd()
            #expect(completed)
        }

        @Test("SkipTour jumps to completion step")
        @MainActor
        func skipTourJumpsToCompletion() {
            let viewModel = OnboardingViewModel {}
            viewModel.advance() // permissions
            viewModel.advance() // discovery
            viewModel.advance() // tour
            viewModel.skipTour()
            #expect(viewModel.currentStep == .completion)
        }
    }

    // MARK: - Progress

    @Suite("Progress")
    struct Progress {
        @Test("Progress is 0 on welcome")
        @MainActor
        func progressIsZeroOnWelcome() {
            let viewModel = OnboardingViewModel {}
            #expect(viewModel.progress == 0.0)
        }

        @Test("Progress is 1 on completion")
        @MainActor
        func progressIsOneOnCompletion() {
            let viewModel = OnboardingViewModel {}
            viewModel.advance() // permissions
            viewModel.advance() // discovery
            viewModel.advance() // tour
            viewModel.advance() // completion
            #expect(viewModel.progress == 1.0)
        }

        @Test("Progress increases with each step")
        @MainActor
        func progressIncreases() {
            let viewModel = OnboardingViewModel {}
            var lastProgress = viewModel.progress
            for _ in OnboardingViewModel.Step.allCases.dropFirst() {
                viewModel.advance()
                #expect(viewModel.progress > lastProgress)
                lastProgress = viewModel.progress
            }
        }
    }

    // MARK: - State Properties

    @Suite("State Properties")
    struct StateProperties {
        @Test("isFirstStep is true only on welcome")
        @MainActor
        func isFirstStepOnlyOnWelcome() {
            let viewModel = OnboardingViewModel {}
            #expect(viewModel.isFirstStep)
            viewModel.advance()
            #expect(!viewModel.isFirstStep)
        }

        @Test("isLastStep is true only on completion")
        @MainActor
        func isLastStepOnlyOnCompletion() {
            let viewModel = OnboardingViewModel {}
            #expect(!viewModel.isLastStep)
            viewModel.advance() // permissions
            viewModel.advance() // discovery
            viewModel.advance() // tour
            viewModel.advance() // completion
            #expect(viewModel.isLastStep)
        }

        @Test("Tour page starts at 0")
        @MainActor
        func tourPageStartsAtZero() {
            let viewModel = OnboardingViewModel {}
            #expect(viewModel.currentTourPage == 0)
        }

        @Test("Tour page count is 4")
        @MainActor
        func tourPageCountIsFour() {
            #expect(OnboardingViewModel.tourPageCount == 4)
        }
    }

    // MARK: - Discovery State

    @Suite("Discovery State")
    struct DiscoveryState {
        @Test("Starts with empty discovered projects")
        @MainActor
        func startsWithEmptyProjects() {
            let viewModel = OnboardingViewModel {}
            #expect(viewModel.discoveredProjects.isEmpty)
            #expect(!viewModel.isDiscovering)
            #expect(viewModel.discoveryError == nil)
        }
    }

    // MARK: - Step Enum

    @Suite("Step Enum")
    struct StepEnum {
        @Test("All cases have sequential raw values")
        @MainActor
        func allCasesSequential() {
            let cases = OnboardingViewModel.Step.allCases
            for (index, step) in cases.enumerated() {
                #expect(step.rawValue == index)
            }
        }

        @Test("Step count is 5")
        @MainActor
        func stepCountIsFive() {
            #expect(OnboardingViewModel.Step.allCases.count == 5)
        }
    }
}
