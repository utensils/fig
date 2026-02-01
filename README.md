# Cascade

A macOS application built with SwiftUI targeting macOS 14+ (Sonoma).

## Overview

Cascade is a modern macOS application that follows the MVVM (Model-View-ViewModel) architecture pattern. It leverages Swift 6's strict concurrency features to ensure thread-safe operations throughout the codebase.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16.0 or later
- Swift 6.0

## Project Structure

```
Cascade/
├── Package.swift           # Swift Package Manager manifest
├── Cascade.entitlements    # Code signing entitlements
└── Sources/
    ├── App/               # Application entry point
    │   └── CascadeApp.swift
    ├── Models/            # Data models (Sendable conformant)
    │   └── SidebarItem.swift
    ├── ViewModels/        # View models (@MainActor)
    │   └── AppViewModel.swift
    ├── Views/             # SwiftUI views
    │   ├── ContentView.swift
    │   ├── SidebarView.swift
    │   └── DetailView.swift
    ├── Services/          # Business logic (actors for I/O)
    │   └── FileService.swift
    └── Utilities/         # Helper utilities
        └── Logger.swift
```

## Architecture

### MVVM Pattern

- **Models**: Pure data structures that conform to `Sendable` for safe concurrent access
- **ViewModels**: Classes marked with `@MainActor` to ensure UI updates happen on the main thread
- **Views**: SwiftUI views that observe view models and render the UI

### Concurrency

The project uses Swift 6 strict concurrency:

- **Actors**: Used for file I/O operations (`FileService`) to ensure thread-safe access
- **@MainActor**: Applied to view models to guarantee main thread execution
- **Sendable**: All models conform to `Sendable` for safe cross-isolation transfers

## Building

### Using Swift Package Manager

```bash
cd Cascade
swift build
```

### Using Xcode

1. Open `Cascade/Package.swift` in Xcode
2. Select the "My Mac" destination
3. Press Cmd+B to build or Cmd+R to run

## Distribution

This application is configured for direct distribution (Developer ID) rather than the Mac App Store. The app should be notarized before distribution.

### Code Signing

The app is configured for Developer ID distribution. Ensure you have a valid Developer ID certificate installed in your keychain.

## Features

- Modern SwiftUI interface with `NavigationSplitView`
- Light and dark mode support
- Thread-safe file operations via actors
- Unified logging using OSLog

## License

Copyright © 2024. All rights reserved.
