import SwiftUI

// MARK: - ConfigHealthCheckView

/// View for displaying project config health check results.
struct ConfigHealthCheckView: View {
    // MARK: Lifecycle

    init(viewModel: ProjectDetailViewModel) {
        self.viewModel = viewModel
        self._healthCheckVM = State(
            initialValue: ConfigHealthCheckViewModel(projectPath: viewModel.projectURL)
        )
    }

    // MARK: Internal

    @Bindable var viewModel: ProjectDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary header
                HealthCheckHeaderView(
                    healthVM: self.healthCheckVM,
                    onRunChecks: { Task { await self.runChecks() } }
                )

                if self.healthCheckVM.isRunning {
                    ProgressView("Running health checks...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if self.healthCheckVM.findings.isEmpty, self.healthCheckVM.lastRunDate != nil {
                    ContentUnavailableView(
                        "No Findings",
                        systemImage: "checkmark.seal.fill",
                        description: Text("Your project configuration looks good!")
                    )
                } else {
                    // Findings grouped by severity
                    ForEach(self.healthCheckVM.groupedFindings, id: \.severity) { group in
                        FindingSectionView(
                            severity: group.severity,
                            findings: group.findings,
                            onAutoFix: { finding in
                                Task { await self.executeAutoFix(finding) }
                            }
                        )
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await self.runChecks()
        }
    }

    // MARK: Private

    @State private var healthCheckVM: ConfigHealthCheckViewModel

    private func runChecks() async {
        await self.healthCheckVM.runChecks(
            globalSettings: self.viewModel.globalSettings,
            projectSettings: self.viewModel.projectSettings,
            projectLocalSettings: self.viewModel.projectLocalSettings,
            mcpConfig: self.viewModel.mcpConfig,
            legacyConfig: self.viewModel.legacyConfig,
            localSettingsExists: self.viewModel.projectLocalSettingsStatus?.exists ?? false,
            mcpConfigExists: self.viewModel.mcpConfigStatus?.exists ?? false
        )
    }

    private func executeAutoFix(_ finding: Finding) async {
        await self.healthCheckVM.executeAutoFix(
            finding,
            legacyConfig: self.viewModel.legacyConfig
        )

        // Reload project config to reflect changes
        await self.viewModel.loadConfiguration()
    }
}

// MARK: - HealthCheckHeaderView

/// Summary header showing check status and severity counts.
struct HealthCheckHeaderView: View {
    let healthVM: ConfigHealthCheckViewModel
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
            if !self.healthVM.findings.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Severity.allCases, id: \.self) { severity in
                        if let count = healthVM.severityCounts[severity], count > 0 {
                            SeverityCountBadge(severity: severity, count: count)
                        }
                    }
                }
            }

            Button {
                self.onRunChecks()
            } label: {
                Label("Re-check", systemImage: "arrow.clockwise")
            }
            .disabled(self.healthVM.isRunning)
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
            Image(systemName: self.severity.icon)
                .font(.caption2)
            Text("\(self.count)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(self.severity.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(self.severity.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
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
                ForEach(Array(self.findings.enumerated()), id: \.element.id) { index, finding in
                    if index > 0 {
                        Divider()
                    }
                    FindingRowView(finding: finding, onAutoFix: self.onAutoFix)
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: self.severity.icon)
                    .foregroundStyle(self.severity.color)
                Text(self.severity.label)
                    .fontWeight(.medium)
                Text("(\(self.findings.count))")
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
            Image(systemName: self.finding.severity.icon)
                .foregroundStyle(self.finding.severity.color)
                .font(.body)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(self.finding.title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(self.finding.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if let autoFix = finding.autoFix {
                Button {
                    self.onAutoFix(self.finding)
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
