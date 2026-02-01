import SwiftUI

/// The sidebar view displaying navigation items.
struct SidebarView: View {
    @Binding var selectedItem: SidebarItem?

    var body: some View {
        List(selection: $selectedItem) {
            Section("Navigation") {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.icon)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Cascade")
        .frame(minWidth: 200)
    }
}

#Preview {
    SidebarView(selectedItem: .constant(.home))
}
