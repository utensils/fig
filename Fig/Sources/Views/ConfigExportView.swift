import SwiftUI

// MARK: - ConfigExportView

/// Sheet for exporting project configuration to a bundle file.
struct ConfigExportView: View {
    // MARK: Internal

    @Bindable var viewModel: ConfigExportViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            self.header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Component selection
                    self.componentSelectionSection

                    // Sensitive data warning
                    if self.viewModel.includeLocalSettings {
                        self.sensitiveDataWarning
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        self.errorSection(error: error)
                    }

                    // Success message
                    if self.viewModel.exportSuccessful {
                        self.successSection
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            self.footer
        }
        .frame(width: 450, height: 400)
        .task {
            await self.viewModel.loadAvailableComponents()
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

    private var header: some View {
        HStack {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text("Export Configuration")
                    .font(.headline)
                Text(self.viewModel.projectName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var componentSelectionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select components to export:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if self.viewModel.availableComponents.isEmpty {
                    Text("No configuration found in this project.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ConfigBundleComponent.allCases) { component in
                        if self.viewModel.availableComponents.contains(component) {
                            ComponentToggle(
                                component: component,
                                isSelected: Binding(
                                    get: { self.viewModel.selectedComponents.contains(component) },
                                    set: { selected in
                                        if selected {
                                            self.viewModel.selectedComponents.insert(component)
                                        } else {
                                            self.viewModel.selectedComponents.remove(component)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Components", systemImage: "square.stack.3d.up")
        }
    }

    private var sensitiveDataWarning: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Local settings may contain sensitive data")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(
                    "The local settings file (settings.local.json) may contain API keys, " +
                        "tokens, or other sensitive information. Only share this export " +
                        "file with trusted parties."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Toggle(isOn: self.$viewModel.acknowledgedSensitiveData) {
                    Text("I understand the risks")
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Security Warning", systemImage: "lock.shield")
        }
    }

    private var successSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Export successful!")
                        .fontWeight(.medium)
                }

                if let url = viewModel.exportedURL {
                    Text(url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Success", systemImage: "checkmark.seal")
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                self.dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if self.viewModel.exportSuccessful {
                Button("Done") {
                    self.dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Export...") {
                    Task {
                        await self.viewModel.performExport()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!self.viewModel.canExport)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private func errorSection(error: String) -> some View {
        GroupBox {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .foregroundStyle(.red)
            }
            .padding(.vertical, 4)
        } label: {
            Label("Error", systemImage: "xmark.octagon")
        }
    }
}

// MARK: - ComponentToggle

/// Toggle for selecting a component with info.
private struct ComponentToggle: View {
    let component: ConfigBundleComponent

    @Binding var isSelected: Bool

    var body: some View {
        Toggle(isOn: self.$isSelected) {
            HStack {
                Image(systemName: self.component.icon)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.component.displayName)
                        .font(.subheadline)
                    if let warning = component.sensitiveWarning {
                        Text(warning)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

#Preview {
    ConfigExportView(
        viewModel: ConfigExportViewModel(
            projectPath: URL(fileURLWithPath: "/tmp/project"),
            projectName: "My Project"
        )
    )
}
