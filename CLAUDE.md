# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Stellar Swift Wallet SDK, a Swift library for building wallet applications on the Stellar Network. It provides high-level abstractions over the [iOS Stellar SDK](https://github.com/Soneso/stellar-ios-mac-sdk) and implements various Stellar Ecosystem Proposals (SEPs).

## Key Commands

### Building and Testing

```bash
# Build the package
swift build

# Run all tests
swift test

# Run specific test file (e.g., AuthTest)
swift test --filter AuthTest

# Run integration tests with required Docker services
docker-compose -f Tests/docker-compose.test.yml up -d
swift test --filter stellar_wallet_sdkIntegrationTests

# List all available tests
swift test --list-tests
```

### Development Commands

```bash
# Clean build artifacts
swift package clean

# Update package dependencies
swift package update

# Resolve package dependencies
swift package resolve
```

## Architecture

### Core Components

The SDK is organized into several key modules under `Sources/stellar-wallet-sdk/`:

- **`Wallet.swift`**: Main entry point class that provides SDK functionality
- **`anchor/`**: SEP-024 interactive flows and anchor interactions
- **`auth/`**: SEP-010 authentication implementation
- **`recovery/`**: SEP-030 account recovery functionality
- **`quote/`**: SEP-038 quote services
- **`customer/`**: SEP-012 KYC API implementation
- **`uri/`**: SEP-007 URI scheme support
- **`horizon/`**: Stellar network interaction layer

### Configuration System

The SDK uses a layered configuration approach:
- `StellarConfig`: Network configuration (testnet/mainnet)
- `AppConfig`: Application-specific settings
- `Config`: Combined configuration passed to components

### Testing Structure

- **Unit Tests** (`Tests/stellar-wallet-sdkTests/`): Test individual components
- **Integration Tests** (`Tests/stellar-wallet-sdkIntegrationTests/`): Test against real services using Docker containers

The integration tests require Docker services defined in `Tests/docker-compose.test.yml`, which includes:
- Recovery signers (ports 8000, 8002)
- Web authentication servers (ports 8001, 8003)
- PostgreSQL databases for persistence

### Key Design Patterns

1. **Singleton Wallet Pattern**: The `Wallet` class is designed to be used as a singleton across the application
2. **SEP Implementation**: Each SEP is implemented as a separate module with clear interfaces
3. **Async/Await**: Modern Swift concurrency throughout the codebase
4. **Error Handling**: Comprehensive error types in `errors/` directory

## SEP Implementations

The SDK implements the following Stellar Ecosystem Proposals:
- SEP-001: Stellar Info File
- SEP-006: Programmatic deposit/withdrawal
- SEP-007: URI scheme for transaction signing
- SEP-009: Standard KYC fields
- SEP-010: Stellar authentication
- SEP-012: KYC API
- SEP-024: Interactive deposit/withdrawal
- SEP-030: Account recovery
- SEP-038: Quote API

## Dependencies

- **stellarsdk**: The underlying iOS Stellar SDK (v3.2.4+)
- **Swift 5.10+**: Minimum Swift version requirement
- **Platform Support**: iOS 13+, macOS 10.15+