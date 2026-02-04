# Fig

<p align="center">
  <img src="https://github.com/user-attachments/assets/1f5228a2-0111-40fc-a5e7-5dc3a29110ca" alt="Fig logo" width="200" />
</p>

A native macOS application for managing [Claude Code](https://github.com/anthropics/claude-code) configuration.

## What is Fig?

Fig provides a visual interface for managing Claude Code settings, MCP servers, and project configurations. Instead of manually editing JSON files scattered across your system, Fig discovers your projects and lets you manage everything from one place.

## Features

### Project Management
- **Project Discovery** — Automatically finds Claude Code projects from `~/.claude.json` and common development directories
- **Project Explorer** — Browse all your projects with quick access to their configuration files
- **Favorites & Recents** — Pin frequently used projects for fast access

### Configuration Editing
- **Settings Editor** — Edit permissions, environment variables, and general settings with a friendly UI
- **MCP Server Management** — Add, edit, and copy MCP servers between projects
- **Visual Hook Composer** — Configure Claude Code hooks without writing JSON by hand
- **Merged Config Viewer** — See the effective configuration with source attribution (which file each setting comes from)

### Safety & Convenience
- **Automatic Backups** — Every save creates a timestamped backup
- **External Change Detection** — Warns when files are modified outside of Fig
- **Undo/Redo** — Full undo history for configuration changes
- **Config Health Checks** — Validates your configuration and highlights potential issues

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16.0 or later (for building from source)
- Swift 6.0

## Installation

### From Source

```bash
git clone https://github.com/doomspork/fig.git
cd fig/Fig
swift build
```

Or open `Fig/Package.swift` in Xcode and press Cmd+R to build and run.

### Pre-built Binary

Coming soon.

## Project Structure

```
Fig/
├── Package.swift           # Swift Package Manager manifest
├── Fig.entitlements        # Code signing entitlements
└── Sources/
    ├── App/               # Application entry point
    ├── Models/            # Data models (Sendable conformant)
    ├── ViewModels/        # View models (@MainActor)
    ├── Views/             # SwiftUI views
    ├── Services/          # Business logic (actors for I/O)
    └── Utilities/         # Helper utilities
```

## Architecture

Fig uses the MVVM pattern with Swift 6 strict concurrency:

- **Models** — Pure data structures conforming to `Sendable`
- **ViewModels** — `@MainActor` classes for UI state management
- **Views** — SwiftUI views with `NavigationSplitView` layout
- **Services** — Actor-based services for thread-safe file I/O

## Configuration Files

Fig manages these Claude Code configuration files:

| File | Scope | Purpose |
|------|-------|---------|
| `~/.claude.json` | Global | User preferences, project history, global MCP servers |
| `~/.claude/settings.json` | Global | Global settings and permissions |
| `<project>/.claude/settings.json` | Project | Project-specific settings |
| `<project>/.claude/settings.local.json` | Project | Local overrides (gitignored) |
| `<project>/.mcp.json` | Project | Project MCP server configuration |

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Status

Fig is in early development. See the [GitHub Issues](https://github.com/doomspork/fig/issues) for the roadmap and current progress.

## License

MIT License - see [LICENSE](LICENSE) for details.
