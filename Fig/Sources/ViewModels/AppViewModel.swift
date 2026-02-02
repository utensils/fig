import Foundation

/// The main application view model responsible for app-wide state management.
@MainActor
@Observable
final class AppViewModel {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    func clearError() {
        errorMessage = nil
    }
}
