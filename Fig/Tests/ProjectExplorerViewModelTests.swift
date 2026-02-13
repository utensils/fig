@testable import Fig
import Foundation
import Testing

// MARK: - ProjectExplorerViewModelTests

@Suite("ProjectExplorerViewModel Tests")
@MainActor
struct ProjectExplorerViewModelTests {
    // MARK: - Grouping

    @Suite("Grouping by Parent Directory")
    @MainActor
    struct GroupingTests {
        @Test("isGroupedByParent defaults to false")
        func defaultsToFalse() {
            let vm = ProjectExplorerViewModel()
            #expect(vm.isGroupedByParent == false)
        }

        @Test("groupedProjects groups by parent directory")
        func groupsByParent() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/Users/test/code/project-a"),
                ProjectEntry(path: "/Users/test/code/project-b"),
                ProjectEntry(path: "/Users/test/repos/other"),
            ]

            let groups = vm.groupedProjects
            #expect(groups.count == 2)

            let codeGroup = groups.first { $0.parentPath == "/Users/test/code" }
            #expect(codeGroup != nil)
            #expect(codeGroup?.projects.count == 2)

            let reposGroup = groups.first { $0.parentPath == "/Users/test/repos" }
            #expect(reposGroup != nil)
            #expect(reposGroup?.projects.count == 1)
        }

        @Test("groupedProjects are sorted by parent path")
        func groupsSortedByPath() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/z/project"),
                ProjectEntry(path: "/a/project"),
            ]

            let groups = vm.groupedProjects
            #expect(groups.count == 2)
            #expect(groups.first?.parentPath == "/a")
            #expect(groups.last?.parentPath == "/z")
        }

        @Test("projects within group sorted by name")
        func projectsSortedWithinGroup() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/code/zebra"),
                ProjectEntry(path: "/code/alpha"),
                ProjectEntry(path: "/code/middle"),
            ]

            let groups = vm.groupedProjects
            #expect(groups.count == 1)
            #expect(groups.first?.projects.count == 3)
            #expect(groups.first?.projects[0].name == "alpha")
            #expect(groups.first?.projects[1].name == "middle")
            #expect(groups.first?.projects[2].name == "zebra")
        }

        @Test("groupedProjects respects search filter")
        func respectsSearchFilter() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/code/alpha"),
                ProjectEntry(path: "/code/beta"),
            ]
            vm.searchQuery = "alpha"

            let groups = vm.groupedProjects
            #expect(groups.count == 1)
            #expect(groups.first?.projects.count == 1)
            #expect(groups.first?.projects.first?.name == "alpha")
        }

        @Test("groupedProjects returns empty when no projects")
        func emptyWhenNoProjects() {
            let vm = ProjectExplorerViewModel()
            #expect(vm.groupedProjects.isEmpty)
        }

        @Test("projects without path go into Unknown group")
        func nilPathGroup() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: nil),
            ]

            let groups = vm.groupedProjects
            #expect(groups.count == 1)
            #expect(groups.first?.parentPath == "Unknown")
        }

        @Test("multiple parent directories create separate groups")
        func multipleParents() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/workspace/fig/doha"),
                ProjectEntry(path: "/workspace/fig/almaty"),
                ProjectEntry(path: "/workspace/fig/cebu"),
                ProjectEntry(path: "/workspace/other/project"),
                ProjectEntry(path: "/home/personal"),
            ]

            let groups = vm.groupedProjects
            #expect(groups.count == 3)

            let figGroup = groups.first { $0.parentPath == "/workspace/fig" }
            #expect(figGroup?.projects.count == 3)

            let otherGroup = groups.first { $0.parentPath == "/workspace/other" }
            #expect(otherGroup?.projects.count == 1)

            let homeGroup = groups.first { $0.parentPath == "/home" }
            #expect(homeGroup?.projects.count == 1)
        }

        @Test("search that eliminates all projects from a group hides that group")
        func searchHidesEmptyGroups() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/code/alpha"),
                ProjectEntry(path: "/repos/beta"),
            ]
            vm.searchQuery = "alpha"

            let groups = vm.groupedProjects
            #expect(groups.count == 1)
            #expect(groups.first?.parentPath == "/code")
        }

        @Test("group displayName abbreviates home directory")
        func displayNameAbbreviation() {
            let vm = ProjectExplorerViewModel()
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            vm.projects = [
                ProjectEntry(path: "\(home)/code/project"),
            ]

            let groups = vm.groupedProjects
            #expect(groups.first?.displayName == "~/code")
        }
    }

    // MARK: - Missing Projects

    @Suite("Missing Projects")
    @MainActor
    struct MissingProjectsTests {
        @Test("missingProjects returns projects with non-existent paths")
        func identifiesMissing() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/nonexistent/path/12345"),
                ProjectEntry(path: "/tmp"),
            ]

            let missing = vm.missingProjects
            #expect(missing.count == 1)
            #expect(missing.first?.path == "/nonexistent/path/12345")
        }

        @Test("hasMissingProjects is true when missing exist")
        func hasMissingTrue() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/nonexistent/path/12345"),
            ]
            #expect(vm.hasMissingProjects == true)
        }

        @Test("hasMissingProjects is false when all exist")
        func hasMissingFalse() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/tmp"),
            ]
            #expect(vm.hasMissingProjects == false)
        }

        @Test("hasMissingProjects is false when empty")
        func hasMissingEmpty() {
            let vm = ProjectExplorerViewModel()
            #expect(vm.hasMissingProjects == false)
        }

        @Test("missingProjects includes nil-path projects")
        func nilPathIsMissing() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: nil),
            ]

            #expect(vm.missingProjects.count == 1)
        }

        @Test("missingProjects with mix of existing and non-existing")
        func mixedExistence() {
            let vm = ProjectExplorerViewModel()
            vm.projects = [
                ProjectEntry(path: "/tmp"),
                ProjectEntry(path: "/nonexistent/a"),
                ProjectEntry(path: "/nonexistent/b"),
                ProjectEntry(path: "/tmp"),
            ]

            #expect(vm.missingProjects.count == 2)
            #expect(vm.hasMissingProjects == true)
        }
    }

    // MARK: - Favorites Interaction

    @Suite("Favorites and Recents")
    @MainActor
    struct FavoritesTests {
        @Test("toggleFavorite adds and removes")
        func toggleFavorite() {
            let vm = ProjectExplorerViewModel()
            let id = UUID().uuidString
            let project = ProjectEntry(path: "/test/toggle-\(id)")

            vm.toggleFavorite(project)
            #expect(vm.isFavorite(project))

            vm.toggleFavorite(project)
            #expect(!vm.isFavorite(project))
        }

        @Test("favoriteProjects excludes projects not in favorites")
        func favoriteProjectsFiltering() {
            let vm = ProjectExplorerViewModel()
            let id = UUID().uuidString
            let fav = ProjectEntry(path: "/test/fav-filter-\(id)")
            let regular = ProjectEntry(path: "/test/reg-filter-\(id)")
            vm.projects = [fav, regular]
            vm.toggleFavorite(fav)

            #expect(vm.favoriteProjects.count == 1)
            #expect(vm.favoriteProjects.first?.path == fav.path)
        }

        @Test("filteredProjects excludes favorites and recents")
        func filteredExcludesFavorites() {
            let vm = ProjectExplorerViewModel()
            let id = UUID().uuidString
            let fav = ProjectEntry(path: "/test/fav-excl-\(id)")
            let regular = ProjectEntry(path: "/test/reg-excl-\(id)")
            vm.projects = [fav, regular]
            vm.toggleFavorite(fav)

            #expect(vm.filteredProjects.count == 1)
            #expect(vm.filteredProjects.first?.path == regular.path)
        }
    }

    // MARK: - Grouped Projects and Favorites Interaction

    @Suite("Grouping with Favorites")
    @MainActor
    struct GroupingWithFavoritesTests {
        @Test("groupedProjects excludes favorites")
        func excludesFavorites() {
            let vm = ProjectExplorerViewModel()
            let id = UUID().uuidString
            let fav = ProjectEntry(path: "/code/fav-grp-\(id)")
            let regular = ProjectEntry(path: "/code/reg-grp-\(id)")
            vm.projects = [fav, regular]
            vm.toggleFavorite(fav)

            let groups = vm.groupedProjects
            #expect(groups.count == 1)
            #expect(groups.first?.projects.count == 1)
            #expect(groups.first?.projects.first?.path == regular.path)
        }
    }
}
