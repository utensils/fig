import SwiftUI

// MARK: - Focused Value Keys

/// Key for the navigation selection binding.
private struct NavigationSelectionKey: FocusedValueKey {
    typealias Value = Binding<NavigationSelection?>
}

/// Key for the project detail tab binding.
private struct ProjectDetailTabKey: FocusedValueKey {
    typealias Value = Binding<ProjectDetailTab>
}

/// Key for the global settings tab binding.
private struct GlobalSettingsTabKey: FocusedValueKey {
    typealias Value = Binding<GlobalSettingsTab>
}

/// Key for the add MCP server action.
private struct AddMCPServerActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

/// Key for the paste/import MCP servers action.
private struct PasteMCPServersActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

// MARK: - FocusedValues Extension

extension FocusedValues {
    /// Binding to the sidebar navigation selection.
    var navigationSelection: Binding<NavigationSelection?>? {
        get { self[NavigationSelectionKey.self] }
        set { self[NavigationSelectionKey.self] = newValue }
    }

    /// Binding to the project detail tab.
    var projectDetailTab: Binding<ProjectDetailTab>? {
        get { self[ProjectDetailTabKey.self] }
        set { self[ProjectDetailTabKey.self] = newValue }
    }

    /// Binding to the global settings tab.
    var globalSettingsTab: Binding<GlobalSettingsTab>? {
        get { self[GlobalSettingsTabKey.self] }
        set { self[GlobalSettingsTabKey.self] = newValue }
    }

    /// Action to add a new MCP server.
    var addMCPServerAction: (() -> Void)? {
        get { self[AddMCPServerActionKey.self] }
        set { self[AddMCPServerActionKey.self] = newValue }
    }

    /// Action to paste/import MCP servers from JSON.
    var pasteMCPServersAction: (() -> Void)? {
        get { self[PasteMCPServersActionKey.self] }
        set { self[PasteMCPServersActionKey.self] = newValue }
    }
}
