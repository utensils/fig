import Foundation

/// Represents items displayed in the sidebar navigation.
enum SidebarItem: String, CaseIterable, Identifiable, Sendable {
    case home
    case projects
    case settings

    // MARK: Internal

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .projects:
            "Projects"
        case .settings:
            "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home:
            "house"
        case .projects:
            "folder"
        case .settings:
            "gear"
        }
    }

    var description: String {
        switch self {
        case .home:
            "Welcome to Fig. This is your home screen where you can see an overview of your activity."
        case .projects:
            "Manage and organize your projects. Create new projects or open existing ones."
        case .settings:
            "Configure application settings and preferences."
        }
    }
}
