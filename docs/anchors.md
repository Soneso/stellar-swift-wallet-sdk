# Interacting with Anchors

Build on and off ramps with anchors for deposits and withdrawals:

```swift
let anchor = wallet.anchor(homeDomain: "testanchor.stellar.org")
```

Get anchor information from a TOML file  using [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md):

```swift
let anchorInfo = try await anchor.info
```

Upload KYC information to anchors using [SEP-012](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md):

```swift
// not yet implemented
```

Authenticate an account with the anchor using [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md):

```swift
let authToken = try await anchor.sep10.authenticate(userKeyPair: accountKeyPair)
```

Available anchor services and information about them. For example, interactive deposit/withdrawal limits, currency, fees, payment methods
using [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md):

```swift
let sep24Info = try await anchor.sep24.info
```

Interactive deposit and withdrawal using [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md):

```swift
let depositResponse = try await anchor.sep24.deposit(assetId: asset, authToken: authToken)
let interactiveUrl = depositResponse.url
```

```swift
let withdrawResponse = try await anchor.sep24.withdraw(assetId: asset, authToken: authToken)
let interactiveUrl = withdrawResponse.url
```

Deposit with extra [SEP-009](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md) fields and/or files:

```dart
let sep9Fields:[String:String] = [Sep9PersonKeys.emailAddress : "mail@example.com",
                                  Sep9PersonKeys.mobileNumber : "+12383844421"]

let photoIdFront = try Data(contentsOf: path)
let sep9Files:[String:Data] = [Sep9PersonKeys.photoIdFront:photoIdFront]

let depositResponse = try await anchor.sep24.deposit(assetId: asset, 
                                                     authToken: authToken,
                                                     extraFields: sep9Fields,
                                                     extraFiles: sep9Files)

let interactiveUrl = depositResponse.url
```

Deposit with alternative account:

```swift
let recepientAccountId = "G..."
depositResponse = try await anchor.sep24.deposit(assetId: usdcAssetId,
                                                 authToken: authToken,
                                                 destinationAccount: recepientAccountId)
```

Get single transaction's current status and details:

```swift
let transaction = try await anchor.sep24.getTransactionBy(authToken: authToken,
                                                          transactionId:"12345")
```

Get transaction by stellar transaction id:

```swift
let transaction = try await anchor.sep24.getTransactionBy(authToken: authToken,
                                                          stellarTransactionId: "17a670bc424ff...")
```

Get transaction by external transaction id:

```swift
let transaction = try await anchor.sep24.getTransactionBy(authToken: authToken,
                                                          externalTransactionId: "9198278372")
```

Get account transactions for specified asset:

```swift

let transactions = try await anchor.sep24.getTransactionsForAsset(authToken: authToken,
                                                                  asset: asset)
```

Watch transaction:

```swift
let watcher = anchor.sep24.watcher()
let result = watcher.watchOneTransaction(authToken: token, 
                                         id: "transaction id")

NotificationCenter.default.addObserver(self,
                                       selector: #selector(handleEvent(_:)),
                                       name: result.notificationName,
                                       object: nil)
                                       
/// ...
@objc public func handleEvent(_ notification: Notification) {
    if let statusChange = notification.object as? StatusChange {
        print("Status change to \(statusChange.status.rawValue). Transaction: \(statusChange.transaction.id)")
    } else if let _ = notification.object as? ExceptionHandlerExit {
        print("Exception handler exited the job")
    } else if let _ = notification.object as? NotificationsClosed {
        print("Notifications closed. Job is done")
    }
}
```

Watch asset:

```swift
let watcher = anchor.sep24.watcher()
let result = watcher.watchAsset(authToken: token, 
                                asset: asset)

NotificationCenter.default.addObserver(self,
                                       selector: #selector(handleEvent(_:)),
                                       name: result.notificationName,
                                       object: nil)
                                       
/// ...
@objc public func handleEvent(_ notification: Notification) {
    if let statusChange = notification.object as? StatusChange {
        print("Status change to \(statusChange.status.rawValue). Transaction: \(statusChange.transaction.id)")
    } else if let _ = notification.object as? ExceptionHandlerExit {
        print("Exception handler exited the job")
    } else if let _ = notification.object as? NotificationsClosed {
        print("Notifications closed. Job is done")
    }
}
```

Examples can be found in the [InteractiveFlowTest](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/Tests/stellar-wallet-sdkTests/InteractiveFlowTest.swift).

## Add client domain signing

Supporting `client_domain` comes in two parts, the wallet's client and the wallet's server implementations. 
In this setup, we will have an extra authentication key. This key will be stored remotely on the server. 
Using the [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md) info file, 
the anchor will be able to query this key and verify the signature. As such, the anchor would be able to confirm
that the request is coming from your wallet, belonging to wallet's `client_domain`.

### Client Side

First, let's implement the client side. In this example we will connect to a remote signer that 
signs transactions on the endpoint `https://demo-wallet-server.stellar.org/sign` for the client domain `demo-wallet-server.stellar.org`.

```swift
let signer = try DomainSigner(url: "https://demo-wallet-server.stellar.org/sign")
let sep10 = try await anchor.sep10

let authToken = try await sep10.authenticate(userKeyPair: userKeyPair,
                                            clientDomain: "demo-wallet-server.stellar.org",
                                            clientDomainSigner: signer)
```

Danger: The demo-wallet signing endpoint is not protected for anybody to use. Your production URL must be protected, otherwise anybody could impersonate your wallet's user.

Let's add authentication with a bearer token. Simply pass the needed request headers with your token:

```swift
let requestHeaders = ["Authorization" : "Bearer 123456789"]

let signer = try DomainSigner(url: "https://demo-wallet-server.stellar.org/sign" , 
                              requestHeaders: ["Authorization" : "Bearer 123456789"])
```
### Server Side

Next, let's implement the server side.

First, generate a new authentication key that will be used as a `client_domain` authentication key.

Next, create a [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md)
`toml` file placed under `<your domain>/.well-known/stellar.toml` with the following content:

````toml
ACCOUNTS = [ "Authentication public key (address)" ]
VERSION = "0.1.0"
SIGNING_KEY = "Authentication public key (address)"
NETWORK_PASSPHRASE = "Test SDF Network ; September 2015"
````

Don't forget to change the network passphrase for Mainnet deployment.

Finally, let's add a server implementation. This sample implementation uses express framework:

```javascript
app.post("/sign", (req, res) => {
  const envelope_xdr = req.body.transaction;
  const network_passphrase = req.body.network_passphrase;
  const transaction = new Transaction(envelope_xdr, network_passphrase);

  if (Number.parseInt(transaction.sequence, 10) !== 0) {
    res.status(400);
    res.send("transaction sequence value must be '0'");
    return;
  }

  transaction.sign(Keypair.fromSecret(SERVER_SIGNING_KEY));

  res.set("Access-Control-Allow-Origin", "*");
  res.status(200);
  res.send({
    transaction: transaction.toEnvelope().toXDR("base64"),
    network_passphrase: network_passphrase,
  });
});
```

The `DomainSigner` will request remote signing at the given endpoint by posting a request that contains a json with 
the `transaction` and `network_passphrase`. On the server side you can now sign the transaction with the client
keypair and send it back as a result. As mentioned before, this sample implementation doesn't have any protection
against unauthorized requests, so you must add authorization checks as part of the request.

An example client implementation can be found in the [AuthTest](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/Tests/stellar-wallet-sdkTests/AuthTest.swift). 
The test uses an example server implementation that can be found [here](https://replit.com/@crogobete/ClientDomainSigner#main.py).




