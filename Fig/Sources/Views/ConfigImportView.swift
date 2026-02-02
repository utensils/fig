import SwiftUI

// MARK: - ConfigImportView

/// Wizard for importing project configuration from a bundle file.
struct ConfigImportView: View {
    // MARK: Internal

    @Bindable var viewModel: ConfigImportViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with step indicator
            header

            Divider()

            // Step content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stepContent
                }
                .padding()
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 500, height: 500)
    }

    // MARK: Private

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text("Import Configuration")
                        .font(.headline)
                    Text(viewModel.projectName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Step indicator
            HStack(spacing: 0) {
                ForEach(Array(ImportWizardStep.allCases.enumerated()), id: \.element) { index, step in
                    if index > 0 {
                        Rectangle()
                            .fill(step.rawValue <= viewModel.currentStep.rawValue
                                ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                    }

                    Circle()
                        .fill(step.rawValue <= viewModel.currentStep.rawValue
                            ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .selectFile:
            selectFileStep
        case .selectComponents:
            selectComponentsStep
        case .resolveConflicts:
            resolveConflictsStep
        case .preview:
            previewStep
        case .complete:
            completeStep
        }
    }

    // MARK: - Step Views

    private var selectFileStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select a configuration bundle to import.")
                .font(.subheadline)

            if let url = viewModel.selectedFileURL {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.blue)
                            Text(url.lastPathComponent)
                                .fontWeight(.medium)
                        }

                        if let bundle = viewModel.bundle {
                            Divider()

                            HStack {
                                Text("From:")
                                    .foregroundStyle(.secondary)
                                Text(bundle.projectName)
                            }
                            .font(.caption)

                            HStack {
                                Text("Exported:")
                                    .foregroundStyle(.secondary)
                                Text(bundle.exportedAt, style: .date)
                            }
                            .font(.caption)

                            if !bundle.contentSummary.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(bundle.contentSummary, id: \.self) { item in
                                        Text(item)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("Selected File", systemImage: "doc")
                }

                Button("Choose Different File...") {
                    Task {
                        await viewModel.selectFile()
                    }
                }
            } else {
                Button {
                    Task {
                        await viewModel.selectFile()
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.largeTitle)
                        Text("Select Bundle File")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                .buttonStyle(.bordered)
            }

            if viewModel.isLoading {
                ProgressView("Loading bundle...")
            }

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }
        }
    }

    private var selectComponentsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select which components to import.")
                .font(.subheadline)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.availableComponents) { component in
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedComponents.contains(component) },
                            set: { selected in
                                if selected {
                                    viewModel.selectedComponents.insert(component)
                                } else {
                                    viewModel.selectedComponents.remove(component)
                                }
                            }
                        )) {
                            HStack {
                                Image(systemName: component.icon)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(component.displayName)
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
                .padding(.vertical, 4)
            } label: {
                Label("Components", systemImage: "square.stack.3d.up")
            }

            // Sensitive data warning
            if viewModel.selectedComponents.contains(.localSettings) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Local settings may contain sensitive data")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)

                        Toggle(isOn: $viewModel.acknowledgedSensitiveData) {
                            Text("I trust this bundle and want to import it")
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("Security Warning", systemImage: "lock.shield")
                }
            }
        }
    }

    private var resolveConflictsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The following conflicts were detected. Choose how to resolve them.")
                .font(.subheadline)

            ForEach(viewModel.conflicts) { conflict in
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(conflict.description)
                        }

                        Picker("Resolution", selection: Binding(
                            get: { viewModel.resolutions[conflict.component] ?? .merge },
                            set: { viewModel.resolutions[conflict.component] = $0 }
                        )) {
                            ForEach(ImportConflict.ImportResolution.allCases) { resolution in
                                Text(resolution.displayName).tag(resolution)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label(conflict.component.displayName, systemImage: conflict.component.icon)
                }
            }
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review the changes that will be made.")
                .font(.subheadline)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(viewModel.selectedComponents)) { component in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(component.displayName)

                            if let resolution = viewModel.resolutions[component] {
                                Text("(\(resolution.displayName))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Components to Import", systemImage: "list.bullet")
            }

            if viewModel.hasSensitiveData {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.orange)
                    Text("This import includes potentially sensitive data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var completeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let result = viewModel.importResult {
                if result.success {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)

                        Text("Import Complete!")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(result.message)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)

                        Text("Import Completed with Issues")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }

                if !result.componentsImported.isEmpty {
                    GroupBox("Imported") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.componentsImported) { component in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(component.displayName)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }

                if !result.componentsSkipped.isEmpty {
                    GroupBox("Skipped") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.componentsSkipped) { component in
                                HStack {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.secondary)
                                    Text(component.displayName)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }

                if !result.errors.isEmpty {
                    GroupBox("Errors") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.errors, id: \.self) { error in
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(error)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)

                    Text("Import Failed")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(error)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    private var footer: some View {
        HStack {
            if viewModel.canGoBack {
                Button("Back") {
                    viewModel.previousStep()
                }
            }

            Spacer()

            if viewModel.currentStep == .complete {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(viewModel.currentStep == .preview ? "Import" : "Next") {
                    Task {
                        await viewModel.nextStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceed || viewModel.isImporting)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

#Preview {
    ConfigImportView(
        viewModel: ConfigImportViewModel(
            projectPath: URL(fileURLWithPath: "/tmp/project"),
            projectName: "My Project"
        )
    )
}
