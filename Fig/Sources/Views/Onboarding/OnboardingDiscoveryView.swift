import SwiftUI

/// Runs project discovery and displays found projects.
///
/// Automatically scans the filesystem for Claude Code projects
/// on appear and shows the results in a scrollable list.
struct OnboardingDiscoveryView: View {
    // MARK: Internal

    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            if self.viewModel.isDiscovering {
                self.discoveringContent
            } else if let error = self.viewModel.discoveryError {
                self.errorContent(error)
            } else if self.viewModel.discoveredProjects.isEmpty {
                self.emptyContent
            } else {
                self.resultsContent
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
        .task {
            if self.viewModel.discoveredProjects.isEmpty, !self.viewModel.isDiscovering {
                await self.viewModel.runDiscovery()
            }
        }
    }

    // MARK: Private

    private var projectCountMessage: String {
        let count = self.viewModel.discoveredProjects.count
        let noun = count == 1 ? "project" : "projects"
        return "Found \(count) Claude Code \(noun) on your system."
    }

    private var discoveringContent: some View {
        VStack(spacing: 16) {
            Text("Discovering Your Projects")
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView()
                .controlSize(.large)

            Text("Scanning for Claude Code projects\u{2026}")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 16) {
            Text("No Projects Found")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("No Claude Code projects were found on your system.")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("Projects will appear once you use Claude Code in a directory.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 450)
        }
    }

    private var resultsContent: some View {
        VStack(spacing: 16) {
            Text("Projects Found")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(self.projectCountMessage)
                .font(.title3)
                .foregroundStyle(.secondary)

            self.projectList
        }
    }

    private var projectList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(
                    Array(self.viewModel.discoveredProjects.prefix(15)),
                    id: \.id
                ) { project in
                    self.projectRow(project)
                }

                if self.viewModel.discoveredProjects.count > 15 {
                    Text(
                        "and \(self.viewModel.discoveredProjects.count - 15) more\u{2026}"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 250)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorContent(_ error: String) -> some View {
        VStack(spacing: 16) {
            Text("Discovery Issue")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Retry") {
                Task {
                    await self.viewModel.runDiscovery()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func projectRow(_ project: DiscoveredProject) -> some View {
        HStack(spacing: 12) {
            Image(systemName: project.exists ? "folder.fill" : "questionmark.folder")
                .foregroundStyle(project.exists ? Color.accentColor : .orange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                Text(self.abbreviatePath(project.path))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

#Preview {
    OnboardingDiscoveryView(viewModel: OnboardingViewModel {})
}
