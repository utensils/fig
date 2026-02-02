import SwiftUI

// MARK: - MCPHealthCheckButton

/// Button that triggers and displays MCP server health check status.
struct MCPHealthCheckButton: View {
    // MARK: Internal

    let serverName: String
    let server: MCPServer

    var body: some View {
        Button {
            runHealthCheck()
        } label: {
            HStack(spacing: 4) {
                statusIcon
                Text("Test")
                    .font(.caption2)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isChecking)
        .help(helpText)
        .popover(isPresented: $showDetails) {
            HealthCheckResultPopover(result: result)
        }
    }

    // MARK: Private

    @State private var state: CheckState = .idle
    @State private var result: MCPHealthCheckResult?
    @State private var showDetails = false

    private enum CheckState {
        case idle
        case checking
        case completed
    }

    private var isChecking: Bool {
        state == .checking
    }

    private var helpText: String {
        switch state {
        case .idle:
            "Test server connection"
        case .checking:
            "Testing connection..."
        case .completed:
            if let result {
                result.isSuccess ? "Connection successful (click for details)" : "Connection failed (click for details)"
            } else {
                "Test complete"
            }
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "play.circle")
                .foregroundStyle(.secondary)
        case .checking:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 12, height: 12)
        case .completed:
            if let result {
                switch result.status {
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failure:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                case .timeout:
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func runHealthCheck() {
        if state == .completed, result != nil {
            // Show details if we already have a result
            showDetails = true
            return
        }

        state = .checking
        result = nil

        Task {
            let checkResult = await MCPHealthCheckService.shared.checkHealth(
                name: serverName,
                server: server
            )
            result = checkResult
            state = .completed

            // Show toast notification
            switch checkResult.status {
            case let .success(info):
                let name = info?.serverName ?? serverName
                NotificationManager.shared.showSuccess(
                    "Connected to \(name)",
                    message: String(format: "Response time: %.0fms", checkResult.duration * 1000)
                )
            case let .failure(error):
                NotificationManager.shared.showError(
                    "Connection failed",
                    message: error.localizedDescription
                )
            case .timeout:
                NotificationManager.shared.showWarning(
                    "Connection timed out",
                    message: "Server did not respond within 10 seconds"
                )
            }
        }
    }
}

// MARK: - HealthCheckResultPopover

/// Popover showing detailed health check results.
struct HealthCheckResultPopover: View {
    let result: MCPHealthCheckResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let result {
                // Status header
                HStack {
                    statusIcon(for: result)
                    VStack(alignment: .leading) {
                        Text(statusTitle(for: result))
                            .font(.headline)
                        Text(String(format: "%.0fms", result.duration * 1000))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Details
                switch result.status {
                case let .success(info):
                    if let info {
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = info.serverName {
                                HealthCheckDetailRow(label: "Server", value: name)
                            }
                            if let version = info.serverVersion {
                                HealthCheckDetailRow(label: "Version", value: version)
                            }
                            if let protocolVersion = info.protocolVersion {
                                HealthCheckDetailRow(label: "Protocol", value: protocolVersion)
                            }
                        }
                    } else {
                        Text("Server responded successfully")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case let .failure(error):
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.localizedDescription ?? "Unknown error")
                            .font(.caption)
                            .foregroundStyle(.red)

                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                case .timeout:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The server did not respond within 10 seconds.")
                            .font(.caption)
                        Text("The server may be slow, unresponsive, or not running.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No result available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 250, maxWidth: 350)
    }

    @ViewBuilder
    private func statusIcon(for result: MCPHealthCheckResult) -> some View {
        switch result.status {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundStyle(.red)
        case .timeout:
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title)
                .foregroundStyle(.orange)
        }
    }

    private func statusTitle(for result: MCPHealthCheckResult) -> String {
        switch result.status {
        case .success:
            "Connection Successful"
        case .failure:
            "Connection Failed"
        case .timeout:
            "Connection Timed Out"
        }
    }
}

// MARK: - HealthCheckDetailRow

/// A simple key-value row for displaying details.
private struct HealthCheckDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview("Idle") {
    MCPHealthCheckButton(
        serverName: "test-server",
        server: .stdio(command: "echo", args: ["hello"])
    )
    .padding()
}
