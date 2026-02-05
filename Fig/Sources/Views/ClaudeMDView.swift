import MarkdownUI
import SwiftUI

// MARK: - ClaudeMDView

/// Tab view for previewing and editing CLAUDE.md files in the project hierarchy.
struct ClaudeMDView: View {
    // MARK: Lifecycle

    init(projectPath: String) {
        _viewModel = State(initialValue: ClaudeMDViewModel(projectPath: projectPath))
    }

    // MARK: Internal

    var body: some View {
        HSplitView {
            // File hierarchy sidebar
            self.claudeMDSidebar
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            // Content area
            self.contentArea
                .frame(minWidth: 300)
        }
        .task {
            await self.viewModel.loadFiles()
        }
    }

    // MARK: Private

    @State private var viewModel: ClaudeMDViewModel

    // MARK: - Sidebar

    private var claudeMDSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Hierarchy")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task {
                        await self.viewModel.loadFiles()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: self.$viewModel.selectedFileID) {
                    // Global section
                    Section("Global") {
                        ForEach(self.viewModel.files.filter { $0.level == .global }) { file in
                            ClaudeMDFileRow(file: file)
                                .tag(file.id)
                        }
                    }

                    // Project section
                    Section("Project") {
                        ForEach(
                            self.viewModel.files.filter { $0.level != .global }
                        ) { file in
                            ClaudeMDFileRow(file: file)
                                .tag(file.id)
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: self.viewModel.selectedFileID) { _, _ in
                    self.viewModel.cancelEditing()
                }
            }
        }
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: 0) {
            if let file = viewModel.selectedFile {
                // Toolbar
                self.contentToolbar(for: file)

                Divider()

                // Content
                if self.viewModel.isEditing {
                    self.editorView
                } else if file.exists {
                    self.previewView(for: file)
                } else {
                    self.emptyFileView(for: file)
                }
            } else {
                ContentUnavailableView(
                    "Select a File",
                    systemImage: "doc.text",
                    description: Text("Choose a CLAUDE.md file from the hierarchy to view or edit.")
                )
            }
        }
    }

    // MARK: - Editor

    private var editorView: some View {
        TextEditor(text: self.$viewModel.editContent)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(4)
    }

    private func contentToolbar(for file: ClaudeMDFile) -> some View {
        HStack {
            // File path
            HStack(spacing: 4) {
                Image(systemName: file.level.icon)
                    .foregroundStyle(.secondary)
                Text(file.displayPath)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
            }

            Spacer()

            // Git status badge
            if file.exists {
                GitStatusBadge(isTracked: file.isTrackedByGit)
            }

            // Action buttons
            if self.viewModel.isEditing {
                Button("Cancel") {
                    self.viewModel.cancelEditing()
                }

                Button("Save") {
                    Task {
                        await self.viewModel.saveSelectedFile()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(self.viewModel.editContent == file.content)
            } else if file.exists {
                Button {
                    self.viewModel.startEditing()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            } else {
                Button {
                    Task {
                        await self.viewModel.createFile(at: file.level)
                    }
                } label: {
                    Label("Create", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Preview

    private func previewView(for file: ClaudeMDFile) -> some View {
        ScrollView {
            Markdown(file.content)
                .markdownTheme(.gitHub)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Empty State

    private func emptyFileView(for file: ClaudeMDFile) -> some View {
        ContentUnavailableView {
            Label("No CLAUDE.md", systemImage: "doc.badge.plus")
        } description: {
            Text("No CLAUDE.md file exists at \(file.displayPath).")
        } actions: {
            Button("Create File") {
                Task {
                    await self.viewModel.createFile(at: file.level)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - ClaudeMDFileRow

/// A row in the CLAUDE.md hierarchy sidebar.
struct ClaudeMDFileRow: View {
    let file: ClaudeMDFile

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: self.file.exists ? "doc.text.fill" : "doc.badge.plus")
                .foregroundStyle(self.file.exists ? .blue : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(self.file.level.displayName)
                    .font(.body)
                    .lineLimit(1)

                if case let .subdirectory(path) = file.level {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if self.file.exists {
                if self.file.isTrackedByGit {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .help("Tracked by git")
                } else {
                    Image(systemName: "circle.dashed")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("Not tracked by git")
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - GitStatusBadge

/// Badge showing git tracking status.
struct GitStatusBadge: View {
    let isTracked: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: self.isTracked ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(self.isTracked ? .green : .orange)
                .font(.caption)
            Text(self.isTracked ? "In git" : "Untracked")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    ClaudeMDView(projectPath: "/Users/test/project")
        .frame(width: 700, height: 500)
}
