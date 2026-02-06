@testable import Fig
import Foundation
import Testing

// MARK: - MCPPasteViewModelTests

@Suite("MCP Paste ViewModel Tests")
@MainActor
struct MCPPasteViewModelTests {
    @Test("Initial state is empty")
    func initialState() {
        let vm = MCPPasteViewModel()
        #expect(vm.jsonText.isEmpty)
        #expect(vm.parsedServers == nil)
        #expect(vm.parseError == nil)
        #expect(vm.serverCount == 0)
        #expect(vm.canImport == false)
        #expect(vm.importSucceeded == false)
    }

    @Test("canImport requires parsed servers and destination")
    func canImportRequirements() {
        let vm = MCPPasteViewModel(
            currentProject: .project(path: "/tmp", name: "test")
        )

        // No servers parsed yet
        #expect(vm.canImport == false)
    }

    @Test("loadDestinations populates available destinations")
    func loadDestinations() {
        let vm = MCPPasteViewModel()

        let projects = [
            ProjectEntry(path: "/path/to/project-a"),
            ProjectEntry(path: "/path/to/project-b"),
        ]

        vm.loadDestinations(projects: projects)

        // Should have global + 2 projects
        #expect(vm.availableDestinations.count == 3)
        #expect(vm.availableDestinations[0] == .global)
    }

    @Test("loadDestinations filters out projects without paths")
    func loadDestinationsFiltersInvalid() {
        let vm = MCPPasteViewModel()

        let projects = [
            ProjectEntry(path: "/path/to/valid"),
            ProjectEntry(path: nil),
        ]

        vm.loadDestinations(projects: projects)

        // Should have global + 1 valid project
        #expect(vm.availableDestinations.count == 2)
    }

    @Test("selectedDestination defaults to current project")
    func defaultDestination() {
        let project = CopyDestination.project(path: "/tmp", name: "test")
        let vm = MCPPasteViewModel(currentProject: project)

        #expect(vm.selectedDestination == project)
    }

    @Test("selectedDestination defaults to nil when no project")
    func defaultDestinationNil() {
        let vm = MCPPasteViewModel()
        #expect(vm.selectedDestination == nil)
    }

    @Test("serverNames returns sorted names")
    func serverNamesSorted() async throws {
        let vm = MCPPasteViewModel()
        vm.jsonText = """
        {
            "mcpServers": {
                "zebra": { "command": "z" },
                "alpha": { "command": "a" }
            }
        }
        """

        // Allow async parsing to complete
        try await Task.sleep(for: .milliseconds(100))

        #expect(vm.serverNames == ["alpha", "zebra"])
    }

    @Test("importSucceeded reflects result")
    func importSucceeded() {
        let vm = MCPPasteViewModel()
        #expect(vm.importSucceeded == false)
    }

    @Test("conflictStrategy defaults to rename")
    func conflictStrategyDefault() {
        let vm = MCPPasteViewModel()
        #expect(vm.conflictStrategy == .rename)
    }
}

