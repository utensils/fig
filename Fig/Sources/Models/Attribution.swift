import Foundation

/// Controls how Claude Code attributes its contributions in version control.
///
/// Example JSON:
/// ```json
/// {
///   "commits": true,
///   "pullRequests": true
/// }
/// ```
public struct Attribution: Codable, Equatable, Hashable, Sendable {
    /// Whether to include attribution in commit messages.
    public var commits: Bool?

    /// Whether to include attribution in pull request descriptions.
    public var pullRequests: Bool?

    /// Additional properties not explicitly modeled, preserved during round-trip.
    public var additionalProperties: [String: AnyCodable]?

    public init(
        commits: Bool? = nil,
        pullRequests: Bool? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.commits = commits
        self.pullRequests = pullRequests
        self.additionalProperties = additionalProperties
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case commits
        case pullRequests
    }

    private static let knownKeys: Set<String> = ["commits", "pullRequests"]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commits = try container.decodeIfPresent(Bool.self, forKey: .commits)
        pullRequests = try container.decodeIfPresent(Bool.self, forKey: .pullRequests)

        // Capture unknown keys
        let allKeysContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var additional: [String: AnyCodable] = [:]

        for key in allKeysContainer.allKeys {
            if !Self.knownKeys.contains(key.stringValue) {
                additional[key.stringValue] = try allKeysContainer.decode(AnyCodable.self, forKey: key)
            }
        }

        additionalProperties = additional.isEmpty ? nil : additional
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(commits, forKey: .commits)
        try container.encodeIfPresent(pullRequests, forKey: .pullRequests)

        // Encode additional properties
        if let additionalProperties {
            var additionalContainer = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in additionalProperties {
                try additionalContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }
}
