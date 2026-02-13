@testable import Fig
import Testing

@Suite("ProjectGroup Tests")
struct ProjectGroupTests {
    @Test("id equals parentPath")
    func idEqualsParentPath() {
        let group = ProjectGroup(
            parentPath: "/Users/test/code",
            displayName: "~/code",
            projects: []
        )
        #expect(group.id == "/Users/test/code")
    }

    @Test("stores projects correctly")
    func storesProjects() {
        let projects = [
            ProjectEntry(path: "/code/alpha"),
            ProjectEntry(path: "/code/beta"),
        ]
        let group = ProjectGroup(
            parentPath: "/code",
            displayName: "/code",
            projects: projects
        )
        #expect(group.projects.count == 2)
        #expect(group.projects[0].path == "/code/alpha")
        #expect(group.projects[1].path == "/code/beta")
    }

    @Test("preserves displayName")
    func preservesDisplayName() {
        let group = ProjectGroup(
            parentPath: "/Users/alice/code",
            displayName: "~/code",
            projects: []
        )
        #expect(group.displayName == "~/code")
    }

    @Test("empty projects list is valid")
    func emptyProjectsList() {
        let group = ProjectGroup(
            parentPath: "/empty",
            displayName: "/empty",
            projects: []
        )
        #expect(group.projects.isEmpty)
    }
}
