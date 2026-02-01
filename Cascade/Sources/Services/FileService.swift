import Foundation

/// Actor responsible for file I/O operations, ensuring thread-safe file access.
///
/// - Note: File operations use synchronous Foundation APIs internally. While the actor
///   ensures thread-safe access, these operations may block the actor's executor during I/O.
actor FileService {
    static let shared = FileService()

    private init() {}

    /// Reads the contents of a file at the specified URL.
    /// - Parameter url: The URL of the file to read.
    /// - Returns: The contents of the file as Data.
    func readFile(at url: URL) async throws -> Data {
        try Data(contentsOf: url)
    }

    /// Writes data to a file at the specified URL.
    /// - Parameters:
    ///   - data: The data to write.
    ///   - url: The URL of the file to write to.
    func writeFile(_ data: Data, to url: URL) async throws {
        try data.write(to: url, options: .atomic)
    }

    /// Checks if a file exists at the specified URL.
    /// - Parameter url: The URL to check.
    /// - Returns: True if the file exists, false otherwise.
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Creates a directory at the specified URL.
    /// - Parameter url: The URL where the directory should be created.
    func createDirectory(at url: URL) async throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    /// Deletes the file or directory at the specified URL.
    /// - Parameter url: The URL of the item to delete.
    func delete(at url: URL) async throws {
        try FileManager.default.removeItem(at: url)
    }
}
