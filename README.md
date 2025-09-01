![logo](./docs/images/wallet-sdk-logo.png)

The Stellar Swift Wallet SDK is a library that allows developers to build wallet applications on the Stellar Network faster. It
utilizes the classic [iOS Stellar SDK](https://github.com/Soneso/stellar-ios-mac-sdk) to communicate with Stellar Horizon and Anchors.

# Installation

Copy the link of the repository (https://github.com/Soneso/stellar-swift-wallet-sdk) and then go to your `Xcode project` -> right click on your project name -> `Add Package Dependencies` … Paste the repository link on the Search, choose the package than click on `Add Package` button. A new screen will shows up, just click `Add Package` button again. Two new Package dependencies will appear: `stellar-wallet-sdk` and `stellarsdk`. The Wallet SDK uses the base [iOS Stellar SDK](https://github.com/Soneso/stellar-ios-mac-sdk).


After installation add following import statement to your swift file:

```swift
import stellar_wallet_sdk
```

## Functionality

The Wallet SDK provides an easy way to communicate with Anchors. It supports:

- [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md)
- [SEP-006](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md)
- [SEP-007](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md)
- [SEP-009](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md)
- [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md)
- [SEP-012](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md)
- [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md)
- [SEP-030](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md)
- [SEP-038](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md)

Furthermore the wallet SDK provides extra functionality on top of the classic iOS Stellar SDK. For interaction with the Stellar Network, the Swift Wallet SDK covers the basics used in a typical wallet flow.


# Getting Started


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

Primary use of the Swift Wallet SDK is to provide an easy way to connect to anchors via sets of protocols known as SEPs. 

Let's look into connecting to the Stellar test anchor:

```swift
let anchor = wallet.anchor(homeDomain: "testanchor.stellar.org")
```

And the most basic interaction of fetching a [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md): Stellar Info File:

```swift
let anchorInfo = try await anchor.info
```

The anchor class also supports [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md): Stellar Authentication, [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md): Hosted Deposit and Withdrawal features, [SEP-012](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md): KYC API and [SEP-009](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md): Standard KYC Fields.

You can read more about working with Anchors in the [respective doc section](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/anchor.md).

## Recovery

[SEP-030](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md) defines the standard way for an individual (e.g., a user or wallet) to regain access to their Stellar account after losing its private key without providing any third party control of the account. During this flow the wallet communicates with one or more recovery signer servers to register the wallet for a later recovery if it's needed.

You can read more about working with Recovery Servers in the [respective doc section](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/recovery.md).

## Quotes

[SEP-038](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md) defines a way for anchors to provide quotes for the exchange of an off-chain asset and a different on-chain asset, and vice versa.

You can read more about requesting quotes in the [respective doc section](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/quotes.md).

## Programmatic Deposit and Withdrawal

The [SEP-06](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md) standard defines a way for anchors and wallets to interact on behalf of users.
Wallets use this standard to facilitate exchanges between on-chain assets (such as stablecoins) and off-chain assets (such as fiat, or other network assets such as BTC).

You can read more about programmatic deposit and withdrawal in the [respective doc section](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/transfer.md).

## URI Scheme to facilitate delegated signing

The [SEP-07](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md) standard defines a way for a non-wallet application to construct a URI scheme that represents a specific transaction for an account to sign. 
The scheme used is `web+stellar`, followed by a colon. Example: `web+stellar:<operation>?<param1>=<value1>&<param2>=<value2>`

You can read more about the SDK's SEP-7 support in the [respective doc section](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/uri.md).

## Documentation and Test Cases

Documentation can be found in the [docs](https://github.com/Soneso/stellar-swift-wallet-sdk/tree/main/docs) folder.

We also recommend that you consult the code examples from the test cases, e.g. in the [Stellar Tests](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/Tests/stellar-wallet-sdkTests/StellarTest.swift) of the SDK.

## Example app

[SwiftBasicPay](https://github.com/Soneso/SwiftBasicPay) is an open-source example iOS payment application that showcases how to integrate Stellar's powerful payment infrastructure into native Swift apps the using the Stellar Swift Wallet SDK and the classic iOS Stellar SDK.

## DeepWiki
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Soneso/stellar-swift-wallet-sdk)
