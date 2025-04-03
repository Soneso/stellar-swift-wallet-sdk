# URI Scheme to facilitate delegated signing

The [SEP-07](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md) standard defines a way for a non-wallet application to construct a URI scheme that represents a specific transaction for an account to sign. The scheme used is `web+stellar`, followed by a colon. Example: `web+stellar:<operation>?<param1>=<value1>&<param2>=<value2>`

## Tx Operation

The tx operation represents a request to sign a specific transaction envelope, with [some configurable parameters](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md#operation-tx).

```swift
let sourceAccountKeypair = try PublicKeyPair(accountId: "G...")
let destinationAccountKeyPair = try PublicKeyPair(accountId: "G...")
let txBuilder = try await stellar.transaction(sourceAddress: sourceAccountKeypair)
let tx = try txBuilder.createAccount(newAccount: destinationAccountKeyPair).build()
let xdr = try tx.encodedEnvelope().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) // url encoded
let callback = "https://example.com/callback".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)  // url encoded
let txUri = "web+stellar:tx?xdr=\(xdr!)&callback=\(callback!)"
let uri = try wallet.parseSep7Uri(uri: txUri)
// uri can be parsed and transaction can be signed/submitted by an application that implements Sep-7
```

You can set replacements to be made in the xdr for specific fields by the application, these will be added in [the Sep-11 transaction representation format](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0011.md) to the URI.

```swift
let uri = try wallet.parseSep7Uri(uri: txUri)

if let uri = uri as? Sep7Tx {
    let replacement = Sep7Replacement(id:"X",
                                      path:"sourceAccount",
                                      hint: "account from where you want to pay fees")

    uri.addReplacement(replacement: replacement)
}
```

You can assign parameters after creating the initial instance using the appropriate setter for the parameter.

```swift
let sourceAccountKeypair = try PublicKeyPair(accountId: "G...")
let destinationAccountKeyPair = try PublicKeyPair(accountId: "G...")
let txBuilder = try await stellar.transaction(sourceAddress: sourceAccountKeypair)
let tx = try txBuilder.createAccount(newAccount: destinationAccountKeyPair).build()

let uri = try Sep7Tx(transaction: tx)
uri.setCallback(callback: "https://example.com/callback")
try uri.setMsg(msg: "here goes a message")
let uriStr = uri.toString() // encodes everything and converts to a uri string
```

## Pay Operation

The pay operation represents a request to pay a specific address with a specific asset, regardless of the source asset used by the payer. You can configure parameters to build the payment operation.

```swift
let destination = "G..."
let assetIssuer = "G..."
let assetCode = "USDC"
let amount = "120.1234567"
let memo = "memo"
let message = "pay me with lumens".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) // url encoded
let originDomain = "example.com"
let payUri = "web+stellar:pay?destination=\(destination)&amount=\(amount)&memo=\(memo)&msg=\(message!)&origin_domain=\(originDomain)&asset_issuer=\(assetIssuer)&asset_code=\(assetCode)"
uri = try Sep7.parseSep7Uri(uri: payUri)
// uri can be parsed and transaction can be built/signed/submitted by an application that implements Sep-7
```

You can assign parameters after creating the initial instance using the appropriate setter for the parameter.

```dart
final uri = Sep7Pay.forDestination('G...');
uri.setCallback('https://example.com/callback');
uri.setMsg('here goes a message');
uri.setAssetCode('USDC');
uri.setAssetIssuer('G...');
uri.setAmount('10');
uri.toString(); // encodes everything and converts to a uri string
```
The last step after building a `Sep7Tx` or `Sep7Pay` is to add a signature to your uri. This will create a payload out of the transaction and sign it with the provided keypair.

```swift
uri = Sep7Pay(destination: "G..")
uri.setOriginDomain(originDomain: "example.com")
let keypair = wallet.stellar.account.createKeyPair()
try uri.addSignature(keyPair: SigningKeyPair(secretKey: keypair.secretKey))
print(uri.getSignature()) // signed uri payload
```

The signature can then be verified by fetching the [Stellar toml file](https://developers.stellar.org/docs/build/apps/example-application-tutorial/anchor-integration/sep1) from the origin domain in the uri, and using the included signing key to verify the uri signature. This is all done as part of the `verifySignature` method.

```swift
let passesVerification = await uri.verifySignature() // true or false
```

## Further readings

Multiple examples can be found in the [SEP-07 test cases](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/Tests/stellar-wallet-sdkTests/UriTest.swift)
