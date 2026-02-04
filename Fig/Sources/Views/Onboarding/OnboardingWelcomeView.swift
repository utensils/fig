import SwiftUI

/// The welcome screen shown as the first onboarding step.
///
/// Introduces the user to Fig and provides options to
/// start the setup flow or skip it entirely.
struct OnboardingWelcomeView: View {
    // MARK: Internal

    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "gearshape.2")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text("Welcome to Fig")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("A visual configuration manager for Claude Code")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                self.featureRow(
                    icon: "folder",
                    text: "Browse and manage all your Claude Code projects"
                )
                self.featureRow(
                    icon: "slider.horizontal.3",
                    text: "Edit permissions, environment variables, and hooks"
                )
                self.featureRow(
                    icon: "server.rack",
                    text: "Configure MCP servers across projects"
                )
            }
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    self.viewModel.advance()
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip Setup") {
                    self.viewModel.skipToEnd()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.callout)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(40)
    }

    // MARK: Private

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    OnboardingWelcomeView(viewModel: OnboardingViewModel {})
}
