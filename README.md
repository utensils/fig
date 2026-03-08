# Fig

<p align="center">
  <img src="https://github.com/user-attachments/assets/1f5228a2-0111-40fc-a5e7-5dc3a29110ca" alt="Fig logo" width="200" />
</p>

A cross-platform desktop application for managing [Claude Code](https://github.com/anthropics/claude-code) configuration.

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

- Rust 1.78 or later

## Installation

### From Source

```bash
git clone https://github.com/utensils/fig.git
cd fig
cargo build --release
```

Run with:

```bash
cargo run --release
```

### Pre-built Binary

Coming soon.

## Project Structure

```
fig-core/              # Library crate: models, services, error types
├── src/
│   ├── models/        # Data models (serde, Clone, PartialEq)
│   ├── services/      # Business logic (config I/O, health checks, merging)
│   └── error.rs       # Error types
fig-ui/                # Binary crate: Iced GUI application
├── src/
│   ├── views/         # View functions (detail, sidebar, editors)
│   ├── styles.rs      # Theme constants
│   └── main.rs        # App state, Message enum, update/view
Cargo.toml             # Workspace manifest
```

## Architecture

Fig uses a Cargo workspace with two crates and the Iced Elm architecture:

- **fig-core** — Pure library with models and services. No GUI dependency. Handles configuration file I/O, settings merging, health checks, and MCP operations.
- **fig-ui** — Binary using [Iced](https://iced.rs) 0.13. Follows the Elm pattern: `Model` (app state) → `Message` (events) → `update` (state transitions) → `view` (render UI).

## Configuration Files

Fig manages these Claude Code configuration files:

| File | Scope | Purpose |
|------|-------|---------|
| `~/.claude.json` | Global | User preferences, project history, global MCP servers |
| `~/.claude/settings.json` | Global | Global settings and permissions |
| `<project>/.claude/settings.json` | Project | Project-specific settings |
| `<project>/.claude/settings.local.json` | Project | Local overrides (gitignored) |
| `<project>/.mcp.json` | Project | Project MCP server configuration |

## Documentation

Full documentation is available at **[utensils.github.io/fig](https://utensils.github.io/fig/)**.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Status

Fig is in early development. See the [GitHub Issues](https://github.com/utensils/fig/issues) for the roadmap and current progress.

## License

MIT License - see [LICENSE](LICENSE) for details.
