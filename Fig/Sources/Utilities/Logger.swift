import OSLog

/// Application-wide logging utility using unified logging.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.fig.app"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let fileIO = Logger(subsystem: subsystem, category: "fileIO")
    static let network = Logger(subsystem: subsystem, category: "network")
}
