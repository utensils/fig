import Foundation
import OSLog

// MARK: - MCPHealthCheckResult

/// Result of an MCP server health check.
struct MCPHealthCheckResult: Sendable {
    /// Status of the health check.
    enum Status: Sendable {
        case success(serverInfo: MCPServerInfo?)
        case failure(error: MCPHealthCheckError)
        case timeout
    }

    /// The server name that was tested.
    let serverName: String

    /// The result status.
    let status: Status

    /// How long the check took.
    let duration: TimeInterval

    /// Whether the check was successful.
    var isSuccess: Bool {
        if case .success = status { return true }
        return false
    }
}

// MARK: - MCPServerInfo

/// Information returned from a successful MCP handshake.
struct MCPServerInfo: Sendable {
    let protocolVersion: String?
    let serverName: String?
    let serverVersion: String?
}

// MARK: - MCPHealthCheckError

/// Errors that can occur during MCP health checks.
enum MCPHealthCheckError: Error, LocalizedError, Sendable {
    case processSpawnFailed(underlying: String)
    case processExitedEarly(code: Int32, stderr: String)
    case invalidHandshakeResponse(details: String)
    case httpRequestFailed(statusCode: Int?, message: String)
    case networkError(message: String)
    case timeout
    case noCommandOrURL

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .processSpawnFailed(msg):
            "Failed to start process: \(msg)"
        case let .processExitedEarly(code, stderr):
            "Process exited with code \(code): \(stderr.prefix(100))"
        case let .invalidHandshakeResponse(details):
            "Invalid MCP response: \(details)"
        case let .httpRequestFailed(code, msg):
            if let code { "HTTP \(code): \(msg)" } else { "HTTP error: \(msg)" }
        case let .networkError(msg):
            "Network error: \(msg)"
        case .timeout:
            "Connection timed out (10s)"
        case .noCommandOrURL:
            "Server has no command or URL configured"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .processSpawnFailed:
            "Check that the command exists and is executable"
        case .processExitedEarly:
            "Check server logs or environment variables"
        case .invalidHandshakeResponse:
            "The server may not support MCP protocol"
        case .httpRequestFailed:
            "Check the URL and any required authentication"
        case .networkError:
            "Check your network connection"
        case .timeout:
            "The server may be slow or unresponsive"
        case .noCommandOrURL:
            "Configure a command (stdio) or URL (HTTP)"
        }
    }
}

// MARK: - MCPHealthCheckService

