import SwiftUI

// MARK: - ConfigHealthCheckView

/// View for displaying project config health check results.
struct ConfigHealthCheckView: View {
    // MARK: Internal

    @Bindable var viewModel: ProjectDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary header
                HealthCheckHeaderView(
                    healthVM: healthCheckVM,
                    onRunChecks: { Task { await runChecks() } }
                )

                if healthCheckVM.isRunning {
                    ProgressView("Running health checks...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if healthCheckVM.findings.isEmpty, healthCheckVM.lastRunDate != nil {
                    ContentUnavailableView(
                        "No Findings",
                        systemImage: "checkmark.seal.fill",
                        description: Text("Your project configuration looks good!")
                    )
                } else {
                    // Findings grouped by severity
                    ForEach(healthCheckVM.groupedFindings, id: \.severity) { group in
                        FindingSectionView(
                            severity: group.severity,
                            findings: group.findings,
                            onAutoFix: { finding in
                                Task { await executeAutoFix(finding) }
                            }
                        )
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await runChecks()
        }
    }

    // MARK: Private

    @State private var healthCheckVM = ConfigHealthCheckViewState()

    private func runChecks() async {
        let vm = ConfigHealthCheckViewModel(projectPath: viewModel.projectURL)
        await vm.runChecks(
            globalSettings: viewModel.globalSettings,
            projectSettings: viewModel.projectSettings,
            projectLocalSettings: viewModel.projectLocalSettings,
            mcpConfig: viewModel.mcpConfig,
            legacyConfig: viewModel.legacyConfig,
            localSettingsExists: viewModel.projectLocalSettingsStatus?.exists ?? false,
            mcpConfigExists: viewModel.mcpConfigStatus?.exists ?? false
        )
        healthCheckVM.findings = vm.findings
        healthCheckVM.lastRunDate = vm.lastRunDate
        healthCheckVM.isRunning = false
    }

    private func executeAutoFix(_ finding: Finding) async {
        let vm = ConfigHealthCheckViewModel(projectPath: viewModel.projectURL)
        await vm.executeAutoFix(
            finding,
            globalSettings: viewModel.globalSettings,
            projectSettings: viewModel.projectSettings,
            projectLocalSettings: viewModel.projectLocalSettings,
            mcpConfig: viewModel.mcpConfig,
            legacyConfig: viewModel.legacyConfig,
            localSettingsExists: viewModel.projectLocalSettingsStatus?.exists ?? false,
            mcpConfigExists: viewModel.mcpConfigStatus?.exists ?? false
        )
        healthCheckVM.findings = vm.findings
        healthCheckVM.lastRunDate = vm.lastRunDate

        // Reload project config to reflect changes
        await viewModel.loadConfiguration()
    }
}

// MARK: - ConfigHealthCheckViewState

/// Local state for the health check view.
@Observable
final class ConfigHealthCheckViewState {
    var findings: [Finding] = []
    var isRunning = false
    var lastRunDate: Date?

    var severityCounts: [Severity: Int] {
        Dictionary(grouping: findings, by: \.severity)
            .mapValues(\.count)
    }

    var groupedFindings: [(severity: Severity, findings: [Finding])] {
        let grouped = Dictionary(grouping: findings, by: \.severity)
        return Severity.allCases.compactMap { severity in
            guard let items = grouped[severity], !items.isEmpty else {
                return nil
            }
            return (severity, items)
        }
    }
}

// MARK: - HealthCheckHeaderView

/// Summary header showing check status and severity counts.
struct HealthCheckHeaderView: View {
    let healthVM: ConfigHealthCheckViewState
    let onRunChecks: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Configuration Health")
                    .font(.headline)

                if let lastRun = healthVM.lastRunDate {
                    Text("Last checked: \(lastRun, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Severity count badges
            if !healthVM.findings.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Severity.allCases, id: \.self) { severity in
                        if let count = healthVM.severityCounts[severity], count > 0 {
                            SeverityCountBadge(severity: severity, count: count)
                        }
                    }
                }
            }

            Button {
                onRunChecks()
            } label: {
                Label("Re-check", systemImage: "arrow.clockwise")
            }
            .disabled(healthVM.isRunning)
        }
    }
}

// MARK: - SeverityCountBadge

/// Small badge showing the count for a severity level.
struct SeverityCountBadge: View {
    let severity: Severity
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: severity.icon)
                .font(.caption2)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(severity.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(severity.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - FindingSectionView

/// Section showing findings for a single severity level.
struct FindingSectionView: View {
    let severity: Severity
    let findings: [Finding]
    let onAutoFix: (Finding) -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(findings.enumerated()), id: \.element.id) { index, finding in
                    if index > 0 {
                        Divider()
                    }
                    FindingRowView(finding: finding, onAutoFix: onAutoFix)
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: severity.icon)
                    .foregroundStyle(severity.color)
                Text(severity.label)
                    .fontWeight(.medium)
                Text("(\(findings.count))")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - FindingRowView

/// A single finding row with title, description, and optional auto-fix button.
struct FindingRowView: View {
    let finding: Finding
    let onAutoFix: (Finding) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: finding.severity.icon)
                .foregroundStyle(finding.severity.color)
                .font(.body)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(finding.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if let autoFix = finding.autoFix {
                Button {
                    onAutoFix(finding)
                } label: {
                    Label(autoFix.label, systemImage: "wand.and.stars")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
