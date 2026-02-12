@testable import Fig
import Foundation
import Testing

@Suite("ProjectDetailViewModel Tests")
struct ProjectDetailViewModelTests {
    @Test("Initializes with correct project path")
    @MainActor
    func initializesWithPath() {
        let viewModel = ProjectDetailViewModel(projectPath: "/Users/test/project-a")
        #expect(viewModel.projectPath == "/Users/test/project-a")
        #expect(viewModel.projectName == "project-a")
    }

    @Test("Different paths produce distinct view models")
    @MainActor
    func differentPathsProduceDistinctViewModels() {
        let viewModelA = ProjectDetailViewModel(projectPath: "/Users/test/project-a")
        let viewModelB = ProjectDetailViewModel(projectPath: "/Users/test/project-b")

        #expect(viewModelA.projectPath != viewModelB.projectPath)
        #expect(viewModelA.projectName == "project-a")
        #expect(viewModelB.projectName == "project-b")
        #expect(viewModelA.projectURL != viewModelB.projectURL)
    }

    @Test("Project URL matches path")
    @MainActor
    func projectURLMatchesPath() {
        let path = "/Users/test/my-project"
        let viewModel = ProjectDetailViewModel(projectPath: path)
        #expect(viewModel.projectURL == URL(fileURLWithPath: path))
    }

    @Test("Default tab is permissions")
    @MainActor
    func defaultTabIsPermissions() {
        let viewModel = ProjectDetailViewModel(projectPath: "/Users/test/project")
        #expect(viewModel.selectedTab == .permissions)
    }

    @Test("Initial state is not loading")
    @MainActor
    func initialStateNotLoading() {
        let viewModel = ProjectDetailViewModel(projectPath: "/Users/test/project")
        #expect(viewModel.isLoading == false)
    }

    @Test("Project name derived from last path component")
    @MainActor
    func projectNameFromPath() {
        let viewModel = ProjectDetailViewModel(projectPath: "/a/b/c/my-app")
        #expect(viewModel.projectName == "my-app")
    }

    @Test("All permissions empty initially")
    @MainActor
    func allPermissionsEmptyInitially() {
        let viewModel = ProjectDetailViewModel(projectPath: "/Users/test/project")
        #expect(viewModel.allPermissions.isEmpty)
    }

    @Test("All MCP servers empty initially")
    @MainActor
    func allMCPServersEmptyInitially() {
        let viewModel = ProjectDetailViewModel(projectPath: "/Users/test/project")
        #expect(viewModel.allMCPServers.isEmpty)
    }

    @Test("All environment variables empty initially")
    @MainActor
    func allEnvVarsEmptyInitially() {
        let viewModel = ProjectDetailViewModel(projectPath: "/Users/test/project")
        #expect(viewModel.allEnvironmentVariables.isEmpty)
    }

    @Test("All disallowed tools empty initially")
    @MainActor
    func allDisallowedToolsEmptyInitially() {
        let viewModel = ProjectDetailViewModel(projectPath: "/Users/test/project")
        #expect(viewModel.allDisallowedTools.isEmpty)
    }

    @Test("Attribution settings nil initially")
    @MainActor
    func attributionSettingsNilInitially() {
        let viewModel = ProjectDetailViewModel(projectPath: "/Users/test/project")
        #expect(viewModel.attributionSettings == nil)
    }

    @Test("Merged settings nil initially")
    @MainActor
    func mergedSettingsNilInitially() {
        let viewModel = ProjectDetailViewModel(projectPath: "/Users/test/project")
        #expect(viewModel.mergedSettings == nil)
    }
}
