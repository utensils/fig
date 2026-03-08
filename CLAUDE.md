# CLAUDE.md

This file provides guidance for Claude Code and other AI agents working on the Fig codebase.

## Project Overview

Fig is a cross-platform desktop application for managing Claude Code configuration files. It provides a visual interface for editing `~/.claude.json`, `~/.claude/settings.json`, project-level settings, MCP server configs, and hooks. See `README.md` for full feature details.

## Development Setup

```bash
cargo build            # Build all crates
cargo test             # Run the test suite
cargo clippy -- -D warnings  # Lint (must pass clean)
cargo fmt --check      # Format check
```

## Architecture

Fig is a Cargo workspace with two crates using the Iced Elm architecture:

- **fig-core** (`fig-core/src/`) — Pure library crate. Models, services, and error types. No GUI dependency.
  - `models/` — Data structures with `serde`, `Clone`, `PartialEq`. Unknown JSON fields preserved via `#[serde(flatten)]` with `HashMap<String, serde_json::Value>`.
  - `services/` — Business logic: config file I/O (`ConfigFileManager`), file watching (`FileWatcher`), settings merging (`SettingsMergeService`), health checks, MCP operations, project discovery.
  - `error.rs` — `FigError` and `ConfigFileError` types using `thiserror`.

- **fig-ui** (`fig-ui/src/`) — Binary crate using [Iced](https://iced.rs) 0.13.
  - `main.rs` — `App` struct (state), `Message` enum (events), `update()` (state transitions), `view()` (render).
  - `views/` — View functions returning `Element<'a, Message>`. Each view is a standalone function, not a struct.
  - `styles.rs` — Theme color constants (`TEXT_PRIMARY`, `ACCENT`, `SELECTED_BG`, etc.).

### Configuration Hierarchy

Settings merge from three tiers with clear precedence: **projectLocal > projectShared > global**. `MergedSettings` tracks the source of each value for UI attribution.

## Code Conventions

- **Linting**: `cargo clippy -- -D warnings` must pass clean. `cargo fmt` for formatting.
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/) required. Pattern: `feat|fix|docs|style|refactor|perf|test|chore|build|ci` with optional scope. Lowercase messages.
- **No `.unwrap()` in library code** — use `?` or proper error handling. `.unwrap()` is acceptable in tests.
- **Logging**: Use `eprintln!` sparingly for debugging. No println in library code.

## Testing

- Inline `#[cfg(test)] mod tests` in each module.
- Use `#[test]` for sync tests, `#[tokio::test]` for async.
- Run with `cargo test`.
- Focus areas: model serialization round-tripping, service logic, validation.
- Currently 166 tests across the workspace.

## Common Pitfalls

- **Preserve unknown JSON fields**: Models use `#[serde(flatten)] pub extra: HashMap<String, serde_json::Value>` to round-trip unknown keys. Never drop extra fields during serialization.
- **Backups are automatic**: `ConfigFileManager` creates timestamped backups before every write. Do not bypass this.
- **External change detection**: File watching uses polling on file modification times. Respect this pattern when modifying file I/O.
- **Config merge semantics**: Permissions union across tiers, environment variables override, hooks concatenate. Check `SettingsMergeService` before changing merge behavior.
- **Iced lifetime patterns**: View functions return `Element<'a, Message>` — borrowed data must outlive the returned element. Use `.to_string()` or `.clone()` for local values used in text widgets.
- **Iced Padding**: Use `Padding::new(f32).left(f32).right(f32)` builder for asymmetric padding.
- **Clippy too-many-arguments**: Use `#[allow(clippy::too_many_arguments)]` on view dispatch functions that pass state to sub-views.
