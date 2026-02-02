import SwiftUI

// MARK: - ToastView

/// A toast notification view.
struct ToastView: View {
    let notification: AppNotification
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: self.notification.type.icon)
                .foregroundStyle(self.notification.type.color)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.notification.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let message = notification.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                self.onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .frame(maxWidth: 400)
    }
}

// MARK: - ToastContainerView

/// Container view for displaying toast notifications.
struct ToastContainerView: View {
    @Bindable var notificationManager: NotificationManager

    var body: some View {
        VStack(spacing: 8) {
            ForEach(self.notificationManager.toasts) { toast in
                ToastView(notification: toast) {
                    self.notificationManager.dismissToast(id: toast.id)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .animation(.spring(duration: 0.3), value: self.notificationManager.toasts.map(\.id))
    }
}

// MARK: - ToastModifier

/// View modifier to add toast notifications to a view.
struct ToastModifier: ViewModifier {
    @Bindable var notificationManager: NotificationManager

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                ToastContainerView(notificationManager: self.notificationManager)
            }
    }
}

extension View {
    /// Adds toast notification support to the view.
    func withToasts(_ notificationManager: NotificationManager) -> some View {
        modifier(ToastModifier(notificationManager: notificationManager))
    }
}

// MARK: - AlertModifier

/// View modifier to add alert support.
struct AlertModifier: ViewModifier {
    @Bindable var notificationManager: NotificationManager

    func body(content: Content) -> some View {
        content
            .alert(
                self.notificationManager.currentAlert?.title ?? "",
                isPresented: .init(
                    get: { self.notificationManager.currentAlert != nil },
                    set: { if !$0 {
                        self.notificationManager.dismissAlert()
                    } }
                ),
                presenting: self.notificationManager.currentAlert
            ) { alertInfo in
                Button(alertInfo.primaryButton.title, role: alertInfo.primaryButton.role) {
                    alertInfo.primaryButton.action?()
                    self.notificationManager.dismissAlert()
                }
                if let secondary = alertInfo.secondaryButton {
                    Button(secondary.title, role: secondary.role) {
                        secondary.action?()
                        self.notificationManager.dismissAlert()
                    }
                }
            } message: { alertInfo in
                if let message = alertInfo.message {
                    Text(message)
                }
            }
    }
}

extension View {
    /// Adds alert support to the view.
    func withAlerts(_ notificationManager: NotificationManager) -> some View {
        modifier(AlertModifier(notificationManager: notificationManager))
    }

    /// Adds both toast and alert support to the view.
    func withNotifications(_ notificationManager: NotificationManager) -> some View {
        self.withToasts(notificationManager)
            .withAlerts(notificationManager)
    }
}

#Preview("Toast Types") {
    VStack(spacing: 20) {
        ToastView(
            notification: AppNotification(
                type: .success,
                title: "Configuration saved",
                message: "Your changes have been saved successfully."
            )
        ) {}

        ToastView(
            notification: AppNotification(
                type: .info,
                title: "New version available",
                message: "Version 2.0 is now available for download."
            )
        ) {}

        ToastView(
            notification: AppNotification(
                type: .warning,
                title: "File modified externally",
                message: "The configuration file was changed outside of Fig."
            )
        ) {}

        ToastView(
            notification: AppNotification(
                type: .error,
                title: "Failed to save",
                message: "Check file permissions and try again."
            )
        ) {}
    }
    .padding()
    .frame(width: 450, height: 400)
}
