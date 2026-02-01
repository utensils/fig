import Foundation

/// Represents items displayed in the sidebar navigation.
enum SidebarItem: String, CaseIterable, Identifiable, Sendable {
    case home
    case projects
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .projects:
            return "Projects"
        case .settings:
            return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house"
        case .projects:
            return "folder"
        case .settings:
            return "gear"
        }
    }

    var description: String {
        switch self {
        case .home:
            return "Welcome to Cascade. This is your home screen where you can see an overview of your activity."
        case .projects:
            return "Manage and organize your projects. Create new projects or open existing ones."
        case .settings:
            return "Configure application settings and preferences."
        }
    }
}
