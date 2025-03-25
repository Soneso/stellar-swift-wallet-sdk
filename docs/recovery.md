
# Recovery

The [SEP-030](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md) standard defines
the standard way for an individual (e.g., a user or wallet) to regain access to their Stellar account after losing
its private key without providing any third party control of the account. During this flow the wallet communicates
with one or more recovery signer servers to register the wallet for a later recovery if it's needed.

## Create Recoverable Account

First, let's create an account key, a device key, and a recovery key that will be attached to the account.

```swift
let accountKp = wallet.stellar.account.createKeyPair()
let deviceKp = wallet.stellar.account.createKeyPair()
var recoveryKp = wallet.stellar.account.createKeyPair()
```
The `accountKp` is the wallet's main account. The `deviceKp` we will be adding to the wallet as a signer so a device (eg. a mobile device a wallet is hosted on) can take control of the account.
And the `recoveryKp` will be used to identify the key with the recovery servers.

Next, let's identify the recovery servers and create our recovery object:

```swift
let first = RecoveryServerKey(name: "first")
let second = RecoveryServerKey(name: "second")

let firstServer = RecoveryServer(endpoint:"https://recovery.example1.com", 
                                authEndpoint:"https://auth.example1.com", 
                                homeDomain:"recovery.example1.com")

let secondServer = RecoveryServer(endpoint:"https://recovery.example2.com", 
                                  authEndpoint:"https://auth.example2.com", 
                                  homeDomain:"recovery.example2.com")

let servers = [first: firstServer, second:secondServer]

let recovery = wallet.recovery(servers: servers)
```

Next, we need to define SEP-30 identities. In this example we are going to create an identity for both servers. Registering an identity tells the recovery server what identities are allowed to access the account.

```swift
let identity1 = [ 
    RecoveryAccountIdentity(role:RecoveryRole.owner, 
                            authMethods: [RecoveryAccountAuthMethod(type:RecoveryType.stellarAddress,
                                                                    value:recoveryKp.address)])
]

let identity2 = [ 
    RecoveryAccountIdentity(role:RecoveryRole.owner, 
                            authMethods: [RecoveryAccountAuthMethod(type:RecoveryType.email,
                                                                    value:"my-email@example.com")])
]
```

Here, stellar key and email are used as recovery methods. Other recovery servers may support phone as a recovery method as well.

You can read more about SEP-30 identities [here](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md#common-request-fields)

Next, let's create a recoverable account:

```swift
let config = RecoverableWalletConfig(accountAddress: accountKp,
                                    deviceAddress: deviceKp,
                                    accountThreshold: AccountThreshold(low: 10, medium: 10, high: 10),
                                    accountIdentity: [first : identity1, second: identity2],
                                    signerWeight: SignerWeight(device: 10, recoveryServer: 5))

let recoverableWallet = try await recovery.createRecoverableWallet(config: config)
```

With the given parameters, this function will create a transaction that will:

1. Set `deviceKp` as the primary account key. Please note that the master key belonging to `accountKp` will be locked. deviceKp should be used as a primary signer instead.
2. Set all operation thresholds to 10. You can read more about threshold in the [documentation](https://developers.stellar.org/docs/encyclopedia/signatures-multisig#thresholds)
3. Use identities that were defined earlier on both servers. (That means, both server will accept SEP-10 authentication via `recoveryKp` as an auth method)
4. Set device key weight to 10, and recovery server weight to 5. Given these account thresholds, both servers must be used to recover the account, as transaction signed by one will only have weight of 5, which is not sufficient to change account key.

Note: You can also provide a sponsor for the transaction.

Finally, sign and submit transaction to the network:

```swift
let transaction = recoverableWallet.transaction
try transaction.sign(keyPair: accountKp.keyPair, network: Network.testnet)
try await wallet.stellar.submitTransaction(signedTransaction: transaction)
```

## Get Account Info

You can fetch account info from one or more servers. To do so, first we need to authenticate with a recovery server using the SEP-10 authentication method:

```swift
let sep10 = try await recovery.sep10Auth(key: first)
let authToken = try await sep10.authenticate(userKeyPair: recoveryKp)
```

Next, get account info using auth tokens:

```swift
let accountInfo = try await recovery.getAccountInfo(accountAddress: accountKp,
                                                    auth: [first:auth1Token.jwt])
```

Our second identity uses an email as an auth method. For that we can't use a [SEP-10] auth token for that server. Instead we need to use a token that ties the email to the user. For example, Firebase tokens are a good use case for this. To use this, the recovery signer server needs to be prepared to handle these kinds of tokens.

Getting account info using these tokens is the same as before.

```swift
let accountInfo = try await recovery.getAccountInfo(accountAddress: accountKp,
                                                    auth: [second:<other token string>])
```

## Recover Wallet

Let's say we've lost our device key and need to recover our wallet.

First, we need to authenticate with both recovery servers:

```swift
let sep10 = try await recovery.sep10Auth(key: first)
let authToken = try await sep10.authenticate(userKeyPair: recoveryKp)

let auth1 = authToken.jwt;
let auth2 = "..."; // get other token e.g. firebase token
```

We need to know the recovery signer addresses that will be used to sign the transaction. You can get them from either the recoverable wallet object we created earlier (`recoverableWallet.signers`), or via fetching account info from recovery servers.

```swift
let recoverySigners = recoverableWallet.signers;
```

Next, create a new device key and retrieve a signed transaction that replaces the device key:

```swift
let newKey = wallet.stellar.account.createKeyPair()
let serverAuth = [
    first: RecoveryServerSigning(signerAddress: recoverySigners[0] , authToken: auth1),
    second: RecoveryServerSigning(signerAddress: recoverySigners[1] , authToken: auth2),
]

let signedReplaceKeyTx = try await recovery.replaceDeviceKey(account: accountKp,
                                                             newKey: newKey,
                                                             serverAuth: serverAuth)
```

Calling this function will create a transaction that locks the previous device key and replaces it with your new key (having the same weight as the old one). Both recovery signers will have signed the transaction.

The lost device key is deduced automatically if not given. A signer will be considered a device key, if one of these conditions matches:

1. It's the only signer that's not in `serverAuth`.
2. All signers in `serverAuth` have the same weight, and the potential signer is the only one with a different weight.

3. Note that the account created above will match the first criteria. If 2-3 schema were used, then second criteria would match. (In 2-3 schema, 3 serves are used and 2 of them is enough to recover key. This is a recommended approach.)

Note: By using the `replaceDeviceKey` function you can also provide the lost key and you can also provide a sponsor for the transaction.
Note: You can also use a more low-level `signWithRecoveryServers` function to sign arbitrary transaction.

Finally, it's time to submit the transaction:

```swift
try await wallet.stellar.submitTransaction(signedTransaction: signedReplaceKeyTx)
```

## Further readings
The [recovery test cases](https://github.com/Soneso/stellar-swift-wallet-sdk/blob/main/Tests/stellar-wallet-sdkTests/RecoveryTest.swift) contain many examples that can be used to learn more about the recovery service.
