# Wallet

Then main class of the sdk is called `Wallet`. You can initialize with a stellar configuration and an app configuration:

```swift
public init(stellarConfig: StellarConfig, appConfig:AppConfig) 
```

Or you can use pre-defined configurations for `testNet`, `publicNet`, and `futureNet` to initialize it:
 
```swift
let wallet:Wallet = Wallet.testNet
```
These pre-defined configurations are the easiest way to initialize the wallet and are sufficient for most cases. However, in the next chapter we will discuss the configuration details when initializing a new `Wallet` object via one of its initializers. 

## Wallet Configuration

By using the `Wallet` class initializes you can pass the stellar config for all Stellar-related activity via an `StellarConfig` object and the app config to be used across the app via an `AppConfig` object.

The `Wallet` class offers following initializers:

```swift
public init(stellarConfig: StellarConfig, appConfig:AppConfig)
```

and

```swift
public convenience init(stellarConfig: StellarConfig) 
```

### Stellar Config

In `StellarConfig` you can configure the default values used by the wallet when interacting with the Stellar Network. These are:

- `network`: Network to be used for transaction signing. E.g. `Network.testnet` 
- `horizonUrl`: URL of the horizon server to be used to communicate with the Stellar Network. E.g. "https://horizon-testnet.stellar.org"
- `baseFee`: The default base fee - max fee per operation in stoops - to be used for paying transactions. See [base fee docs](https://developers.stellar.org/docs/encyclopedia/fees-surge-pricing-fee-strategies#network-fees-on-stellar). Defaults to 100 Stoops. A Stroop is the smallest unit of a lumen, one ten-millionth of a lumen (.0000001 XLM).
- `txTimeout`: The transaction timeout in seconds. If no timebounds are added to a transaction, this timeout value will be used when building a transaction. The transaction will be valid from `now` to `now + txTimeout`. The default value for `txTimeout` is set to 300 seconds.

### App Config

In `AppConfig` you can configure the default behaviour across the application. Currently it offers following values:

- `defaultSigner`: The Default signer implementation to be used across application. Currently only `DefaultSigner` is available. It requires signing account keypair(s) to sign the transactions. We will add a `DomainSigner` implementation too, that will support signing via a server using standard signing data request and response types.
- `defaultClientDomain`: Domain of the server that will be used by the `DomainSigner` implementation.


## Next

Continue with [Interacting with the Stellar Network](stellar.md).



