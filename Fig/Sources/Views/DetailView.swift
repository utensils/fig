import SwiftUI

/// The detail view displaying content for the selected sidebar item.
struct DetailView: View {
    let selection: NavigationSelection?

    var body: some View {
        Group {
            switch self.selection {
            case .globalSettings:
                GlobalSettingsDetailView()
            case let .project(path):
                ProjectDetailView(projectPath: path)
                    .id(path)
            case nil:
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose an item from the sidebar to get started.")
                )
            }
        }
        .frame(minWidth: 500)
    }
}

#Preview("Global Settings") {
    DetailView(selection: .globalSettings)
        .frame(width: 700, height: 500)
}

#Preview("Project") {
    DetailView(selection: .project("/Users/test/project"))
        .frame(width: 700, height: 500)
}

#Preview("No Selection") {
    DetailView(selection: nil)
        .frame(width: 700, height: 500)
}
