import Testing
@testable import Cascade

@Suite("SidebarItem Tests")
struct SidebarItemTests {
    @Test("All cases have non-empty titles")
    func allCasesHaveTitles() {
        for item in SidebarItem.allCases {
            #expect(!item.title.isEmpty)
        }
    }

    @Test("All cases have valid SF Symbol icons")
    func allCasesHaveIcons() {
        for item in SidebarItem.allCases {
            #expect(!item.icon.isEmpty)
        }
    }

    @Test("All cases have descriptions")
    func allCasesHaveDescriptions() {
        for item in SidebarItem.allCases {
            #expect(!item.description.isEmpty)
        }
    }

    @Test("ID matches raw value")
    func idMatchesRawValue() {
        for item in SidebarItem.allCases {
            #expect(item.id == item.rawValue)
        }
    }
}
