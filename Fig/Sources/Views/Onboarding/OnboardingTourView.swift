import SwiftUI

/// A multi-page feature tour highlighting key Fig capabilities.
///
/// Displays 4 feature pages with manual navigation and a skip option.
/// Uses custom paging instead of TabView(.page) which is iOS-only.
struct OnboardingTourView: View {
    // MARK: Internal

    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            self.tourPage(for: self.viewModel.currentTourPage)
                .id(self.viewModel.currentTourPage)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            self.pageIndicator

            Spacer()

            HStack {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if self.viewModel.currentTourPage > 0 {
                            self.viewModel.currentTourPage -= 1
                        } else {
                            self.viewModel.goBack()
                        }
                    }
                }
                .buttonStyle(.bordered)

                Button("Skip Tour") {
                    self.viewModel.skipTour()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.callout)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        let isLastPage = self.viewModel.currentTourPage
                            == OnboardingViewModel.tourPageCount - 1
                        if !isLastPage {
                            self.viewModel.currentTourPage += 1
                        } else {
                            self.viewModel.advance()
                        }
                    }
                } label: {
                    Text(self.isLastTourPage ? "Finish Tour" : "Next")
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(40)
        .animation(.easeInOut(duration: 0.25), value: self.viewModel.currentTourPage)
    }

    private var isLastTourPage: Bool {
        self.viewModel.currentTourPage == OnboardingViewModel.tourPageCount - 1
    }

    // MARK: Private

    private struct TourPageData {
        let icon: String
        let title: String
        let description: String
    }

    // swiftlint:disable line_length
    private static let pages: [TourPageData] = [
        TourPageData(
            icon: "sidebar.left",
            title: "Project Explorer",
            description: "Browse all your Claude Code projects in one place. See which projects have settings, MCP servers, and local configurations. Favorite projects for quick access."
        ),
        TourPageData(
            icon: "slider.horizontal.3",
            title: "Configuration Editor",
            description: "Edit permission rules, environment variables, hooks, and attribution settings with a visual editor. Changes are saved directly to your configuration files with automatic backups."
        ),
        TourPageData(
            icon: "server.rack",
            title: "MCP Server Management",
            description: "View, add, and configure MCP servers across projects. Copy server configurations between projects with a single click and check server health status."
        ),
        TourPageData(
            icon: "globe",
            title: "Global Settings",
            description: "Manage global Claude Code settings that apply across all your projects. Set default permissions, environment variables, and hooks in one place."
        )
    ]
    // swiftlint:enable line_length

    @ViewBuilder
    private func tourPage(for index: Int) -> some View {
        let page = Self.pages[index]
        VStack(spacing: 20) {
            Image(systemName: page.icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(page.description)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< OnboardingViewModel.tourPageCount, id: \.self) { index in
                Circle()
                    .fill(
                        index == self.viewModel.currentTourPage
                            ? Color.accentColor
                            : Color.secondary.opacity(0.3)
                    )
                    .frame(width: 8, height: 8)
            }
        }
    }
}

#Preview {
    OnboardingTourView(viewModel: OnboardingViewModel {})
}
