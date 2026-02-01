import SwiftUI

/// The main entry point for the Fig application.
@main
struct FigApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
    }
}
