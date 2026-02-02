import SwiftUI

/// The main content view with NavigationSplitView layout.
struct ContentView: View {
    // MARK: Internal

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selection, viewModel: viewModel)
        } detail: {
            DetailView(selection: selection)
        }
        .navigationSplitViewStyle(.balanced)
        .onKeyPress(keys: [KeyEquivalent("k")], phases: .down) { press in
            guard press.modifiers.contains(.command) else {
                return .ignored
            }
            viewModel.isQuickSwitcherPresented = true
            return .handled
        }
        .sheet(isPresented: $viewModel.isQuickSwitcherPresented) {
            QuickSwitcherView(viewModel: viewModel, selection: $selection)
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
