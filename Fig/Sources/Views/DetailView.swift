import SwiftUI

/// The detail view displaying content for the selected sidebar item.
struct DetailView: View {
    let selectedItem: SidebarItem?

    var body: some View {
        Group {
            if let item = selectedItem {
                VStack(spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)

                    Text(item.title)
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    Text(item.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose an item from the sidebar to get started.")
                )
            }
        }
        .frame(minWidth: 400)
    }
}

#Preview {
    DetailView(selectedItem: .home)
}

#Preview("No Selection") {
    DetailView(selectedItem: nil)
}
