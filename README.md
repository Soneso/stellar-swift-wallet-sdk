![logo](./docs/images/wallet-sdk-logo.png)

With the Swift Wallet SDK, building an iOS Stellar-enabled wallet or application will be faster and easier than ever. The Swift Wallet SDK is currently work in progress and will extend the [Stellar Wallet SDK Family](https://stellar.org/products-and-tools/wallet-sdk).


## Roadmap

### 1. Interacting with the Stellar Network

**Brief description:** Implementation of the features and api needed for communication with the Stellar Network as documented [here](https://developers.stellar.org/docs/build/apps/wallet/stellar).

**Status:** In progress


### 2. Stellar Authentication (SEP-10)

**Brief description:** Wallets connect to anchors using a standard way of authentication via the Stellar network defined by the [SEP-10](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md) standard. 
This ilestone will contain all the components required for SEP-10 Authentication with Anchors as documented [here](https://developers.stellar.org/docs/build/apps/wallet/sep10).

**Status:** To do


### Hosted Deposit and Withdrawal (SEP-24)

**Brief description:** The [SEP-24](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md) standard defines the standard way for anchors and wallets to interact on behalf of users. Wallets use this standard to facilitate exchanges between on-chain assets (such as stablecoins) and off-chain assets (such as fiat, or other network assets such as BTC). This milestone will cover the SEP-24 flow as documented [here](https://developers.stellar.org/docs/build/apps/wallet/sep24).

**Status:** To do


### 3. Quotes (SEP-38)

**Brief description:** The [SEP-38](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md) standard defines a way for anchors to provide quotes for the exchange of an off-chain asset and a different on-chain asset, and vice versa. This milestone will cover the SEP-38 flow as documented [here](https://developers.stellar.org/docs/build/apps/wallet/sep38).

**Status:** To do


### 4. KYC API (SEP-12)

**Brief description:** [SEP-12](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md) defines a standard way for stellar clients to upload KYC (or other) information to anchors and other services. 
Our SEP-6 implementation will use this protocol, but it can serve as a stand-alone service as well. This milestone will cover the SEP-12 flow as documented [here](https://developers.stellar.org/docs/build/apps/wallet/sep6#providing-kyc-info).

**Status:** To do


### 5. Programmatic Deposit and Withdrawal (SEP-06)

**Brief description:** The [SEP-06](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md) standard defines a way for anchors and wallets to interact on behalf of users. 
Wallets use this standard to facilitate exchanges between on-chain assets (such as stablecoins) and off-chain assets 
(such as fiat, or other network assets such as BTC). See Wallet SDK docs [here](https://developers.stellar.org/docs/build/apps/wallet/sep6).

**Status:** To do


### 6. Recovery (SEP-30)

**Brief description:** The [SEP-30](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md) standard defines the standard way for an individual 
(e.g., a user or wallet) to regain access to their Stellar account after losing its private key without providing any third party control of the account. During this flow the wallet communicates with one or more recovery 
signer servers to register the wallet for a later recovery if it's needed. See Wallet SDK docs [here](https://developers.stellar.org/docs/build/apps/wallet/sep30).

**Status:** To do
