# Overview

This tutorial walks through how to use the Stellar Swift Wallet SDK. 

# Getting Started

## Installation

Copy the link of the repository (https://github.com/Soneso/stellar-swift-wallet-sdk) and then go to your `Xcode project` -> right click on your project name -> `Add Package Dependencies` … Paste the repository link on the Search, choose the package than click on `Add Package` button. A new screen will shows up, just click `Add Package` button again. Two new Package dependencies will appear: `stellar-wallet-sdk` and `stellarsdk`. The Wallet SDK uses the base [iOS Stellar SDK](https://github.com/Soneso/stellar-ios-mac-sdk).


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

If you want to find out more about wallet configuration, you can read the details in the documentation under [Wallet Configuration](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/wallet.md).

## Stellar Basics

The wallet SDK provides extra functionality on top of the existing Horizon SDK. For interaction with the Stellar network, the wallet SDK covers only the basics used in a typical wallet flow. For more advanced use cases, the underlying Horizon SDK should be used instead.

To interact with the Horizon instance configured in the previous steps, simply do:

```swift
let stellar = wallet.stellar
```

Please read the [Interacting with Stellar](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/stellar.md) docs of the SDK to find out about all available features such as the account service, building transactions, all available operation types, signing and submitting transactions to Stellar, fetching Stellar Network data via Horizon and more.

## Classic iOS Stellar SDK

The classic [Stellar iOS SDK](https://github.com/Soneso/stellar-ios-mac-sdk) is included as a dependency in the Swift Wallet SDK. 

It's very simple to use the iOS Stellar Stellar SDK connecting to the same Horizon instance as a Wallet class. To do so, simply call:

```swift
let stellar = wallet.stellar
let server = stellar.server
let responseEnum = try await server.transactions.getTransactions(forAccount: accountId)
```

But you can also import and use it for example like this:

```swift
import stellarsdk

let sdk = StellarSDK.testNet()

let accountId = "GASYKQXV47TPTB6HKXWZNB6IRVPMTQ6M6B27IM5L2LYMNYBX2O53YJAL"
let responseEnum = try await sdk.transactions.getTransactions(forAccount: accountId)
```

## Anchor Basics

Primary use of the SDK is to provide an easy way to connect to anchors via sets of protocols known as SEPs such as:

- SEP-1: Stellar Info File
- SEP-10: Stellar Authentication
- SEP-24: Hosted Deposit and Withdrawal
- SEP-6: Programmatic Deposit and Withdrawal
- SEP-12: Providing KYC info
- SEP-38: Quotes
- SEP-30: Recovery

## Chapters

- [Wallet](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/wallet.md)
- [Interaction with the Stellar Network](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/stellar.md)
- [Interaction with Anchors](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/anchors.md)
- [Quotes](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/quotes.md)
- [Programmatic Deposit and Withdrawal](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/transfer.md)
- [Recovery](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/recovery.md)

## Next

Continue with [Wallet](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/wallet.md).
