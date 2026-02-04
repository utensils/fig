import SwiftUI

/// The main entry point for the Fig application.
@main
struct FigApp: App {
    // MARK: Internal

    var body: some Scene {
        WindowGroup {
            if self.hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.hasCompletedOnboarding = true
                    }
                }
            }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
    }

    // MARK: Private

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
}
