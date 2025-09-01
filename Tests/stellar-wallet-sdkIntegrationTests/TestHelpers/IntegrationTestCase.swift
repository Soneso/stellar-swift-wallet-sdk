//
//  IntegrationTestCase.swift
//  stellar-wallet-sdkIntegrationTests
//
//  Base class for integration tests with common setup and helper methods
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

/// Base test case class for integration tests
class IntegrationTestCase: XCTestCase {
    
    // Common test properties
    var wallet: Wallet!
    var stellar: Stellar!
    
    // Docker manager
    let dockerManager = DockerManager.shared
    
    // Track if Docker is available
    static var isDockerAvailable = false
    
    // MARK: - Setup & Teardown
    
    override class func setUp() {
        super.setUp()
        
        // Check if Docker services are already running (e.g., started by the script)
        // If SKIP_DOCKER_STARTUP env var is set, assume Docker is already managed externally
        if ProcessInfo.processInfo.environment["SKIP_DOCKER_STARTUP"] != nil {
            print("Docker services managed externally, skipping startup")
            isDockerAvailable = true
            return
        }
        
        // Check Docker availability once for all tests
        let expectation = XCTestExpectation(description: "Check Docker")
        
        Task {
            do {
                try await DockerManager.shared.startServices()
                isDockerAvailable = true
            } catch {
                print("Warning: Docker services not available: \(error)")
                print("Tests requiring Docker will be skipped")
                isDockerAvailable = false
            }
            expectation.fulfill()
        }
        
        // Wait for Docker check with timeout
        _ = XCTWaiter.wait(for: [expectation], timeout: TestConstants.Timeouts.dockerStartup)
    }
    
    override class func tearDown() {
        super.tearDown()
        
        // Don't stop Docker if it's managed externally
        if ProcessInfo.processInfo.environment["SKIP_DOCKER_STARTUP"] != nil {
            return
        }
        
        if isDockerAvailable {
            let expectation = XCTestExpectation(description: "Stop Docker")
            
            Task {
                try? await DockerManager.shared.stopServices()
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: TestConstants.Timeouts.short)
        }
    }
    
    override func setUp() {
        super.setUp()
        
        // Initialize wallet and services
        wallet = Wallet.testNet
        stellar = wallet.stellar
    }
    
    override func tearDown() {
        super.tearDown()
        
        wallet = nil
        stellar = nil
    }
    
    // MARK: - Helper Methods
    
    /// Skip test if Docker is not available
    func requireDocker() throws {
        try XCTSkipUnless(Self.isDockerAvailable, "Docker services not available")
    }
    
    /// Create and fund a test account
    func createAndFundAccount() async throws -> SigningKeyPair {
        let accountKp = stellar.account.createKeyPair()
        
        // Fund account using friendbot
        try await fundAccount(accountId: accountKp.address)
        
        // Verify account exists
        let exists = try await stellar.account.accountExists(accountAddress: accountKp.address)
        if (!exists) {
            throw IntegrationTestError.fundingFailed(accountKp.address)
        }
        
        return accountKp
    }
    
    /// Fund an account using Stellar testnet friendbot
    func fundAccount(accountId: String) async throws {
        try await stellar.fundTestNetAccount(address: accountId)
        
        // Wait a bit for the transaction to be included
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
    
    /// Execute an async operation with retry logic
    func waitForStellarOperation<T>(
        timeout: TimeInterval = TestConstants.Timeouts.medium,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?
        
        while Date() < deadline {
            do {
                return try await operation()
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
        
        throw lastError ?? IntegrationTestError.operationTimeout
    }
    
    /// Run a test with a specific timeout
    func runWithTimeout(
        _ timeout: TimeInterval = TestConstants.Timeouts.medium,
        test: @escaping () async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await test()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw IntegrationTestError.testTimeout(timeout)
            }
            
            // First task to complete wins
            try await group.next()
            group.cancelAll()
        }
    }
}

// MARK: - Integration Test Errors

enum IntegrationTestError: LocalizedError {
    case fundingFailed(String)
    case operationTimeout
    case testTimeout(TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .fundingFailed(let accountId):
            return "Failed to fund account: \(accountId)"
        case .operationTimeout:
            return "Operation timed out"
        case .testTimeout(let timeout):
            return "Test timed out after \(timeout) seconds"
        }
    }
}