/// Service for testing MCP server connectivity.
actor MCPHealthCheckService {
    // MARK: Internal

    /// Shared instance for app-wide health checks.
    static let shared = MCPHealthCheckService()

    /// Timeout for health checks in seconds.
    let timeout: TimeInterval = 10.0

    /// Tests connection to an MCP server.
    func checkHealth(name: String, server: MCPServer) async -> MCPHealthCheckResult {
        let startTime = Date()

        let status: MCPHealthCheckResult.Status
        if server.isHTTP {
            status = await checkHTTPServer(server)
        } else if server.isStdio {
            status = await checkStdioServer(server)
        } else {
            status = .failure(error: .noCommandOrURL)
        }

        let duration = Date().timeIntervalSince(startTime)

        return MCPHealthCheckResult(
            serverName: name,
            status: status,
            duration: duration
        )
    }

    // MARK: Private

    // MARK: - Stdio Server Check

    private func checkStdioServer(_ server: MCPServer) async -> MCPHealthCheckResult.Status {
        guard let command = server.command else {
            return .failure(error: .noCommandOrURL)
        }

        return await withTaskGroup(of: MCPHealthCheckResult.Status.self) { group in
            // Timeout task
            group.addTask {
                try? await Task.sleep(for: .seconds(self.timeout))
                return .timeout
            }

            // Health check task
            group.addTask {
                await self.performStdioCheck(
                    command: command,
                    args: server.args,
                    env: server.env
                )
            }

            // Return first completed result
            let result = await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func performStdioCheck(
        command: String,
        args: [String]?,
        env: [String: String]?
    ) async -> MCPHealthCheckResult.Status {
        let process = Process()

        // Use /usr/bin/env to resolve PATH for commands
        if command.hasPrefix("/") || command.hasPrefix("./") {
            process.executableURL = URL(fileURLWithPath: command)
            if let args {
                process.arguments = args
            }
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + (args ?? [])
        }

        // Set environment
        var environment = ProcessInfo.processInfo.environment
        if let env {
            for (key, value) in env {
                environment[key] = value
            }
        }
        process.environment = environment

        // Set up pipes
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return .failure(error: .processSpawnFailed(underlying: error.localizedDescription))
        }

        // Give the process a moment to start
        try? await Task.sleep(for: .milliseconds(100))

        // Check if process exited immediately
        if !process.isRunning {
            let exitCode = process.terminationStatus
            let stderrData = try? stderrPipe.fileHandleForReading.readToEnd()
            let stderrString = stderrData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return .failure(error: .processExitedEarly(code: exitCode, stderr: stderrString))
        }

        // Send MCP initialize request
        let initRequest = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":"# +
            #"{"protocolVersion":"2024-11-05","capabilities":{},"# +
            #""clientInfo":{"name":"Fig Health Check","version":"1.0"}}}"#
        let requestData = Data(initRequest.utf8)

        // MCP uses Content-Length header for stdio transport
        let header = "Content-Length: \(requestData.count)\r\n\r\n"
        stdinPipe.fileHandleForWriting.write(Data(header.utf8))
        stdinPipe.fileHandleForWriting.write(requestData)

        // Try to close the write end to signal we're done sending
        try? stdinPipe.fileHandleForWriting.close()

        // Read response with timeout
        let responseResult = await readMCPResponse(from: stdoutPipe.fileHandleForReading)

        // Clean up process
        process.terminate()
        try? await Task.sleep(for: .milliseconds(100))

        switch responseResult {
        case let .success(data):
            return parseInitializeResponse(data)
        case let .failure(error):
            return .failure(error: error)
        }
    }

    private func readMCPResponse(from handle: FileHandle) async -> Result<Data, MCPHealthCheckError> {
        // Try to read available data
        guard let data = try? handle.availableData, !data.isEmpty else {
            return .failure(.invalidHandshakeResponse(details: "No response received"))
        }

        // Look for Content-Length header in the response
        guard let responseString = String(data: data, encoding: .utf8) else {
            return .failure(.invalidHandshakeResponse(details: "Invalid response encoding"))
        }

        // Find the JSON body (after headers)
        if let headerEnd = responseString.range(of: "\r\n\r\n") {
            let body = String(responseString[headerEnd.upperBound...])
            return .success(Data(body.utf8))
        } else if responseString.hasPrefix("{") {
            // Some servers may not send Content-Length header
            return .success(data)
        }

        return .failure(.invalidHandshakeResponse(details: "Could not parse response"))
    }

    private func parseInitializeResponse(_ data: Data) -> MCPHealthCheckResult.Status {
        struct InitializeResponse: Decodable {
            let jsonrpc: String?
            let id: Int?
            let result: ResultPayload?
            let error: ErrorPayload?

            struct ResultPayload: Decodable {
                let protocolVersion: String?
                let serverInfo: ServerInfo?

                struct ServerInfo: Decodable {
                    let name: String?
                    let version: String?
                }
            }

            struct ErrorPayload: Decodable {
                let code: Int
                let message: String
            }
        }

        do {
            let response = try JSONDecoder().decode(InitializeResponse.self, from: data)

            if let error = response.error {
                return .failure(error: .invalidHandshakeResponse(
                    details: "Error \(error.code): \(error.message)"
                ))
            }

            if let result = response.result {
                return .success(serverInfo: MCPServerInfo(
                    protocolVersion: result.protocolVersion,
                    serverName: result.serverInfo?.name,
                    serverVersion: result.serverInfo?.version
                ))
            }

            // Got a response but couldn't parse result - still consider it a success
            return .success(serverInfo: nil)
        } catch {
            Log.general.debug("Failed to parse MCP response: \(error)")
            // If we got any JSON response, consider the server responsive
            if (try? JSONSerialization.jsonObject(with: data)) != nil {
                return .success(serverInfo: nil)
            }
            return .failure(error: .invalidHandshakeResponse(details: "Invalid JSON response"))
        }
    }

    // MARK: - HTTP Server Check

    private func checkHTTPServer(_ server: MCPServer) async -> MCPHealthCheckResult.Status {
        guard let urlString = server.url,
              let url = URL(string: urlString)
        else {
            return .failure(error: .noCommandOrURL)
        }

        return await withTaskGroup(of: MCPHealthCheckResult.Status.self) { group in
            group.addTask {
                try? await Task.sleep(for: .seconds(self.timeout))
                return .timeout
            }

            group.addTask {
                await self.performHTTPCheck(url: url, headers: server.headers)
            }

            let result = await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func performHTTPCheck(
        url: URL,
        headers: [String: String]?
    ) async -> MCPHealthCheckResult.Status {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        if let headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Create initialize request body
        let initRequest = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":"# +
            #"{"protocolVersion":"2024-11-05","capabilities":{},"# +
            #""clientInfo":{"name":"Fig Health Check","version":"1.0"}}}"#
        request.httpBody = Data(initRequest.utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(error: .httpRequestFailed(statusCode: nil, message: "Invalid response"))
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                return .failure(error: .httpRequestFailed(
                    statusCode: httpResponse.statusCode,
                    message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                ))
            }

            // Try to parse MCP response
            return parseInitializeResponse(data)
        } catch let error as URLError {
            return .failure(error: .networkError(message: error.localizedDescription))
        } catch {
            return .failure(error: .httpRequestFailed(statusCode: nil, message: error.localizedDescription))
        }
    }
}
