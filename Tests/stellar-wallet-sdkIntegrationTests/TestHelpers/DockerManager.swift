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
    private var dockerPath: String?
    private var dockerComposeCommand: [String] = []
    private var isDetectionComplete = false
    private let detectionLock = NSLock()
    
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
        
        // Ensure Docker setup is detected
        await detectDockerSetup()
        
        // Check if Docker is installed
        guard dockerPath != nil && !dockerComposeCommand.isEmpty else {
            throw DockerError.dockerNotInstalled
        }
        
        // Check if docker-compose file exists
        guard FileManager.default.fileExists(atPath: dockerComposePath) else {
            throw DockerError.composeFileNotFound(dockerComposePath)
        }
        
        // Build the complete command arguments
        var arguments = dockerComposeCommand
        arguments.append(contentsOf: [
            "-f", dockerComposePath,
            "-p", projectName,
            "up", "-d"
        ])
        
        // Start services using the detected Docker setup
        let result = await runCommandDirect(arguments)
        
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
        
        // No need to detect again if already running
        var arguments = dockerComposeCommand
        arguments.append(contentsOf: [
            "-f", dockerComposePath,
            "-p", projectName,
            "down"
        ])
        
        let result = await runCommandDirect(arguments)
        
        guard result.exitCode == 0 else {
            throw DockerError.stopFailed(result.error)
        }
        
        isRunning = false
        print("Docker services stopped")
    }
    
    /// Check if a service is healthy
    func isServiceHealthy(_ serviceName: String) async -> Bool {
        // Ensure detection is complete (will only run once)
        if !isDetectionComplete {
            await detectDockerSetup()
        }
        
        var arguments = dockerComposeCommand
        arguments.append(contentsOf: [
            "-f", dockerComposePath,
            "-p", projectName,
            "ps", serviceName
        ])
        
        let result = await runCommandDirect(arguments)
        
        // Check if service is running - Works with both v1 and v2
        return result.exitCode == 0 && (result.output.contains("running") || result.output.contains("healthy") || result.output.contains("Up"))
    }
    
    /// Get logs for a service
    func getServiceLogs(_ serviceName: String, lines: Int = 100) async -> String {
        // Ensure detection is complete (will only run once)
        if !isDetectionComplete {
            await detectDockerSetup()
        }
        
        var arguments = dockerComposeCommand
        arguments.append(contentsOf: [
            "-f", dockerComposePath,
            "-p", projectName,
            "logs", "--tail", "\(lines)", serviceName
        ])
        
        let result = await runCommandDirect(arguments)
        
        return result.output
    }
    
    // MARK: - Private Methods
    
    /// Detect Docker installation and Docker Compose version
    private func detectDockerSetup() async {
        // Use lock to ensure thread-safe detection
        detectionLock.lock()
        defer { detectionLock.unlock() }
        
        // Skip if already detected
        if isDetectionComplete {
            return
        }
        
        // Try common Docker locations when running in Xcode
        let dockerPaths = [
            "/opt/homebrew/bin/docker",  // Apple Silicon Macs with Homebrew
            "/usr/local/bin/docker",      // Intel Macs with Homebrew
            "/usr/bin/docker",             // System location
            "/Applications/Docker.app/Contents/Resources/bin/docker", // Docker Desktop
            "docker"                       // Fallback to PATH
        ]
        
        // Find Docker binary
        for path in dockerPaths {
            let result = await runCommandWithPath(path, arguments: ["--version"])
            if result.exitCode == 0 {
                dockerPath = path
                print("Found Docker at: \(path)")
                break
            }
        }
        
        guard let dockerPath = dockerPath else {
            print("Docker not found in any common location")
            isDetectionComplete = true
            return
        }
        
        // Detect Docker Compose version
        // Try Docker Compose v2 first (docker compose)
        let v2Result = await runCommandWithPath(dockerPath, arguments: ["compose", "version"])
        if v2Result.exitCode == 0 {
            dockerComposeCommand = [dockerPath, "compose"]
            print("Using Docker Compose v2 (docker compose)")
            isDetectionComplete = true
            return
        }
        
        // Try Docker Compose v1 (docker-compose)
        let composeV1Paths = [
            "/opt/homebrew/bin/docker-compose",
            "/usr/local/bin/docker-compose",
            "/usr/bin/docker-compose",
            "docker-compose"
        ]
        
        for composePath in composeV1Paths {
            let result = await runCommandWithPath(composePath, arguments: ["--version"])
            if result.exitCode == 0 {
                dockerComposeCommand = [composePath]
                print("Using Docker Compose v1 at: \(composePath)")
                isDetectionComplete = true
                return
            }
        }
        
        print("Warning: Docker Compose not found. Integration tests may fail.")
        isDetectionComplete = true
    }
    
    /// Run a command using the detected Docker setup
    private func runCommandDirect(_ arguments: [String]) async -> (output: String, error: String, exitCode: Int32) {
        guard !arguments.isEmpty else {
            return ("", "No command provided", -1)
        }
        
        let command = arguments[0]
        let commandArgs = Array(arguments.dropFirst())
        
        return await runCommandWithPath(command, arguments: commandArgs)
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
                var arguments = dockerComposeCommand
                arguments.append(contentsOf: [
                    "-f", dockerComposePath,
                    "-p", projectName,
                    "ps", service
                ])
                
                let psResult = await runCommandDirect(arguments)
                
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
