import SwiftUI

/// The top-level onboarding container that routes between steps.
///
/// Displays a progress indicator and the current step's view,
/// with animated transitions between steps.
struct OnboardingView: View {
    // MARK: Lifecycle

    init(onComplete: @escaping @MainActor () -> Void) {
        self._viewModel = State(
            initialValue: OnboardingViewModel(onComplete: onComplete)
        )
    }

    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            self.progressDots
                .padding(.top, 24)
                .padding(.bottom, 8)

            Group {
                switch self.viewModel.currentStep {
                case .welcome:
                    OnboardingWelcomeView(viewModel: self.viewModel)
                case .permissions:
                    OnboardingPermissionsView(viewModel: self.viewModel)
                case .discovery:
                    OnboardingDiscoveryView(viewModel: self.viewModel)
                case .tour:
                    OnboardingTourView(viewModel: self.viewModel)
                case .completion:
                    OnboardingCompletionView(viewModel: self.viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 500)
        .animation(.easeInOut(duration: 0.3), value: self.viewModel.currentStep)
    }

    // MARK: Private

    @State private var viewModel: OnboardingViewModel

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingViewModel.Step.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(
                        step.rawValue <= self.viewModel.currentStep.rawValue
                            ? Color.accentColor
                            : Color.secondary.opacity(0.3)
                    )
                    .frame(width: 8, height: 8)
            }
        }
    }
}

#Preview {
    OnboardingView {}
}
