import Foundation

/// The main application view model responsible for app-wide state management.
@MainActor
@Observable
final class AppViewModel {
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    init() {}

    func clearError() {
        errorMessage = nil
    }
}
