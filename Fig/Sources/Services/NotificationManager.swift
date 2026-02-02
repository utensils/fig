import Foundation
import OSLog
import SwiftUI

// MARK: - AppNotification

/// A notification to display to the user.
struct AppNotification: Identifiable, Sendable {
    // MARK: Lifecycle

    init(
        id: UUID = UUID(),
        type: NotificationType,
        title: String,
        message: String? = nil,
        dismissAfter: TimeInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.dismissAfter = dismissAfter
    }

    // MARK: Internal

    /// Notification severity levels.
    enum NotificationType: Sendable {
        case success
        case info
        case warning
        case error

        // MARK: Internal

        var icon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: .green
            case .info: .blue
            case .warning: .orange
            case .error: .red
            }
        }
    }

    let id: UUID
    let type: NotificationType
    let title: String
    let message: String?
    let dismissAfter: TimeInterval?
}

// MARK: - NotificationManager

/// Manages application notifications and alerts.
///
/// Use this manager to display toast notifications and alerts to the user.
/// All UI updates are performed on the main actor.
@MainActor
@Observable
final class NotificationManager {
    // MARK: Lifecycle

    private init() {}

    // MARK: Internal

    // MARK: - Alerts

    /// Information for displaying an alert dialog.
    struct AlertInfo: Identifiable {
        struct AlertButton {
            // MARK: Lifecycle

            init(
                title: String,
                role: ButtonRole? = nil,
                action: (@Sendable () -> Void)? = nil
            ) {
                self.title = title
                self.role = role
                self.action = action
            }

            // MARK: Internal

            let title: String
            let role: ButtonRole?
            let action: (@Sendable () -> Void)?

            static func ok(action: (@Sendable () -> Void)? = nil) -> AlertButton {
                AlertButton(title: "OK", action: action)
            }

            static func cancel(action: (@Sendable () -> Void)? = nil) -> AlertButton {
                AlertButton(title: "Cancel", role: .cancel, action: action)
            }

            static func destructive(_ title: String, action: (@Sendable () -> Void)? = nil) -> AlertButton {
                AlertButton(title: title, role: .destructive, action: action)
            }
        }

        let id = UUID()
        let title: String
        let message: String?
        let primaryButton: AlertButton
        let secondaryButton: AlertButton?
    }

    /// Shared instance for app-wide notification management.
    static let shared = NotificationManager()

    /// Currently displayed toast notifications.
    private(set) var toasts: [AppNotification] = []

    /// Currently displayed alert, if any.
    private(set) var currentAlert: AlertInfo?

    // MARK: - Toast Notifications

    /// Shows a success toast notification.
    func showSuccess(_ title: String, message: String? = nil) {
        self.showToast(type: .success, title: title, message: message, dismissAfter: 3.0)
    }

    /// Shows an info toast notification.
    func showInfo(_ title: String, message: String? = nil) {
        self.showToast(type: .info, title: title, message: message, dismissAfter: 4.0)
    }

    /// Shows a warning toast notification.
    func showWarning(_ title: String, message: String? = nil) {
        self.showToast(type: .warning, title: title, message: message, dismissAfter: 5.0)
    }

    /// Shows an error toast notification.
    func showError(_ title: String, message: String? = nil) {
        self.showToast(type: .error, title: title, message: message, dismissAfter: 6.0)
    }

    /// Shows an error from a FigError.
    func showError(_ error: FigError) {
        Log.general.error("Error: \(error.localizedDescription)")
        self.showToast(
            type: .error,
            title: error.localizedDescription,
            message: error.recoverySuggestion,
            dismissAfter: 6.0
        )
    }

    /// Shows an error from any Error type.
    func showError(_ error: Error) {
        if let figError = error as? FigError {
            self.showError(figError)
        } else if let configError = error as? ConfigFileError {
            self.showError(FigError(from: configError))
        } else {
            Log.general.error("Error: \(error.localizedDescription)")
            self.showToast(
                type: .error,
                title: "Error",
                message: error.localizedDescription,
                dismissAfter: 6.0
            )
        }
    }

    /// Dismisses a specific toast notification.
    func dismissToast(id: UUID) {
        self.dismissTimers[id]?.cancel()
        self.dismissTimers.removeValue(forKey: id)

        withAnimation(.easeInOut(duration: 0.2)) {
            self.toasts.removeAll { $0.id == id }
        }
    }

    /// Dismisses all toast notifications.
    func dismissAllToasts() {
        for timer in self.dismissTimers.values {
            timer.cancel()
        }
        self.dismissTimers.removeAll()

        withAnimation(.easeInOut(duration: 0.2)) {
            self.toasts.removeAll()
        }
    }

    /// Shows an alert dialog.
    func showAlert(
        title: String,
        message: String? = nil,
        primaryButton: AlertInfo.AlertButton = .ok(),
        secondaryButton: AlertInfo.AlertButton? = nil
    ) {
        Log.general.info("Alert shown: \(title)")
        self.currentAlert = AlertInfo(
            title: title,
            message: message,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton
        )
    }

    /// Shows an error alert dialog.
    func showErrorAlert(_ error: FigError) {
        Log.general.error("Error alert: \(error.localizedDescription)")
        self.showAlert(
            title: "Error",
            message: [error.localizedDescription, error.recoverySuggestion]
                .compactMap(\.self)
                .joined(separator: "\n\n")
        )
    }

    /// Shows an error alert for any Error type.
    func showErrorAlert(_ error: Error) {
        if let figError = error as? FigError {
            self.showErrorAlert(figError)
        } else if let configError = error as? ConfigFileError {
            self.showErrorAlert(FigError(from: configError))
        } else {
            Log.general.error("Error alert: \(error.localizedDescription)")
            self.showAlert(title: "Error", message: error.localizedDescription)
        }
    }

    /// Shows a confirmation alert.
    func showConfirmation(
        title: String,
        message: String? = nil,
        confirmTitle: String = "Confirm",
        confirmRole: ButtonRole? = nil,
        onConfirm: @escaping @Sendable () -> Void,
        onCancel: (@Sendable () -> Void)? = nil
    ) {
        self.showAlert(
            title: title,
            message: message,
            primaryButton: AlertInfo.AlertButton(title: confirmTitle, role: confirmRole, action: onConfirm),
            secondaryButton: .cancel(action: onCancel)
        )
    }

    /// Dismisses the current alert.
    func dismissAlert() {
        self.currentAlert = nil
    }

    // MARK: Private

    /// Auto-dismiss timers for toasts.
    private var dismissTimers: [UUID: Task<Void, Never>] = [:]

    /// Shows a toast notification.
    private func showToast(
        type: AppNotification.NotificationType,
        title: String,
        message: String?,
        dismissAfter: TimeInterval?
    ) {
        let notification = AppNotification(
            type: type,
            title: title,
            message: message,
            dismissAfter: dismissAfter
        )

        // Log based on type
        switch type {
        case .success:
            Log.general.info("Success: \(title)")
        case .info:
            Log.general.info("Info: \(title)")
        case .warning:
            Log.general.warning("Warning: \(title)")
        case .error:
            Log.general.error("Error: \(title)")
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            self.toasts.append(notification)
        }

        // Set up auto-dismiss if specified
        if let dismissAfter {
            let id = notification.id
            self.dismissTimers[id] = Task {
                try? await Task.sleep(for: .seconds(dismissAfter))
                if !Task.isCancelled {
                    self.dismissToast(id: id)
                }
            }
        }
    }
}
