# Overview

This tutorial walks through how to use the Stellar Swift Wallet SDK. 

> **Caution:**
The Stellar Swift Wallet SDK is work in progress and it should not be used on the public network until we publish a stable release.

# Getting Started

## Installation

Copy the link of the repository (https://github.com/Soneso/stellar-swift-wallet-sdk) and then go to your `Xcode project` -> right click on your project name -> `Add Package Dependencies` … Paste the repository link on the Search, choose the package than click on `Add Package` button. A new screen will shows up, just click `Add Package` button again. Two new Package dependencies will appear: `stellar-wallet-sdk` and `stellarsdk`. The Wallet SDK uses the base [iOS Stellar SDK](https://github.com/Soneso/stellar-ios-mac-sdk) (currently from the `await-async` branch).


After installation add following import statement to your swift file:

```swift
import stellar_wallet_sdk
```

## Working with the SDK

Let's start with the main class that provides all SDK functionality. It's advised to have a singleton wallet object shared across the application. Creating a wallet with a default configuration connected to Stellar's Testnet is simple:

```swift
let wallet = Wallet.testNet
```

The wallet instance can be further configured. For example, to connect to the public network:

```swift
let wallet = Wallet(stellarConfig: StellarConfig.publicNet)
```

If you want to find out more about wallet configuration, you can read the details in the documentation under [Wallet Configuration](./docs/wallet.md).

## Stellar Basics

The wallet SDK provides extra functionality on top of the existing Horizon SDK. For interaction with the Stellar network, the wallet SDK covers only the basics used in a typical wallet flow. For more advanced use cases, the underlying Horizon SDK should be used instead.

To interact with the Horizon instance configured in the previous steps, simply do:

```swift
let stellar = wallet.stellar
```

This example will create a Stellar class that manages the connection to Horizon service.

Please read the [Interacting with Stellar](stellar.md) docs of the SDK to find out about all available features such as the account service, building transactions, all available operation types, signing and submitting transactions to Stellar, fetching Stellar Network data via Horizon and more.

## Anchor Basics

Primary use of the SDK is to provide an easy way to connect to anchors via sets of protocols known as SEPs such as:

- SEP-1: Stellar Info File
- SEP-10: Stellar Authentication
- SEP-24: Hosted Deposit and Withdrawal
- SEP-6: Programmatic Deposit and Withdrawal
- SEP-12: Providing KYC info
- SEP-38: Quotes

This functionality is not yet implemented. We will provide all details as soon as it is ready. Stay tuned!

## Chapters

- [Wallet](wallet.md)
- [Interaction with the Stellar Network](stellar.md)
- [Interaction with Anchors](anchors.md)

## Next

Continue with [Wallet](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/wallet.md).
