import SwiftUI

/// The main content view with NavigationSplitView layout.
struct ContentView: View {
    // MARK: Internal

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedItem: $selectedItem)
        } detail: {
            DetailView(selectedItem: selectedItem)
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: Private

    @State private var selectedItem: SidebarItem?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
}

#Preview {
    ContentView()
}
