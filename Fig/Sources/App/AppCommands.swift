import SwiftUI

/// App-level menu commands with keyboard shortcuts.
struct AppCommands: Commands {
    // MARK: Internal

    var body: some Commands {
        // Replace Preferences menu item with Global Settings navigation
        CommandGroup(replacing: .appSettings) {
            Button("Global Settings...") {
                self.selection = .globalSettings
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        // File menu: New MCP Server
        CommandGroup(after: .newItem) {
            Button("New MCP Server") {
                self.addMCPServer?()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(self.addMCPServer == nil)
        }

        // Tab menu for switching detail tabs
        CommandMenu("Tab") {
            if self.projectTab != nil {
                ForEach(Array(ProjectDetailTab.allCases.prefix(9).enumerated()), id: \.element) { index, tab in
                    Button(tab.title) {
                        self.projectTab = tab
                    }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")),
                        modifiers: .command
                    )
                }
            } else if self.globalTab != nil {
                ForEach(Array(GlobalSettingsTab.allCases.prefix(9).enumerated()), id: \.element) { index, tab in
                    Button(tab.title) {
                        self.globalTab = tab
                    }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")),
                        modifiers: .command
                    )
                }
            } else {
                Text("No tabs available")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Private

    @FocusedBinding(\.navigationSelection) private var selection
    @FocusedBinding(\.projectDetailTab) private var projectTab
    @FocusedBinding(\.globalSettingsTab) private var globalTab
    @FocusedValue(\.addMCPServerAction) private var addMCPServer
}
