import SwiftUI

// MARK: - MCPPasteSheet

/// Sheet for importing MCP servers from pasted JSON.
struct MCPPasteSheet: View {
    // MARK: Internal

    @Bindable var viewModel: MCPPasteViewModel

    var body: some View {
        VStack(spacing: 0) {
            self.header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    self.jsonInputSection
                    self.previewSection
                    self.destinationSection
                    self.conflictSection

                    if let result = viewModel.importResult {
                        self.resultSection(result: result)
                    }

                    if let error = viewModel.errorMessage {
                        self.errorSection(error: error)
                    }
                }
                .padding()
            }

            Divider()

            self.footer
        }
        .frame(width: 500, height: 550)
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text("Import MCP Servers")
                    .font(.headline)
                Text("Paste JSON configuration to add servers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var jsonInputSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Paste your MCP server JSON below:")
                        .font(.subheadline)

                    Spacer()

                    Button {
                        Task {
                            await self.viewModel.loadFromClipboard()
                        }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "clipboard")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                TextEditor(text: self.$viewModel.jsonText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 120, maxHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                if let error = viewModel.parseError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("JSON Input", systemImage: "curlybraces")
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let servers = viewModel.parsedServers, !servers.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(self.viewModel.serverCount) server(s) detected")
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(self.viewModel.serverNames, id: \.self) { name in
                            HStack {
                                let server = servers[name]
                                Image(systemName: server?.isHTTP == true ? "globe" : "terminal")
                                    .foregroundStyle(server?.isHTTP == true ? .blue : .green)
                                    .font(.caption)
                                Text(name)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                                Text(server?.isHTTP == true ? "HTTP" : "Stdio")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Preview", systemImage: "eye")
            }
        }
    }

    @ViewBuilder
    private var destinationSection: some View {
        if self.viewModel.parsedServers != nil {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    if self.viewModel.availableDestinations.isEmpty {
                        Text("No destinations available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Import to", selection: self.$viewModel.selectedDestination) {
                            Text("Select destination...")
                                .tag(nil as CopyDestination?)

                            ForEach(self.viewModel.availableDestinations) { destination in
                                Label(destination.displayName, systemImage: destination.icon)
                                    .tag(destination as CopyDestination?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Destination", systemImage: "arrow.right.square")
            }
        }
    }

    @ViewBuilder
    private var conflictSection: some View {
        if self.viewModel.parsedServers != nil {
            GroupBox {
                Picker("If server already exists", selection: self.$viewModel.conflictStrategy) {
                    ForEach(
                        [ConflictStrategy.rename, .overwrite, .skip],
                        id: \.self
                    ) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(.menu)
                .padding(.vertical, 4)
            } label: {
                Label("Conflict Resolution", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                self.dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if self.viewModel.importSucceeded {
                Button("Done") {
                    self.dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Import") {
                    Task {
                        await self.viewModel.performImport()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!self.viewModel.canImport)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private func resultSection(result: BulkImportResult) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if result.totalImported > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(result.summary)
                    }

                    if !result.renamed.isEmpty {
                        ForEach(Array(result.renamed.sorted(by: { $0.key < $1.key })), id: \.key) { old, new in
                            HStack {
                                Text(old)
                                    .font(.system(.caption, design: .monospaced))
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(new)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text(result.summary)
                    }
                }

                if !result.errors.isEmpty {
                    ForEach(result.errors, id: \.self) { error in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Result", systemImage: "checkmark.seal")
        }
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

#Preview {
    MCPPasteSheet(
        viewModel: MCPPasteViewModel(
            currentProject: .project(path: "/tmp/project", name: "My Project")
        )
    )
}
