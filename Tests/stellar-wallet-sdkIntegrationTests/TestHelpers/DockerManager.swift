//
//  DockerManager.swift
//  stellar-wallet-sdkIntegrationTests
//
//  Manages Docker containers for integration tests
//

import Foundation
import XCTest

#if os(macOS)
import Darwin

/// Manages Docker containers for integration testing
@available(macOS 10.15, *)
class DockerManager {
    
    static let shared = DockerManager()
    
    private let dockerComposePath: String
    private let projectName = "stellar-wallet-test"
    private var isRunning = false
    
    private init() {
        // Find docker-compose.test.yml in Tests directory
        let testsDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        dockerComposePath = testsDir.appendingPathComponent("docker-compose.test.yml").path
    }
    
    // MARK: - Public Methods
    
    /// Start Docker services
    func startServices() async throws {
        guard !isRunning else { return }
        
        print("Starting Docker services...")
        
        // Check if Docker is installed
        guard await isDockerInstalled() else {
            throw DockerError.dockerNotInstalled
        }
        
        // Check if docker-compose file exists
        guard FileManager.default.fileExists(atPath: dockerComposePath) else {
            throw DockerError.composeFileNotFound(dockerComposePath)
        }
        
        // Start services - use docker compose (v2) instead of docker-compose
        let result = await runCommand(
            "docker",
            arguments: [
                "compose",
                "-f", dockerComposePath,
                "-p", projectName,
                "up", "-d"
            ]
        )
        
        guard result.exitCode == 0 else {
            throw DockerError.startFailed(result.error)
        }
        
        // Wait for services to be healthy
        try await waitForServices()
        
        isRunning = true
        print("Docker services started successfully")
    }
    
    /// Stop Docker services
    func stopServices() async throws {
        guard isRunning else { return }
        
        print("Stopping Docker services...")
        
        let result = await runCommand(
            "docker",
            arguments: [
                "compose",
                "-f", dockerComposePath,
                "-p", projectName,
                "down"
            ]
        )
        
        guard result.exitCode == 0 else {
            throw DockerError.stopFailed(result.error)
        }
        
        isRunning = false
        print("Docker services stopped")
    }
    
    /// Check if a service is healthy
    func isServiceHealthy(_ serviceName: String) async -> Bool {
        let result = await runCommand(
            "docker",
            arguments: [
                "compose",
                "-f", dockerComposePath,
                "-p", projectName,
                "ps", serviceName
            ]
        )
        
        // Check if service is running - Docker Compose v2 uses "running" status
        return result.exitCode == 0 && (result.output.contains("running") || result.output.contains("healthy"))
    }
    
    /// Get logs for a service
    func getServiceLogs(_ serviceName: String, lines: Int = 100) async -> String {
        let result = await runCommand(
            "docker",
            arguments: [
                "compose",
                "-f", dockerComposePath,
                "-p", projectName,
                "logs", "--tail", "\(lines)", serviceName
            ]
        )
        
        return result.output
    }
    
    // MARK: - Private Methods
    
    private func isDockerInstalled() async -> Bool {
        // Try common Docker locations when running in Xcode
        let dockerPaths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker",
            "docker" // fallback to PATH
        ]
        
        for dockerPath in dockerPaths {
            let result = await runCommandWithPath(dockerPath, arguments: ["--version"])
            if result.exitCode == 0 {
                return true
            }
        }
        
        return false
    }
    
    private func runCommandWithPath(_ command: String, arguments: [String]) async -> (output: String, error: String, exitCode: Int32) {
        let process = Process()
        
        // If command contains a path, use it directly
        if command.contains("/") {
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
        } else {
            // Otherwise use env to find it in PATH
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            return (output, error, process.terminationStatus)
        } catch {
            return ("", error.localizedDescription, -1)
        }
    }
    
    private func waitForServices() async throws {
        let services = [
            "recovery-signer1",
            "recovery-signer2",
            "web-auth1",
            "web-auth2"
        ]
        
        let timeout = Date().addingTimeInterval(TestConstants.Timeouts.dockerStartup)
        
        for service in services {
            print("Waiting for \(service) to be healthy...")
            
            while Date() < timeout {
                if await isServiceHealthy(service) {
                    print("\(service) is healthy")
                    break
                }
                
                // Check if service exists and is running
                let psResult = await runCommand(
                    "docker",
                    arguments: [
                        "compose",
                        "-f", dockerComposePath,
                        "-p", projectName,
                        "ps", service
                    ]
                )
                
                if psResult.exitCode != 0 {
                    throw DockerError.serviceNotFound(service)
                }
                
                try await Task.sleep(nanoseconds: UInt64(TestConstants.Timeouts.pollingInterval * 1_000_000_000))
            }
            
            if Date() >= timeout {
                let logs = await getServiceLogs(service)
                throw DockerError.serviceUnhealthy(service, logs: logs)
            }
        }
    }
    
    private func runCommand(_ command: String, arguments: [String]) async -> (output: String, error: String, exitCode: Int32) {
        // Always use full path for docker to avoid PATH issues in Xcode
        var actualCommand = command
        if command == "docker" {
            // Docker is installed at /usr/local/bin/docker
            actualCommand = "/usr/local/bin/docker"
        }
        
        return await runCommandWithPath(actualCommand, arguments: arguments)
    }
}
#endif // End of macOS-only DockerManager

// MARK: - Docker Errors
// DockerError is available on all platforms for consistent API
enum DockerError: LocalizedError {
    case dockerNotInstalled
    case composeFileNotFound(String)
    case startFailed(String)
    case stopFailed(String)
    case serviceNotFound(String)
    case serviceUnhealthy(String, logs: String)
    
    var errorDescription: String? {
        switch self {
        case .dockerNotInstalled:
            return "Docker is not installed. Please install Docker to run integration tests."
        case .composeFileNotFound(let path):
            return "docker-compose.test.yml not found at: \(path)"
        case .startFailed(let error):
            return "Failed to start Docker services: \(error)"
        case .stopFailed(let error):
            return "Failed to stop Docker services: \(error)"
        case .serviceNotFound(let service):
            return "Docker service '\(service)' not found"
        case .serviceUnhealthy(let service, let logs):
            return "Docker service '\(service)' is not healthy. Logs:\n\(logs)"
        }
    }
}

#if !os(macOS)
// Stub implementation for non-macOS platforms
class DockerManager {
    static let shared = DockerManager()
    
    func startServices() async throws {
        throw DockerError.dockerNotInstalled
    }
    
    func stopServices() async throws {
        // No-op on non-macOS platforms
    }
    
    func isServiceHealthy(_ serviceName: String) async -> Bool {
        return false
    }
    
    func getServiceLogs(_ serviceName: String, lines: Int = 100) async -> String {
        return "Docker is not available on this platform"
    }
}
#endif
