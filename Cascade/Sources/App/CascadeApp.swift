import SwiftUI

/// The main entry point for the Cascade application.
@main
struct CascadeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
    }
}
