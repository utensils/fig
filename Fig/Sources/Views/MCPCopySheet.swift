import SwiftUI

// MARK: - MCPCopySheet

/// Sheet for copying an MCP server to another project or global config.
struct MCPCopySheet: View {
    // MARK: Internal

    @Bindable var viewModel: MCPCopyViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Server info
                    serverInfoSection

                    // Sensitive data warnings
                    if !viewModel.sensitiveWarnings.isEmpty {
                        sensitiveWarningsSection
                    }

                    // Destination picker
                    destinationSection

                    // Conflict resolution (if conflict exists)
                    if let conflict = viewModel.conflict {
                        conflictSection(conflict: conflict)
                    }

                    // Result message
                    if let result = viewModel.copyResult {
                        resultSection(result: result)
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        errorSection(error: error)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 450, height: 500)
        .onChange(of: viewModel.selectedDestination) { _, _ in
            Task {
                await viewModel.checkForConflict()
            }
        }
    }

    // MARK: Private

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.doc")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text("Copy MCP Server")
                    .font(.headline)
                Text(viewModel.serverName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var serverInfoSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Server Type:")
                        .foregroundStyle(.secondary)
                    Text(viewModel.server.isStdio ? "Stdio" : "HTTP")
                        .fontWeight(.medium)
                }

                if viewModel.server.isStdio {
                    if let command = viewModel.server.command {
                        HStack(alignment: .top) {
                            Text("Command:")
                                .foregroundStyle(.secondary)
                            Text("\(command) \((viewModel.server.args ?? []).joined(separator: " "))")
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(2)
                        }
                    }
                } else if viewModel.server.isHTTP {
                    if let url = viewModel.server.url {
                        HStack(alignment: .top) {
                            Text("URL:")
                                .foregroundStyle(.secondary)
                            Text(url)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Server Configuration", systemImage: "server.rack")
        }
    }

    private var sensitiveWarningsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("This server contains potentially sensitive environment variables:")
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.sensitiveWarnings) { warning in
                        HStack {
                            Text(warning.key)
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                            Text("-")
                                .foregroundStyle(.secondary)
                            Text(warning.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Toggle(isOn: $viewModel.acknowledgedSensitiveData) {
                    Text("I understand these values will be copied")
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Security Warning", systemImage: "lock.shield")
        }
    }

    private var destinationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.isLoadingDestinations {
                    ProgressView("Loading destinations...")
                } else if viewModel.availableDestinations.isEmpty {
                    Text("No destinations available")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Destination", selection: $viewModel.selectedDestination) {
                        Text("Select destination...")
                            .tag(nil as CopyDestination?)

                        ForEach(viewModel.availableDestinations) { destination in
                            Label(destination.displayName, systemImage: destination.icon)
                                .tag(destination as CopyDestination?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Copy To", systemImage: "arrow.right.square")
        }
    }

    @ViewBuilder
    private func conflictSection(conflict: CopyConflict) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("A server named '\(conflict.serverName)' already exists at this destination.")
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose how to resolve:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // Overwrite option
                    Button {
                        Task {
                            await viewModel.copyWithOverwrite()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            VStack(alignment: .leading) {
                                Text("Overwrite")
                                    .fontWeight(.medium)
                                Text("Replace the existing server configuration")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    // Rename option
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            Task {
                                await viewModel.copyWithRename()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                VStack(alignment: .leading) {
                                    Text("Rename")
                                        .fontWeight(.medium)
                                    Text("Copy with a different name")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        TextField("New name", text: $viewModel.renamedServerName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    // Skip option
                    Button {
                        Task {
                            await viewModel.skipCopy()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            VStack(alignment: .leading) {
                                Text("Skip")
                                    .fontWeight(.medium)
                                Text("Cancel this copy operation")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Conflict Detected", systemImage: "exclamationmark.circle")
        }
    }

    @ViewBuilder
    private func resultSection(result: CopyResult) -> some View {
        GroupBox {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.success ? .green : .red)
                Text(result.message)
            }
            .padding(.vertical, 4)
        } label: {
            Label("Result", systemImage: "checkmark.seal")
        }
    }

    @ViewBuilder
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

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if viewModel.copyResult?.success == true {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else if viewModel.conflict == nil {
                Button("Copy") {
                    Task {
                        await viewModel.performCopy()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canCopy)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

#Preview {
    MCPCopySheet(
        viewModel: MCPCopyViewModel(
            serverName: "github",
            server: .stdio(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-github"],
                env: ["GITHUB_TOKEN": "ghp_xxx"]
            ),
            sourceDestination: .project(path: "/tmp/project", name: "My Project")
        )
    )
}
