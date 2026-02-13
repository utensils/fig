import AppKit
import SwiftUI

// MARK: - AppDelegate

/// App delegate to configure the application before UI loads.
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    func applicationDidFinishLaunching(_: Notification) {
        // Ensure the app activates and shows its window when running from Xcode/SPM
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - FigApp

/// The main entry point for the Fig application.
@main
struct FigApp: App {
    // MARK: Internal

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
        .commands {
            AppCommands()
        }
    }

    // MARK: Private

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
}
