# Interacting with the Stellar Network


In the previous section we learned how to create a wallet and a `Stellar` object that provides a connection to Horizon. 

```swift
let wallet = Wallet.testNet
let stellar = wallet.stellar
```

In this section, we will look at the usages of this class.

## Accounts

The most basic entity on the Stellar network is an account. Let's look into `AccountService` that provides the capability to work with accounts:

```swift
let account = wallet.stellar.account
```

Now we can create a keypair:

```swift
let accountKeyPair = account.createKeyPair()
```

## Build Transaction

The transaction builder allows you to create various transactions that can be signed and submitted to the Stellar network. Some transactions can be sponsored.

### Building Basic Transactions

First, let's look into building basic transactions.

#### Create Account

The create account transaction activates/creates an account with a starting balance of XLM (1 XLM by default).

```swift
let txBuilder = try await stellar.transaction(
    sourceAddress: sourceAccountKeyPair)

let tx = try txBuilder.createAccount(
    newAccount: destinationAccountKeyPair).build()
```

#### Modify Account

You can lock the master key of the account by setting its weight to 0. Use caution when locking the account's master key. Make sure you have set the correct signers and weights. Otherwise, you will lock the account irreversibly.

```swift
let txBuilder = try await stellar.transaction(
    sourceAddress: sourceAccountKeyPair)

let tx = txBuilder.lockAccountMasterKey().build()
```

Add a new signer to the account. Use caution when adding new signers and make sure you set the correct signer weight. Otherwise, you will lock the account irreversibly.

```swift
let newSignerKeyPair = account.createKeyPair()

let tx = txBuilder.addAccountSigner(
    signerAddress: newSignerKeyPair,
    signerWeight: 10).build()
```

Remove a signer from the account.

```swift
let tx = txBuilder.removeAccountSigner(
    signerAddress: newSignerKeyPair).build()
```

Modify account thresholds (useful when multiple signers are assigned to the account). This allows you to restrict access to certain operations when the limit is not reached.

```swift
let tx = txBuilder.setThreshold(low: 1, medium: 10, high: 30).build()
```

#### Modify Assets (Trustlines)

Add an asset (trustline) to the account. This allows the account to receive transfers of the asset.

```swift
let asset = try IssuedAssetId(
    code: "USDC",
    issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5")
    
let tx = txBuilder.addAssetSupport(asset: asset).build()
```

