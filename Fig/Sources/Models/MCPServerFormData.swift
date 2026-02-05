import Foundation

// MARK: - MCPServerType

/// Type of MCP server transport.
enum MCPServerType: String, CaseIterable, Identifiable, Sendable {
    case stdio
    case http

    // MARK: Internal

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .stdio: "Stdio (Command)"
        case .http: "HTTP (URL)"
        }
    }

    var icon: String {
        switch self {
        case .stdio: "terminal"
        case .http: "globe"
        }
    }
}

// MARK: - MCPServerScope

/// Target scope for saving an MCP server configuration.
enum MCPServerScope: String, CaseIterable, Identifiable, Sendable {
    case project
    case global

    // MARK: Internal

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .project: "Project (.mcp.json)"
        case .global: "Global (~/.claude.json)"
        }
    }

    var icon: String {
        switch self {
        case .project: "folder"
        case .global: "globe"
        }
    }
}

// MARK: - KeyValuePair

/// A key-value pair for environment variables or headers.
struct KeyValuePair: Identifiable, Equatable, Sendable {
    // MARK: Lifecycle

    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id
        self.key = key
        self.value = value
    }

    // MARK: Internal

    let id: UUID
    var key: String
    var value: String

    /// Whether this pair has valid content.
    var isValid: Bool {
        !self.key.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - MCPValidationError

/// Validation error for MCP server form.
struct MCPValidationError: Identifiable, Equatable, Sendable {
    // MARK: Lifecycle

    init(field: String, message: String) {
        self.id = UUID()
        self.field = field
        self.message = message
    }

    // MARK: Internal

    let id: UUID
    let field: String
    let message: String
}

// MARK: - MCPServerFormData

/// Observable form state for creating or editing an MCP server.
@MainActor
@Observable
final class MCPServerFormData {
    // MARK: Lifecycle

    init(
        name: String = "",
        serverType: MCPServerType = .stdio,
        scope: MCPServerScope = .project,
        command: String = "",
        args: [String] = [],
        envVars: [KeyValuePair] = [],
        url: String = "",
        headers: [KeyValuePair] = [],
        isEditing: Bool = false,
        originalName: String? = nil
    ) {
        self.name = name
        self.serverType = serverType
        self.scope = scope
        self.command = command
        self.args = args
        self.envVars = envVars
        self.url = url
        self.headers = headers
        self.isEditing = isEditing
        self.originalName = originalName
    }

    // MARK: Internal

    /// Server name (key in the dictionary).
    var name: String

    /// Type of server (stdio or http).
    var serverType: MCPServerType

    /// Target scope for saving.
    var scope: MCPServerScope

    /// Command to execute for stdio servers.
    var command: String

    /// Arguments for the command.
    var args: [String]

    /// Environment variables.
    var envVars: [KeyValuePair]

    /// URL for HTTP servers.
    var url: String

    /// HTTP headers.
    var headers: [KeyValuePair]

    // MARK: - Editing State

    /// Whether we're editing an existing server.
    var isEditing: Bool

    /// Original name when editing (for rename detection).
    var originalName: String?

    /// Input for adding a new argument.
    var newArgInput: String = ""

    /// Whether the form has valid data to save.
    var isValid: Bool {
        self.validate(existingNames: []).isEmpty
    }

    // MARK: - Factory Methods

    /// Creates form data from an existing MCP server for editing.
    static func from(
        name: String,
        server: MCPServer,
        scope: MCPServerScope
    ) -> MCPServerFormData {
        let formData = MCPServerFormData(
            name: name,
            serverType: server.isHTTP ? .http : .stdio,
            scope: scope,
            command: server.command ?? "",
            args: server.args ?? [],
            envVars: (server.env ?? [:]).map { KeyValuePair(key: $0.key, value: $0.value) }
                .sorted { $0.key < $1.key },
            url: server.url ?? "",
            headers: (server.headers ?? [:]).map { KeyValuePair(key: $0.key, value: $0.value) }
                .sorted { $0.key < $1.key },
            isEditing: true,
            originalName: name
        )
        return formData
    }

    // MARK: - Validation

    /// Validates the form data and returns any errors.
    func validate(existingNames: Set<String>) -> [MCPValidationError] {
        var errors: [MCPValidationError] = []

        // Name validation
        let trimmedName = self.name.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty {
            errors.append(MCPValidationError(field: "name", message: "Server name is required"))
        } else if !self.isValidServerName(trimmedName) {
            errors.append(MCPValidationError(
                field: "name",
                message: "Name can only contain letters, numbers, hyphens, and underscores"
            ))
        } else if existingNames.contains(trimmedName) {
            // Only check for duplicates if not editing or if name changed
            if !self.isEditing || (self.originalName != trimmedName) {
                errors.append(MCPValidationError(field: "name", message: "A server with this name already exists"))
            }
        }

        // Type-specific validation
        switch self.serverType {
        case .stdio:
            if self.command.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(MCPValidationError(field: "command", message: "Command is required"))
            }
        case .http:
            let trimmedURL = self.url.trimmingCharacters(in: .whitespaces)
            if trimmedURL.isEmpty {
                errors.append(MCPValidationError(field: "url", message: "URL is required"))
            } else if !self.isValidURL(trimmedURL) {
                errors.append(MCPValidationError(field: "url", message: "URL must start with http:// or https://"))
            }
        }

        return errors
    }

    /// Converts form data to an MCPServer model.
    func toMCPServer() -> MCPServer {
        switch self.serverType {
        case .stdio:
            let envDict = self.envVars
                .filter(\.isValid)
                .reduce(into: [String: String]()) { dict, pair in
                    dict[pair.key] = pair.value
                }
            return MCPServer.stdio(
                command: self.command.trimmingCharacters(in: .whitespaces),
                args: self.args.isEmpty ? nil : self.args,
                env: envDict.isEmpty ? nil : envDict
            )
        case .http:
            let headersDict = self.headers
                .filter(\.isValid)
                .reduce(into: [String: String]()) { dict, pair in
                    dict[pair.key] = pair.value
                }
            return MCPServer.http(
                url: self.url.trimmingCharacters(in: .whitespaces),
                headers: headersDict.isEmpty ? nil : headersDict
            )
        }
    }

    // MARK: - Argument Management

    /// Adds a new argument.
    func addArg(_ arg: String) {
        let trimmed = arg.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return
        }
        self.args.append(trimmed)
    }

    /// Removes an argument at the specified index.
    func removeArg(at index: Int) {
        guard self.args.indices.contains(index) else {
            return
        }
        self.args.remove(at: index)
    }

    // MARK: - Environment Variable Management

    /// Adds an empty environment variable row.
    func addEnvVar() {
        self.envVars.append(KeyValuePair())
    }

    /// Removes an environment variable at the specified index.
    func removeEnvVar(at index: Int) {
        guard self.envVars.indices.contains(index) else {
            return
        }
        self.envVars.remove(at: index)
    }

    // MARK: - Header Management

    /// Adds an empty header row.
    func addHeader() {
        self.headers.append(KeyValuePair())
    }

    /// Removes a header at the specified index.
    func removeHeader(at index: Int) {
        guard self.headers.indices.contains(index) else {
            return
        }
        self.headers.remove(at: index)
    }

    // MARK: - Import Methods

    /// Parses JSON and populates form data.
    func parseFromJSON(_ json: String) throws {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        // Try parsing as MCPServer directly
        if let server = try? decoder.decode(MCPServer.self, from: data) {
            self.populateFrom(server: server)
            return
        }

        // Try parsing as a named server { "name": { ...config } }
        if let dict = try? decoder.decode([String: MCPServer].self, from: data),
           let (serverName, server) = dict.first
        {
            self.name = serverName
            self.populateFrom(server: server)
            return
        }

        throw MCPParseError.invalidJSON("Could not parse JSON as MCP server configuration")
    }

    /// Parses a CLI command and populates form data.
    /// Supports: claude mcp add-json 'name' '{"command": ...}'
    func parseFromCLICommand(_ command: String) throws {
        // Pattern: claude mcp add-json 'name' '{...json...}'
        // or: claude mcp add-json "name" "{...json...}"
        let pattern = #"claude\s+mcp\s+add-json\s+['\"]?(\w[\w-]*)['\"]?\s+['\"]?(\{.+\})['\"]?"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(
                  in: command,
                  options: [],
                  range: NSRange(command.startIndex..., in: command)
              ),
              let nameRange = Range(match.range(at: 1), in: command),
              let jsonRange = Range(match.range(at: 2), in: command)
        else {
            throw MCPParseError
                .invalidCLICommand("Could not parse CLI command. Expected: claude mcp add-json 'name' '{...}'")
        }

        self.name = String(command[nameRange])
        let jsonString = String(command[jsonRange])

        try parseFromJSON(jsonString)
    }

    // MARK: Private

    private func isValidServerName(_ name: String) -> Bool {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return name.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    private func isValidURL(_ urlString: String) -> Bool {
        urlString.hasPrefix("http://") || urlString.hasPrefix("https://")
    }

    private func populateFrom(server: MCPServer) {
        if server.isHTTP {
            self.serverType = .http
            self.url = server.url ?? ""
            self.headers = (server.headers ?? [:]).map { KeyValuePair(key: $0.key, value: $0.value) }
                .sorted { $0.key < $1.key }
        } else {
            self.serverType = .stdio
            self.command = server.command ?? ""
            self.args = server.args ?? []
            self.envVars = (server.env ?? [:]).map { KeyValuePair(key: $0.key, value: $0.value) }
                .sorted { $0.key < $1.key }
        }
    }
}

// MARK: - MCPParseError

/// Errors that can occur when parsing MCP server configurations.
enum MCPParseError: Error, LocalizedError {
    case invalidJSON(String)
    case invalidCLICommand(String)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .invalidJSON(message): message
        case let .invalidCLICommand(message): message
        }
    }
}
