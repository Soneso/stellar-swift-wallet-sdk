# Stellar Swift Wallet SDK Integration Tests

This directory contains integration tests for the Stellar Swift Wallet SDK that test against real network endpoints and Docker-based test services.

## Overview

The integration tests verify the SDK's functionality against:
- **Live Stellar TestNet**: For basic Stellar operations
- **Anchor Platform**: Live anchor at `https://anchor-sep-server-dev.stellar.org/`
- **Docker Services**: Local recovery servers and web authentication services for SEP-30 testing

## Test Structure

```
stellar-wallet-sdkIntegrationTests/
├── TestHelpers/
│   ├── IntegrationTestCase.swift               # Base test class with common utilities
│   ├── DockerManager.swift                     # Docker container management
│   └── TestConstants.swift                     # Test configuration and constants
├── AnchorPlatformIntegrationTests.swift        # SEP-10, 12, 6, 24, 38 tests
├── RecoveryIntegrationTests.swift              # SEP-30 recovery protocol tests
└── README.md                                   # This file
```

## Prerequisites

### Required Software

1. **Swift 5.10+**: Required for building and running tests
2. **Docker Desktop**: Required for SEP-30 recovery tests
   - macOS: [Download Docker Desktop](https://www.docker.com/products/docker-desktop)
   - Ensure Docker is running before running tests
3. **Xcode** (optional): For running tests in IDE or on iOS simulator

### Network Requirements

- Internet connection for Stellar TestNet access
- Access to `https://anchor-sep-server-dev.stellar.org/`
- Local ports 8000-8003 and 5432-5433 available for Docker services

## Running Tests

1. Open the project in Xcode
2. Go to `Tests/stellar-wallet-sdkIntegrationTests`
3. Choose your platform (macOS or iOS Simulator: tests requiring Docker will not run on Simulator)
4. Run tests directly in Xcode, e.g. AnchorPlatformIntegrationTests.swift or RecoveryIntegrationTests.swift

## Docker Services

The `Tests/docker-compose.test.yml` file provides:
- 2 PostgreSQL databases (ports 5432, 5433)
- 2 Recovery signer services (ports 8000, 8002)
- 2 Web authentication services (ports 8001, 8003)

### Finding docker on your mac

`DockerManager.swift` tries to find the docker binary on your mac by searching different locations:

```swift
let dockerPaths = [
    "/opt/homebrew/bin/docker",  // Apple Silicon Macs with Homebrew
    "/usr/local/bin/docker",      // Intel Macs with Homebrew
    "/usr/bin/docker",             // System location
    "/Applications/Docker.app/Contents/Resources/bin/docker", // Docker Desktop
    "docker"                       // Fallback to PATH
]
`

If your docker binary can not be found, docker dependent integration tests will not run. Consider extending `DockerManager.swift` in this case.

## Test Categories

### Anchor Platform Tests (AnchorPlatformIntegrationTests.swift)

Tests the following SEP protocols against a live anchor:

- **SEP-10**: Web Authentication
  - Basic authentication flow
  - Custom auth header support
  
- **SEP-12**: KYC/Customer Information
  - Customer registration
  - Information updates
  
- **SEP-6**: Deposit/Withdrawal
  - Deposit flow with KYC
  - Withdrawal flow with KYC
  
- **SEP-24**: Interactive Deposit/Withdrawal
  - Interactive deposit flow
  - Interactive withdrawal flow
  - Transaction status queries
  
- **SEP-38**: Quotes
  - Price queries
  - Quote creation and retrieval

### Recovery Tests (RecoveryTests.swift)

Tests SEP-30 account recovery with multiple servers:
  
- **Full Account Recovery**
  - Complete recovery flow simulation


## Writing New Integration Tests

### Creating a New Test Class

1. Extend `IntegrationTestCase`:
```swift
final class MyNewTests: IntegrationTestCase {
    // Your tests here
}
```

2. Use helper methods:
```swift
func testMyFeature() async throws {
    // Create and fund account
    let account = try await createAndFundAccount()
    
    // Use retry logic
    let result = try await waitForStellarOperation {
        // Your operation here
    }
}
```

3. Handle Docker requirements:
```swift
func testDockerFeature() async throws {
    try requireDocker() // Skip if Docker not available
    // Your Docker-dependent test
}
```

## Additional Resources

- [Stellar TestNet](https://horizon-testnet.stellar.org/)
- [SEP Protocols Documentation](https://github.com/stellar/stellar-protocol/tree/master/ecosystem)
- [Anchor Platform Documentation](https://developers.stellar.org/docs/anchors)
- [Docker Documentation](https://docs.docker.com/)

## Contributing

When adding new integration tests:
1. Follow the existing test structure
2. Update this README with new test descriptions
3. Add appropriate error handling and timeouts
4. Test on both macOS and iOS platforms when applicable
