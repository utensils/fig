import SwiftUI

/// Explains what configuration files Fig accesses.
///
/// Since the app is non-sandboxed, filesystem access is not an issue.
/// This step is informational, helping users understand what files
/// Fig reads and writes.
struct OnboardingPermissionsView: View {
    // MARK: Internal

    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text("File Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Fig reads and writes Claude Code configuration files on your system.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            VStack(alignment: .leading, spacing: 16) {
                self.fileAccessRow(
                    path: "~/.claude.json",
                    description: "Global project registry and MCP servers"
                )
                self.fileAccessRow(
                    path: "~/.claude/settings.json",
                    description: "Global Claude Code settings"
                )
                self.fileAccessRow(
                    path: "<project>/.claude/settings.json",
                    description: "Per-project settings and local overrides"
                )
                self.fileAccessRow(
                    path: "<project>/.mcp.json",
                    description: "Per-project MCP server configuration"
                )
            }
            .padding(20)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Fig only accesses Claude Code configuration files.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Button("Back") {
                    self.viewModel.goBack()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    self.viewModel.advance()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(40)
    }

    // MARK: Private

    private func fileAccessRow(path: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(path)
                    .font(.system(.body, design: .monospaced))
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingPermissionsView(viewModel: OnboardingViewModel {})
}