Remove an asset from the account (the asset's balance must be 0).

```swift
let tx = txBuilder.removeAssetSupport(asset: asset).build()
```

#### Swap

Exchange an account's asset for a different asset. The account must have a trustline for the destination asset.

```swift
let txBuilder = try await stellar.transaction(sourceAddress: sourceKp)

let usdcAsset = try IssuedAssetId(
    code: "USDC",
    issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5"
)

let txn = try txBuilder.swap(
    fromAsset: NativeAssetId(),
    toAsset: usdcAsset,
    amount: 0.1).build()
```

#### Path Pay

Send one asset from the source account and receive a different asset in the destination account.

```swift
let txBuilder = try await stellar.transaction(sourceAddress: sourceKp)

let usdcAsset = try IssuedAssetId(
    code: "USDC",
    issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5"
)

let txn = try txBuilder.pathPay(
    destinationAddress: receivingKp.address,
    sendAsset: NativeAssetId(),
    destinationAsset: usdcAsset,
    sendAmount: 5).build();
```

#### Set Memo

Set a memo on the transaction. The memo object can be imported from the base `stellarsdk`.

```swift
import stellarsdk

let tx = txBuilder.setMemo(memo: Memo.text("Memo string")).build()
```

#### Account Merge

Merges account into a destination account.

```swift
let txBuilder = try await stellar.transaction(
    sourceAddress: accountKp,
    baseFee: 1000)
    
let mergeTxn = try txBuilder.accountMerge(
    destinationAddress: accountKp.address,
    sourceAddress: sourceKp.address).build()
```

#### Fund Testnet Account

Fund an account on the Stellar test network

```swift
try await wallet.stellar.fundTestNetAccount(
    address: accountKeyPair.address)
```

### Building Advanced Transactions

In some cases a private key may not be known prior to forming a transaction. For example, a new account must be funded to exist and the wallet may not have the key for the account so may request the create account transaction to be sponsored by a third party.

```swift
// Third-party key that will sponsor creating new account
let externalKeyPair = try PublicKeyPair.init(accountId: "GC5GD...")
let newKeyPair = account.createKeyPair()
```

First, the account must be created.

```swift
let createTxn = try txBuilder.createAccount(
    newAccount: newKeyPair).build()
```

This transaction must be sent to external signer (holder of externalKeyPair) to be signed.

```swift
let xdrString = createTxn.toEnvelopeXdrBase64()

// Send xdr encoded transaction to your backend server to sign
let xdrStringFromBackend = try await sendTransactionToBackend(xdr:xdrString)

// Decode xdr to get the signed transaction
let signedTransactionEnum = stellar.decodeTransaction(xdr: xdrStringFromBackend)
```

Signed transaction can be submitted by the wallet.

```swift
switch signedTransactionEnum {
case .transaction(let tx):
    // submit transaction
    let success = try await stellar.submitTransaction(signedTransaction: tx)
    XCTAssertTrue(success)
case .feeBumpTransaction(_):
    // ...
case .invalidXdrErr:
    // ...
}
```

Now, after the account is created, it can perform operations. For example, we can disable the master keypair and replace it with a new one (let's call it the device keypair) atomically in one transaction:

```swift
let deviceKeyPair = account.createKeyPair()

let txBuilder = try await stellar.transaction(sourceAddress:newKeyPair)
let modifyAccountTransaction = try txBuilder
    .addAccountSigner(signerAddress: deviceKeyPair, signerWeight: 1)
    .lockAccountMasterKey()
    .build()

stellar.sign(tx: modifyAccountTransaction, keyPair: newKeyPair)

let success = try await stellar
    .submitTransaction(signedTransaction: modifyAccountTransaction)
```

### Adding an operation

Add a custom Operation to a transaction. This can be any Operation supported by the Stellar network. The Operation object can be imported the base `stellarsdk`.

```swift
import stellarsdk

let txBuilder = try await stellar.transaction(
    sourceAddress:sourceAccountKeyPair)
    
let tx = txBuilder.addOperation(
    operation: ManageDataOperation(
        sourceAccountId:sourceAccountKeyPair.address,
        name: "web_auth_domain",
        data: "https://testanchor.stellar.org".data(using: .utf8)
    )
)
```

### Sponsoring Transactions

### Sponsoring Operations

Some operations, that modify account reserves can be [sponsored](https://developers.stellar.org/docs/learn/encyclopedia/transactions-specialized/sponsored-reserves#sponsored-reserves-operations). For sponsored operations, the sponsoring account will be paying for the reserves instead of the account that being sponsored. This allows you to do some operations, even if account doesn't have enough funds to perform such operations. To sponsor a transaction, simply create a building function (describing which operations are to be sponsored) and pass it to the `sponsoring` method:

```swift
let txBuilder = try await stellar.transaction(
    sourceAddress:sponsoredKeyPair)
    
let tx = try txBuilder.sponsoring(
    sponsorAccount: sponsorKeyPair,
    buildingFunction: { (builder) in builder.lockAccountMasterKey()}).build()

// sign transaction
stellar.sign(tx: tx, keyPair: sponsorKeyPair)
stellar.sign(tx: tx, keyPair: sponsoredKeyPair)
```

*Info: Only some operations can be sponsored, and a sponsoring builder has a slightly different set of functions available compared to the regular `TxBuilder`. Note, that a transaction must be signed by both the sponsor account (`sponsoringKeyPair`) and the account being sponsored (`sponsoredKeyPair`).*

### Sponsoring Account Creation

One of the things that can be done via sponsoring is to create an account with a 0 starting balance. This account creation can be created by simply writing:

```swift
let txBuilder = try await stellar.transaction(
    sourceAddress:sponsorKeyPair)

let newKeyPair = account.createKeyPair()

let tx = try txBuilder.sponsoring(
    sponsorAccount: sponsorKeyPair,
    buildingFunction: { (builder) in builder.createAccount(newAccount: newKeyPair)},
    sponsoredAccount: newKeyPair).build()

// sign transaction
stellar.sign(tx: tx, keyPair: newKeyPair)
stellar.sign(tx: tx, keyPair: sponsorKeyPair)
```

Note how in the first example the transaction source account is set to `sponsoredKeyPair`. Due to this, we did not need to pass a sponsored account value to the `sponsoring` method. Since when ommitted, the sponsored account defaults to the transaction source account (`sponsoredKeyPair`).

However, this time, the sponsored account (freshly created `newKeyPair`) is different from the transaction source account. Therefore, it's necessary to specify it. Otherwise, the transaction will contain a malformed operation. As before, the transaction must be signed by both keys.

### Sponsoring Account Creation and Modification

If you want to create an account and modify it in one transaction, it's possible to do so with passing a `sponsoredAccount` optional argument to the sponsoring method (`newKeyPair` below). If this argument is present, all operations inside the sponsored block will be sourced by this `sponsoredAccount`. (Except account creation, which is always sourced by the sponsor).

```swift
let txBuilder = try await stellar.transaction(
    sourceAddress:sponsorKeyPair)

let newKeyPair = account.createKeyPair()
let replaceWith = account.createKeyPair()

let tx = try txBuilder.sponsoring(
    sponsorAccount: sponsorKeyPair,
    buildingFunction: {(builder) in builder.createAccount(newAccount: newAccountKeyPair)
                                            .addAccountSigner(signerAddress: replaceWith, signerWeight: 1)
                                            .lockAccountMasterKey()},
    sponsoredAccount: newAccountKeyPair).build()

// sign transaction
stellar.sign(tx: tx, keyPair: newKeyPair)
stellar.sign(tx: tx, keyPair: sponsorKeyPair)
```

## Fee-Bump Transaction

If you wish to modify a newly created account with a 0 balance, it's also possible to do so via FeeBump. It can be combined with a sponsoring method to achieve the same result as in the example above. However, with FeeBump it's also possible to add more operations (that don't require sponsoring), such as a transfer.

First, let's create a transaction that will replace the master key of an account with a new keypair.

```swift
let txBuilder = try await stellar.transaction(
    sourceAddress:sponsoredKeyPair)

let replaceWith = account.createKeyPair()

let transaction = try txBuilder.sponsoring(
    sponsorAccount: sponsorKeyPair,
    buildingFunction: {(builder) in builder.lockAccountMasterKey()
                                            .addAccountSigner(signerAddress: replaceWith, signerWeight: 1)}).build()
```

Second, sign transaction with both keys.

```swift
stellar.sign(tx: transaction, keyPair: sponsorKeyPair)
stellar.sign(tx: transaction, keyPair: sponsoredKeyPair)
```

Next, create a fee bump, targeting the transaction.

```swift
let feeBump = try stellar.makeFeeBump(feeAddress: sponsorKeyPair, transaction: transaction)
stellar.sign(feeBumpTx: feeBump, keyPair: sponsorKeyPair)
```

Finally, submit a fee-bump transaction. Executing this transaction will be fully covered by the `sponsorKeyPair` and `sponsoredKeyPair` and may not even have any XLM funds on its account.

```swift
let success = try await stellar.submitTransaction(signedFeeBumpTransaction: feeBump)
```

## Using XDR to Send Transaction Data

Note, that a wallet may not have a signing key for `sponsorKeyPair`. In that case, it's necessary to convert the transaction to XDR, send it to the server, containing `sponsorKey` and return 
the signed transaction back to the wallet. Let's use the previous example of sponsoring account creation, but this time with the sponsor key being unknown to the wallet. 
The first step is to define the public key of the sponsor keypair:

```swift
let sponsorKeyPair = try PublicKeyPair(accountId: "GC5GD...")
```

Next, create an account in the same manner as before and sign it with `newKeyPair`. This time, convert the transaction to XDR:

```swift
let newKeyPair = account.createKeyPair()
        
let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
let transaction = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair, 
                                            buildingFunction: { (builder) in builder.createAccount(newAccount: newKeyPair)},
                                            sponsoredAccount: newKeyPair).build()
        
stellar.sign(tx: transaction, keyPair: newKeyPair)
        
let xdrString = sponsorAccountCreationTx.toEnvelopeXdrBase64()
```

It can now be sent to the server. On the server, sign it with a private key for the sponsor address:

```swift
private func signTransaction(xdrString:String) throws -> String {
    let sponsorPrivateKey = try SigningKeyPair(secretKey: "SD3LH4...")
    let transactionEnum = stellar.decodeTransaction(xdr: xdrString)
    switch transactionEnum {
    case .transaction(let tx):
        stellar.sign(tx: tx, keyPair: sponsorPrivateKey)
        return tx.toEnvelopeXdrBase64()
    case .feeBumpTransaction(let feeBumpTx):
        stellar.sign(feeBumpTx: feeBumpTx, keyPair: sponsorPrivateKey)
        return feeBumpTx.toEnvelopeXdrBase64()
    case .invalidXdrErr:
        throw ValidationError.invalidArgument(message: "invalid envelope xdr")
    }
}
```

When the client receives the fully signed transaction, it can be decoded and sent to the Stellar network:

```swift
let signedTransaction = stellar.decodeTransaction(xdr: xdrStringFromBackend)
switch signedTransaction {
case .transaction(let tx):
    // submit transaction
    let success = try await stellar.submitTransaction(signedTransaction: tx)
case .feeBumpTransaction(let feeBumpTx):
    // ...
case .invalidXdrErr:
    // ...
}
```

## Submit Transaction

*Info: It's strongly recommended to use the wallet SDK transaction submission functions instead of Horizon alternatives. The wallet SDK gracefully handles timeout and out-of-fee exceptions.*

Finally, let's submit a signed transaction to the Stellar network. Note that a sponsored transaction must be signed by both the account and the sponsor.

The transaction is automatically re-submitted on the Horizon 504 error (timeout), which indicates a sudden network activity increase.

```swift
stellar.sign(tx: tx, keyPair: sourceAccountKeyPair)
let success = try await stellar
    .submitTransaction(signedTransaction: tx)
```

However, the method above doesn't handle fee surge pricing in the network gracefully. If the required fee for a transaction to be included in the ledger becomes too high and transaction expires before making it into the ledger, this method will throw an exception.

So, instead, the alternative approach is to `submitWithFeeIncrease`:

```swift
let success = 
try await stellar.submitWithFeeIncrease(sourceAddress: sourceAccountKeyPair, 
                                        timeout: 30,
                                        baseFeeIncrease: 100,
                                        maxBaseFee: 2000,
                                        buildingFunction: {
                                             (builder) in try! builder.transfer(destinationAddress: account2KeyPair.address, 
                                                                                assetId: NativeAssetId(),
                                                                                amount: 10.0)})
```

This will create and sign the transaction that originated from the `sourceAccountKeyPair`. Every 30 seconds this function will re-construct this transaction with a new fee (increased by 100 stroops), repeating signing and submitting. Once the transaction is successful, the function will return the transaction body. Note, that any other error will terminate the retry cycle and an exception will be thrown.


## Accessing Horizon SDK

It's very simple to use the Horizon SDK connecting to the same Horizon instance as a `Wallet` class. To do so, simply call:

```swift
let server = wallet.stellar.server
```

And you can work with Horizon Server instance:

```swift
let stellarTransactions = await server.transactions.getTransactions(forAccount: "account_id")
```

## Next

Continue with [Interacting with Anchors](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/anchors.md).

