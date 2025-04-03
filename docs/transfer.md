# Programmatic Deposit and Withdrawal

The [SEP-06](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md) standard defines a way for anchors and wallets to interact on behalf of users.
Wallets use this standard to facilitate exchanges between on-chain assets (such as stablecoins) and off-chain assets (such as fiat, or other network assets such as BTC).

Please note, this is for _programmatic_ deposits and withdrawals. For hosted deposits and withdrawals,
where the anchor interacts with wallets interactively using a popup, please see [Hosted Deposit and Withdrawal](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/doc/anchor.md).

## Get Anchor Information

Let's start with creating a sep6 object, which we'll use for all SEP-6 interactions:


```swift
let sep6 = anchor.sep6
```

First, let's get information about the anchor's support for [SEP-6].
This request doesn't require authentication, and will return generic info,
such as supported currencies, and features supported by the anchor.
You can get a full list of returned fields in the [SEP-6 specification](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md#info).

```swift
let info = try await sep6.info()
```


## Start a deposit

Before getting started, make sure you have connected to the anchor and received an authentication token,
as described in the [Stellar Authentication] wallet guide.
We will use `authToken` in the examples below as the [SEP-10](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md) authentication token, obtained earlier.

To initiate an operation, we need to know an asset. You can hardcode this.
Ensure it is one that is included in the info response above.

:::info

Before starting with the deposit flow, make sure that the user account has
[established a trustline](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/doc/stellar.md#modify-assets-trustlines) for the asset you are working with.

:::

Let's start with a basic deposit. We will use `accountId` to represent our account's public key.


```swift
let params = Sep6DepositParams(assetCode: assetCode, account: accountId)
let depositResponse = try await anchor.sep6.deposit(params: params, authToken: authToken)
```


There are several kinds of responses, depending on if the anchor needs more information. All deposits and withdrawals will have these same response types:

### 1. Success response

If the response is successful (HTTP 200), then the anchor is processing the deposit. If it needs additional information, it will communicate it when providing the [transaction info](#getting-transaction-info).
                          
```swift
switch depositResponse {
case .depositSuccess(let how, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo, let instructions):
 // ...
}
```

### 2. Still processing, or denied

If an HTTP 403 with data: `customer_info_status` is returned, it means the action is still processing, or not accepted. In this case the `more_info_url` field should have a link describing next steps.

An example response:

```
{
  "type": "customer_info_status",
  "status": "denied",
  "more_info_url": "https://api.example.com/kycstatus?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI"
}
```

In your code:

```swift
switch depositResponse {
case .pending(let status, let moreInfoUrl, let eta):
 // ...
}
```

### 3. Needs more KYC info

Another common response is an HTTP 403, with the response: `non_interactive_customer_info_needed`. In this case the anchor needs more KYC information via [SEP-12](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md).

An example response:

```
{
  "type": "non_interactive_customer_info_needed",
  "fields" : ["family_name", "given_name", "address", "tax_id"]
}
```

Let's show how a wallet can handle this situation. First, we get the deposit response object. If the response includes this error, then we can see which missing fields the anchor is requiring.


```swift
switch depositResponse {
case .missingKYC(let fields):
   //...
}
```

The wallet will need to handle displaying to the user which fields are missing. And then to add those fields, we can use the sep12 class like so.

```swift
let sep12 = try await anchor.sep12(authToken: authToken)

// adding the missing kyc info (sample data)
let sep9Info = [
 "family_name" : "smith",
 "given_name" : "john",
 "address" : "123 street",
 "tax_id": "123",
]

let addResponse = try await sep12.add(sep9Info: sep9Info)
```


Then, we can re-call the deposit method like before and it should be successful.

More information about sending KYC info using [SEP-12](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md) can be found in [Providing KYC info](#providing-kyc-info).

## Providing KYC info

An anchor may respond to a deposit or withdrawal request saying they need additional KYC info. To faciliate this, [SEP-06](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md) supports adding a customer's KYC info via [SEP-12](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md). The user can send in the required info using the sep12 object like below.

Let's add some KYC info for our account using sample data. Binary data (eg. image data), needs to be sent in a separate field. The fields allowed to send to the anchor are described in [SEP-09](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md).


```swift
let sep12 = try await anchor.sep12(authToken: authToken)

let sep9Info = [
    "first_name" : "john",
    "last_name" : "smith",
    "email_address" : "123@gmail.com",
    "bank_number" : "12345",
    "bank_account_number" : "12345",
]

let photoIdFront:Data = // ...
let photoIdBack:Data = // ...

let sep9Files = [
  "photo_id_front": photoIdFront,
  "photo_id_back": photoIdBack,
]

addResponse = try await sep12.add(sep9Info: sep9Info, sep9Files: sep9Files)
```


## Start a withdrawal

Starting a withdrawal is similar to deposit, and has the same response types as described earlier.


```swift
let params = Sep6WithdrawParams(
  assetCode: "SRT",
  account: accountId,
  type: "bank_account",
  dest: "123",
  destExtra: "12345")

let resp = try await anchor.sep6.withdraw(params: withdrawParams, 
                                          authToken: authToken)
```

## Get exchange info

If the anchor supports [SEP-38](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md) quotes, it can support deposits that make a bridge between non-equivalent assets. For example, an anchor recieves BRL via bank transfer and in return sends USDC (of equivalent value minus fees) to the user on Stellar.

The sep6 exchange functions allow a user to start an exchange deposit or withdrawal with the anchor, and the anchor can communicate back next steps to the user.

First, let's start a deposit exchange with sample data. Assets are described using the [SEP-38](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md) scheme.

```swift
let params = Sep6DepositExchangeParams(
  destinationAssetCode: "SRT",
  sourceAssetId: FiatAssetId(id: "USD"),
  amount: "10")

let resp = try await anchor.sep6.depositExchange(params: params, 
                                                authToken: authToken)
```


The response follows the same types as all the deposits and withdrawals for SEP-6.

Now let's create a withdrawal exchange, which follows the same format as the deposit exchange. We also specify it's bank account withdrawal using the `type` field.


```swift
let params = Sep6WithdrawExchangeParams(
  sourceAssetCode: "SRT",
  destinationAssetId: FiatAssetId("USD"),
  amount: "10",
  type: "bank_account")

let resp = try await anchor.sep6.withdrawExchange(params: params, 
                                                  authToken: authToken)
```


The response follows the same types as all the deposits and withdrawals for SEP-6.

## Getting Transaction Info

On the typical flow, the wallet would get transaction data to notify users about status updates. This is done via the [SEP-06](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md) `GET /transaction` and `GET /transactions` endpoint.

### Tracking Transaction

Let's look into how to use the sdk to track transaction status changes. We will use the `Watcher` class for this purpose. First, let's initialize it and start tracking a transaction.

Watch transaction:

```swift
let watcher = anchor.sep6.watcher()
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

Alternatively, we can track multiple transactions for the same asset.

```swift
let watcher = anchor.sep6.watcher()
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

### Fetching Transaction

While `Watcher` class offers powerful tracking capabilities, sometimes it's required to just fetch a transaction (or transactions) once. The `Anchor` class allows you to fetch a transaction by ID, Stellar transaction ID, or external transaction ID:


```swift
let tx = try await anchor.sep6.getTransactionBy(authToken: authToken, 
                                                transactionId:transactionId)
```


It's also possible to fetch transactions by the asset.


```swift
let transactions = try await anchor.sep6.getTransactionsForAsset(authToken: authToken,
                                                                assetCode: assetCode)
```

## Further readings

Multiple examples can be found in the [SEP-06 test cases](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/Tests/stellar-wallet-sdkTests/TransferTest.swift)

## Next

Continue with [SEP-30 Recovery](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/docs/recovery.md