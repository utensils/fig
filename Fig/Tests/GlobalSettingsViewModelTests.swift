@testable import Fig
import Foundation
import Testing

@Suite("GlobalSettingsViewModel Tests")
struct GlobalSettingsViewModelTests {
    @Test("Initial state is not loading")
    @MainActor
    func initialStateNotLoading() {
        let viewModel = GlobalSettingsViewModel()
        #expect(viewModel.isLoading == false)
    }

    @Test("Default tab is permissions")
    @MainActor
    func defaultTabIsPermissions() {
        let viewModel = GlobalSettingsViewModel()
        #expect(viewModel.selectedTab == .permissions)
    }

    @Test("Settings nil before load")
    @MainActor
    func settingsNilBeforeLoad() {
        let viewModel = GlobalSettingsViewModel()
        #expect(viewModel.settings == nil)
    }

    @Test("Legacy config nil before load")
    @MainActor
    func legacyConfigNilBeforeLoad() {
        let viewModel = GlobalSettingsViewModel()
        #expect(viewModel.legacyConfig == nil)
    }

    @Test("Global MCP servers empty before load")
    @MainActor
    func globalMCPServersEmptyBeforeLoad() {
        let viewModel = GlobalSettingsViewModel()
        #expect(viewModel.globalMCPServers.isEmpty)
    }

    @Test("Global settings path nil before load")
    @MainActor
    func globalSettingsPathNilBeforeLoad() {
        let viewModel = GlobalSettingsViewModel()
        #expect(viewModel.globalSettingsPath == nil)
    }

    @Test("File statuses nil before load")
    @MainActor
    func fileStatusesNilBeforeLoad() {
        let viewModel = GlobalSettingsViewModel()
        #expect(viewModel.settingsFileStatus == nil)
        #expect(viewModel.configFileStatus == nil)
    }

    @Test("All global settings tabs exist")
    func allTabsExist() {
        let tabs = GlobalSettingsTab.allCases
        #expect(tabs.count == 4)
        #expect(tabs.contains(.permissions))
        #expect(tabs.contains(.environment))
        #expect(tabs.contains(.mcpServers))
        #expect(tabs.contains(.advanced))
    }

    @Test("Tabs have titles and icons")
    func tabsHaveTitlesAndIcons() {
        for tab in GlobalSettingsTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(!tab.icon.isEmpty)
            #expect(tab.id == tab.rawValue)
        }
    }
}
