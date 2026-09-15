# Changelog

## 0.9.5 - 2026-09-15

### Changed
- Updated the `stellar-ios-mac-sdk` dependency to 3.11.0, which adds `SCValXDR.toNative()` and `SCAddressXDR.toStrKey()`, accepts an injected `URLSession` in the Soroban client layer, and carries the stellar-xdr `c40231c` definitions. All additions are opt-in; the wallet API and behavior are unchanged.

## 0.9.4 - 2026-08-25

### Changed
- Updated the `stellar-ios-mac-sdk` dependency to 3.10.0, which supports Protocol 28 (CAP-85 external references, Horizon v28.0.0).
- Strkey handling follows SEP-23 strictly (validated by `stellar-ios-mac-sdk`): corrupted or wrong-width account ids and secret seeds now throw at key pair construction instead of decoding silently.
- SEP-6: the fee request sends the amount as a plain decimal string; whole amounts carry no fractional part and one stroop goes out as `0.0000001`, no longer in scientific notation (fixed in `stellar-ios-mac-sdk`).

## 0.9.3 - 2026-08-04

### Changed
- Updated the `stellar-ios-mac-sdk` dependency to 3.8.1, which adds the CAP-0083 and CAP-0085 XDR definitions and hardens mnemonic generation (fails closed if secure random generation is unavailable).

## 0.9.2 - 2026-06-25

### Changed
- Updated the `stellar-ios-mac-sdk` dependency to 3.6.0.

### Fixed
- SEP-6: withdraw and withdraw-exchange types advertised in `GET /info` with no fields (for example `"cash": {}`) were dropped from the parsed `types` map. They are now retained with a nil value, so a field-less withdrawal type is no longer lost.
- `TxBuilder.strictReceive` (and `pathPay` with a `destAmount`) crashed when called without an explicit `sendMax`: the default value overflowed `Int64` during stroop conversion. The default is now the exact maximum amount.

### Testing and tooling
- Split the test suite into a unit target (`Tests/stellar-wallet-sdkUnitTests`, offline and mocked, run in CI) and an integration target (`Tests/stellar-wallet-sdkIntegrationTests`, live network and Docker, run locally). The unit suites are isolated from one another.
- Added an offline unit test suite; unit line coverage is approximately 95%.
- Added GitHub Actions CI and Codecov coverage reporting.

Earlier releases predate this changelog; see the git history for details.
