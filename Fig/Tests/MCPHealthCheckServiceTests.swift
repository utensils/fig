@testable import Fig
import Foundation
import Testing

// MARK: - MCPHealthCheckResult Tests

@Suite("MCPHealthCheckResult Tests")
struct MCPHealthCheckResultTests {
    @Test("Success result reports isSuccess true")
    func successIsSuccess() {
        let result = MCPHealthCheckResult(
            serverName: "test",
            status: .success(serverInfo: nil),
            duration: 0.5
        )
        #expect(result.isSuccess == true)
    }

    @Test("Failure result reports isSuccess false")
    func failureIsNotSuccess() {
        let result = MCPHealthCheckResult(
            serverName: "test",
            status: .failure(error: .noCommandOrURL),
            duration: 0.1
        )
        #expect(result.isSuccess == false)
    }

    @Test("Timeout result reports isSuccess false")
    func timeoutIsNotSuccess() {
        let result = MCPHealthCheckResult(
            serverName: "test",
            status: .timeout,
            duration: 10.0
        )
        #expect(result.isSuccess == false)
    }

    @Test("Success with server info preserves details")
    func successWithServerInfo() {
        let info = MCPServerInfo(
            protocolVersion: "2024-11-05",
            serverName: "my-server",
            serverVersion: "1.2.3"
        )
        let result = MCPHealthCheckResult(
            serverName: "test",
            status: .success(serverInfo: info),
            duration: 0.3
        )
        #expect(result.isSuccess == true)
        if case let .success(serverInfo) = result.status {
            #expect(serverInfo?.serverName == "my-server")
            #expect(serverInfo?.serverVersion == "1.2.3")
            #expect(serverInfo?.protocolVersion == "2024-11-05")
        } else {
            Issue.record("Expected success status")
        }
    }
}

// MARK: - MCPHealthCheckError Tests

@Suite("MCPHealthCheckError Tests")
struct MCPHealthCheckErrorTests {
    @Test("All error cases have descriptions")
    func allErrorsHaveDescriptions() {
        let errors: [MCPHealthCheckError] = [
            .processSpawnFailed(underlying: "not found"),
            .processExitedEarly(code: 1, stderr: "error"),
            .invalidHandshakeResponse(details: "bad response"),
            .httpRequestFailed(statusCode: 500, message: "server error"),
            .httpRequestFailed(statusCode: nil, message: "unknown"),
            .networkError(message: "timeout"),
            .timeout,
            .noCommandOrURL,
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("All error cases have recovery suggestions")
    func allErrorsHaveRecoverySuggestions() {
        let errors: [MCPHealthCheckError] = [
            .processSpawnFailed(underlying: "not found"),
            .processExitedEarly(code: 1, stderr: "error"),
            .invalidHandshakeResponse(details: "bad response"),
            .httpRequestFailed(statusCode: 500, message: "server error"),
            .networkError(message: "timeout"),
            .timeout,
            .noCommandOrURL,
        ]

        for error in errors {
            #expect(error.recoverySuggestion != nil)
            #expect(!error.recoverySuggestion!.isEmpty)
        }
    }
}

// MARK: - MCPHealthCheckService Stdio Tests

@Suite("MCPHealthCheckService Stdio Tests")
struct MCPHealthCheckServiceStdioTests {
    @Test("Returns failure for server with no command or URL")
    func noCommandOrURL() async {
        let service = MCPHealthCheckService()
        let server = MCPServer()
        let result = await service.checkHealth(name: "empty", server: server)

        #expect(result.isSuccess == false)
        if case let .failure(error) = result.status {
            if case .noCommandOrURL = error {
                // Expected
            } else {
                Issue.record("Expected noCommandOrURL, got \(error)")
            }
        } else {
            Issue.record("Expected failure with noCommandOrURL")
        }
    }

    @Test("Successful health check against echo-based stdio server")
    func stdioEchoServer() async {
        let service = MCPHealthCheckService()
        // Use cat which echoes stdin to stdout - it will echo back our request
        // which is valid JSON, so the health check should parse it as a success
        let server = MCPServer.stdio(command: "cat")
        let result = await service.checkHealth(name: "cat-test", server: server)

        // cat echoes back the request, which contains valid JSON with no "error" field
        // and no "result" field, so it should be treated as success (any JSON = responsive)
        #expect(result.isSuccess == true)
    }

    @Test("Returns failure for non-existent command")
    func nonExistentCommand() async {
        let service = MCPHealthCheckService()
        let server = MCPServer.stdio(
            command: "/nonexistent/command/that/does/not/exist"
        )
        let result = await service.checkHealth(name: "bad-cmd", server: server)

        #expect(result.isSuccess == false)
    }

    @Test("Returns failure for command that exits immediately")
    func commandExitsImmediately() async {
        let service = MCPHealthCheckService()
        let server = MCPServer.stdio(command: "false")
        let result = await service.checkHealth(name: "false-cmd", server: server)

        #expect(result.isSuccess == false)
        if case let .failure(error) = result.status {
            if case .processExitedEarly = error {
                // Expected
            } else {
                Issue.record("Expected processExitedEarly, got \(error)")
            }
        }
    }

    @Test("Duration is recorded")
    func durationRecorded() async {
        let service = MCPHealthCheckService()
        let server = MCPServer.stdio(command: "cat")
        let result = await service.checkHealth(name: "duration-test", server: server)

        #expect(result.duration > 0)
    }

    @Test("Server name is preserved in result")
    func serverNamePreserved() async {
        let service = MCPHealthCheckService()
        let server = MCPServer.stdio(command: "cat")
        let result = await service.checkHealth(name: "my-custom-name", server: server)

        #expect(result.serverName == "my-custom-name")
    }
}
