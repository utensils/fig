import SwiftUI

/// The final onboarding screen shown before entering the main app.
///
/// Displays a summary of discovered projects and a button
/// to complete onboarding and launch the main app.
struct OnboardingCompletionView: View {
    // MARK: Internal

    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text("You\u{2019}re All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(self.summaryMessage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                self.viewModel.advance()
            } label: {
                Text("Open Fig")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
                .frame(height: 40)
        }
        .padding(40)
    }

    // MARK: Private

    private var summaryMessage: String {
        let count = self.viewModel.discoveredProjects.count
        if count == 0 {
            return "Fig is ready to use."
        }
        let noun = count == 1 ? "project" : "projects"
        return "Fig found \(count) \(noun) and is ready to use."
    }
}

#Preview {
    OnboardingCompletionView(viewModel: OnboardingViewModel {})
}
