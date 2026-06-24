# Changelog

## 0.9.2 - 2026-06-25

### Changed
- Updated the `stellar-ios-mac-sdk` dependency to 3.6.0.

### Fixed
- SEP-6: withdraw and withdraw-exchange types advertised in `GET /info` with no fields (for example `"cash": {}`) were dropped from the parsed `types` map. They are now retained with a nil value, so a field-less withdrawal type is no longer lost.
- `TxBuilder.strictReceive` (and `pathPay` with a `destAmount`) crashed when called without an explicit `sendMax`: the default value overflowed `Int64` during stroop conversion. The default is now the exact maximum amount.

### Testing and tooling
- Split the test suite into a unit target (`Tests/stellar-wallet-sdkTests`, offline and mocked, run in CI) and an integration target (`Tests/stellar-wallet-sdkIntegrationTests`, live network and Docker, run locally). The unit suites are isolated from one another.
- Added an offline unit test suite; unit line coverage is approximately 95%.
- Added GitHub Actions CI and Codecov coverage reporting.

Earlier releases predate this changelog; see the git history for details.
