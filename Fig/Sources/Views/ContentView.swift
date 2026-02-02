import SwiftUI

/// The main content view with NavigationSplitView layout.
struct ContentView: View {
    // MARK: Internal

    var body: some View {
        NavigationSplitView(columnVisibility: self.$columnVisibility) {
            SidebarView(selection: self.$selection, viewModel: self.viewModel)
        } detail: {
            DetailView(selection: self.selection)
        }
        .navigationSplitViewStyle(.balanced)
        .onKeyPress(keys: [KeyEquivalent("k")], phases: .down) { press in
            guard press.modifiers.contains(.command) else {
                return .ignored
            }
            self.viewModel.isQuickSwitcherPresented = true
            return .handled
        }
        .sheet(isPresented: self.$viewModel.isQuickSwitcherPresented) {
            QuickSwitcherView(viewModel: self.viewModel, selection: self.$selection)
        }
    }

    // MARK: Private

    @State private var selection: NavigationSelection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var viewModel = ProjectExplorerViewModel()
}

#Preview {
    ContentView()
}
