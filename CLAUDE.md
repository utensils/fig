# CLAUDE.md

This file provides guidance for Claude Code and other AI agents working on the Fig codebase.

## Project Overview

Fig is a native macOS application for managing Claude Code configuration files. It provides a visual interface for editing `~/.claude.json`, `~/.claude/settings.json`, project-level settings, MCP server configs, and hooks. See `README.md` for full feature details.

## Development Setup

```bash
brew bundle            # Installs SwiftLint, SwiftFormat, Lefthook
lefthook install       # Sets up pre-commit/pre-push git hooks
swift build            # Build the project
swift test             # Run the test suite
```

Minimum deployment target: **macOS 14.0 (Sonoma)**. Swift 6.0 with strict concurrency enabled.

## Architecture

Fig uses **MVVM** with Swift 6 strict concurrency throughout:

- **Models** (`Sources/Models/`) — `Sendable`, `Codable`, `Equatable`, `Hashable`. All models preserve unknown JSON keys via `AnyCodable` and `DynamicCodingKey` for safe round-tripping.
- **ViewModels** (`Sources/ViewModels/`) — `@MainActor @Observable final class`. Manage UI state, loading/saving, undo/redo, and file watching.
- **Views** (`Sources/Views/`) — SwiftUI views. Onboarding views live in `Views/Onboarding/`.
- **Services** (`Sources/Services/`) — Actor-based services for all file I/O and business logic. Thread-safe by design.
- **Utilities** (`Sources/Utilities/`) — Helpers like `Logger.swift`.
- **App** (`Sources/App/`) — Entry point (`FigApp.swift`), keyboard commands, and focused values.

### Configuration Hierarchy

Settings merge from three tiers with clear precedence: **projectLocal > projectShared > global**. `MergedSettings` tracks the source of each value for UI attribution.

## Code Conventions

- **Linting**: SwiftLint (`.swiftlint.yml`) + SwiftFormat (`.swiftformat`) enforced via pre-commit hooks.
- **Line length**: 120-char soft limit (warning), 150-char hard limit (error).
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/) required. Pattern: `feat|fix|docs|style|refactor|perf|test|chore|build|ci` with optional scope. Enforced by lefthook commit-msg hook.
- **No force unwraps** — prefer `guard`/`if let`.
- **Logging**: Use the `Log` utility (`Log.general`, `Log.ui`, `Log.fileIO`, `Log.network`) — never use `print`.
- **Concurrency**: All models must be `Sendable`. All I/O services must be `actor`. All view models must be `@MainActor`.

## Testing

- Uses **Swift Testing** framework (`@Suite`, `@Test`, `#expect`) — not XCTest.
- Tests live in `Tests/`.
- Run with `swift test`.
- Focus areas: model serialization/round-tripping, service logic, view model behavior.
- Test fixtures use enums with static properties for shared test data.

## Common Pitfalls

- **Preserve unknown JSON fields**: Models use custom `init(from:)`/`encode(to:)` with `AnyCodable` to round-trip unknown keys. Never drop `additionalProperties` during serialization.
- **Backups are automatic**: `ConfigFileManager` creates timestamped backups before every write. Do not bypass this.
- **External change detection**: File watching uses `DispatchSource` on file modification dates. Respect this pattern when modifying file I/O.
- **Config merge semantics**: Permissions union across tiers, environment variables override, hooks concatenate. Check `SettingsMergeService` before changing merge behavior.
- **AnyCodable is `@unchecked Sendable`**: It stores `Any` internally and sanitizes values recursively. Take care when modifying it.
