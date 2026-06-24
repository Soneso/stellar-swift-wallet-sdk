//
//  CoveragePushTests.swift
//
//
//  Offline coverage push for branches not yet exercised by the existing suites:
//  - anchor/responses/TomlInfo.swift: full documentation / principals / currencies /
//    validators parsing, InfoCurrency.assetId resolution and its throwing branch,
//    and nil-section handling.
//  - customer/Sep12.swift: update success / failure, verify failure, delete failure.
//  - uri/Sep7.swift: chain nesting beyond the allowed maximum.
//  - anchor/watcher/Watcher.swift: watchOneTransaction / watchAsset result lifecycle
//    without polling.
//  - recovery/AccountRecover.swift: deduceKey throwing branches via replaceDeviceKey.
//
//  All tests run fully offline through the URLProtocol-based ServerMock.
//

import XCTest
import Foundation
import stellarsdk
@testable import stellar_wallet_sdk

final class CovPushUtils {

    // Hosts dedicated to this suite to avoid collisions with other suites.
    static let richTomlDomain = "rich.covpush.example"
    static let minimalTomlDomain = "minimal.covpush.example"
    static let codeNoIssuerTomlDomain = "codenoissuer.covpush.example"

    static let anchorDomain = "anchor.covpush.example"
    static let apiHost = "api.covpush.example"
    static let webAuthEndpoint = "https://\(apiHost)/auth"
    static let kycServer = "http://\(apiHost)/kyc"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"

    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)

    // Valid issuer / validator / collateral public keys.
    static let usdcIssuer = "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
    static let account1 = "GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
    static let account2 = "GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U"
    static let validator1Key = "GD5FXLMVZSNK2HXP4MQNQTL7QVNH4Z6V7FZTCXHJZ6XBTQ7XGV7M5HC2"
    static let validator2Key = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"

    static let usdcAsset = try! IssuedAssetId(code: "USDC", issuer: usdcIssuer)

    /// A structurally valid JWT (header.payload.signature) used to build an AuthToken
    /// directly for the watcher tests without performing SEP-10 auth.
    /// Header: {"alg":"HS256","typ":"JWT"}
    /// Payload: {"iss":"https://issuer.example","sub":"GABC:def:1234","iat":1700000000,"exp":1700003600,"client_domain":"client.example"}
    static let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlIiwic3ViIjoiR0FCQzpkZWY6MTIzNCIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAzNjAwLCJjbGllbnRfZG9tYWluIjoiY2xpZW50LmV4YW1wbGUifQ.c2lnbmF0dXJlc2VnbWVudA"
}

/// stellar.toml with a rich DOCUMENTATION table, two PRINCIPALS, two CURRENCIES
/// (one native, one issued with the optional fields), two VALIDATORS, plus several
/// account-level fields.
class CovPushRichTomlMock: ResponsesMock {
    let host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] _, _ in
            return self?.toml
        }
        return RequestMock(host: host,
                           path: "/.well-known/stellar.toml",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    var toml: String {
        return """
        VERSION="2.0.0"
        NETWORK_PASSPHRASE="\(Network.testnet.passphrase)"
        FEDERATION_SERVER="https://\(CovPushUtils.richTomlDomain)/federation"
        HORIZON_URL="https://\(CovPushUtils.richTomlDomain)/horizon"
        SIGNING_KEY="\(CovPushUtils.serverAccountId)"
        URI_REQUEST_SIGNING_KEY="\(CovPushUtils.serverAccountId)"
        DIRECT_PAYMENT_SERVER="https://\(CovPushUtils.richTomlDomain)/sep31"
        ANCHOR_QUOTE_SERVER="https://\(CovPushUtils.richTomlDomain)/sep38"
        ACCOUNTS=["\(CovPushUtils.account1)", "\(CovPushUtils.account2)"]

        [DOCUMENTATION]
        ORG_NAME="CovPush Org"
        ORG_DBA="CovPush DBA"
        ORG_URL="https://\(CovPushUtils.richTomlDomain)"
        ORG_LOGO="https://\(CovPushUtils.richTomlDomain)/logo.png"
        ORG_DESCRIPTION="An organization used for coverage tests."
        ORG_PHYSICAL_ADDRESS="123 Test Street"
        ORG_PHYSICAL_ADDRESS_ATTESTATION="https://\(CovPushUtils.richTomlDomain)/address.pdf"
        ORG_PHONE_NUMBER="+1 555 0100"
        ORG_PHONE_NUMBER_ATTESTATION="https://\(CovPushUtils.richTomlDomain)/phone.pdf"
        ORG_KEYBASE="covpush"
        ORG_TWITTER="covpush"
        ORG_GITHUB="covpush"
        ORG_OFFICIAL_EMAIL="info@\(CovPushUtils.richTomlDomain)"
        ORG_SUPPORT_EMAIL="support@\(CovPushUtils.richTomlDomain)"
        ORG_LICENSING_AUTHORITY="Test Authority"
        ORG_LICENSE_TYPE="Test License"
        ORG_LICENSE_NUMBER="LIC-12345"

        [[PRINCIPALS]]
        name="Alice Example"
        email="alice@\(CovPushUtils.richTomlDomain)"
        keybase="alice"
        telegram="alice_tg"
        twitter="alice_tw"
        github="alice_gh"
        id_photo_hash="aaa111"
        verification_photo_hash="bbb222"

        [[PRINCIPALS]]
        name="Bob Example"
        email="bob@\(CovPushUtils.richTomlDomain)"

        [[CURRENCIES]]
        code="native"
        display_decimals=7
        name="Lumens"
        desc="The native asset"
        status="live"

        [[CURRENCIES]]
        code="USDC"
        issuer="\(CovPushUtils.usdcIssuer)"
        display_decimals=2
        name="USD Coin"
        desc="A US dollar stablecoin"
        conditions="No conditions apply"
        image="https://\(CovPushUtils.richTomlDomain)/usdc.png"
        status="live"
        fixed_number=1000000
        max_number=2000000
        is_unlimited=false
        is_asset_anchored=true
        anchor_asset_type="fiat"
        anchor_asset="USD"
        attestation_of_reserve="https://\(CovPushUtils.richTomlDomain)/reserve.pdf"
        redemption_instructions="Contact support to redeem"
        collateral_addresses=["\(CovPushUtils.account1)", "\(CovPushUtils.account2)"]
        collateral_address_messages=["msg1", "msg2"]
        collateral_address_signatures=["sig1", "sig2"]
        regulated=true
        approval_server="https://\(CovPushUtils.richTomlDomain)/approve"
        approval_criteria="Must be a verified customer"

        [[VALIDATORS]]
        ALIAS="covpush-val-1"
        DISPLAY_NAME="CovPush Validator 1"
        PUBLIC_KEY="\(CovPushUtils.validator1Key)"
        HOST="core1.\(CovPushUtils.richTomlDomain):11625"
        HISTORY="https://\(CovPushUtils.richTomlDomain)/history/1/"

        [[VALIDATORS]]
        ALIAS="covpush-val-2"
        DISPLAY_NAME="CovPush Validator 2"
        PUBLIC_KEY="\(CovPushUtils.validator2Key)"
        HOST="core2.\(CovPushUtils.richTomlDomain):11625"
        """
    }
}

/// stellar.toml with only the minimum required account-level fields plus a
/// DOCUMENTATION table and no PRINCIPALS / CURRENCIES / VALIDATORS sections.
class CovPushMinimalTomlMock: ResponsesMock {
    let host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] _, _ in
            return self?.toml
        }
        return RequestMock(host: host,
                           path: "/.well-known/stellar.toml",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    var toml: String {
        return """
        VERSION="2.0.0"
        NETWORK_PASSPHRASE="\(Network.testnet.passphrase)"
        SIGNING_KEY="\(CovPushUtils.serverAccountId)"

        [DOCUMENTATION]
        ORG_NAME="Minimal Org"
        """
    }
}

/// stellar.toml with a single currency that has a code but no issuer, used to
/// exercise the InfoCurrency.assetId throwing branch.
class CovPushCodeNoIssuerTomlMock: ResponsesMock {
    let host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] _, _ in
            return self?.toml
        }
        return RequestMock(host: host,
                           path: "/.well-known/stellar.toml",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    var toml: String {
        return """
        VERSION="2.0.0"
        NETWORK_PASSPHRASE="\(Network.testnet.passphrase)"
        SIGNING_KEY="\(CovPushUtils.serverAccountId)"

        [DOCUMENTATION]
        ORG_NAME="Code No Issuer Org"

        [[CURRENCIES]]
        code="USDC"
        display_decimals=2
        """
    }
}

/// Registers PUT /kyc/customer, PUT /kyc/customer/verification and
/// DELETE /kyc/customer/{account} handlers, each with a configurable status code.
class CovPushKycMock: ResponsesMock {
    let host: String
    var putStatusCode = 200
    private let verifyMock: CovPushKycVerifyMock
    private let deleteMock: CovPushKycDeleteMock

    var verifyStatusCode: Int {
        get { verifyMock.statusCode }
        set { verifyMock.statusCode = newValue }
    }

    var deleteStatusCode: Int {
        get { deleteMock.statusCode }
        set { deleteMock.statusCode = newValue }
    }

    init(host: String) {
        self.host = host
        self.verifyMock = CovPushKycVerifyMock(host: host)
        self.deleteMock = CovPushKycDeleteMock(host: host)
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, _ in
            guard let self = self else { return nil }
            mock.statusCode = self.putStatusCode
            if self.putStatusCode != 200 {
                return "{\"error\": \"customer not found\"}"
            }
            return "{ \"id\": \"covpush-customer-id\" }"
        }
        return RequestMock(host: host,
                           path: "kyc/customer",
                           httpMethod: "PUT",
                           mockHandler: handler)
    }
}

class CovPushKycVerifyMock: ResponsesMock {
    let host: String
    var statusCode = 200

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, _ in
            guard let self = self else { return nil }
            mock.statusCode = self.statusCode
            if self.statusCode != 200 {
                return "{\"error\": \"customer not found\"}"
            }
            return """
            {
               "id": "covpush-customer-id",
               "status": "ACCEPTED"
            }
            """
        }
        return RequestMock(host: host,
                           path: "kyc/customer/verification",
                           httpMethod: "PUT",
                           mockHandler: handler)
    }
}

class CovPushKycDeleteMock: ResponsesMock {
    let host: String
    var statusCode = 200

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, _ in
            guard let self = self else { return nil }
            mock.statusCode = self.statusCode
            if self.statusCode != 200 {
                return "{\"error\": \"customer not found\"}"
            }
            return nil
        }
        return RequestMock(host: host,
                           path: "kyc/customer/${account}",
                           httpMethod: "DELETE",
                           mockHandler: handler)
    }
}

/// Mocks GET https://horizon-testnet.stellar.org/accounts/{accountId} returning a
/// fixed, valid Horizon AccountResponse for the given account and signer set.
class CovPushHorizonAccountMock: ResponsesMock {
    let accountId: String
    let signers: [(key: String, weight: Int)]

    init(accountId: String, signers: [(key: String, weight: Int)]) {
        self.accountId = accountId
        self.signers = signers
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, _ in
            guard let self = self else { return nil }
            mock.statusCode = 200
            return self.accountJson()
        }
        return RequestMock(host: "horizon-testnet.stellar.org",
                           path: "/accounts/\(accountId)",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    private func accountJson() -> String {
        let signersJson = signers.map { signer in
            """
            { "weight": \(signer.weight), "key": "\(signer.key)", "type": "ed25519_public_key" }
            """
        }.joined(separator: ",")

        return """
        {
          "_links": {
            "self": { "href": "https://horizon-testnet.stellar.org/accounts/\(accountId)" },
            "transactions": { "href": "https://horizon-testnet.stellar.org/accounts/\(accountId)/transactions{?cursor,limit,order}", "templated": true },
            "operations": { "href": "https://horizon-testnet.stellar.org/accounts/\(accountId)/operations{?cursor,limit,order}", "templated": true },
            "payments": { "href": "https://horizon-testnet.stellar.org/accounts/\(accountId)/payments{?cursor,limit,order}", "templated": true },
            "effects": { "href": "https://horizon-testnet.stellar.org/accounts/\(accountId)/effects{?cursor,limit,order}", "templated": true },
            "offers": { "href": "https://horizon-testnet.stellar.org/accounts/\(accountId)/offers{?cursor,limit,order}", "templated": true },
            "trades": { "href": "https://horizon-testnet.stellar.org/accounts/\(accountId)/trades{?cursor,limit,order}", "templated": true },
            "data": { "href": "https://horizon-testnet.stellar.org/accounts/\(accountId)/data/{key}", "templated": true }
          },
          "id": "\(accountId)",
          "account_id": "\(accountId)",
          "sequence": "4233721387843585",
          "subentry_count": 0,
          "last_modified_ledger": 985731,
          "last_modified_time": "2024-01-01T00:00:00Z",
          "thresholds": { "low_threshold": 0, "med_threshold": 0, "high_threshold": 0 },
          "flags": { "auth_required": false, "auth_revocable": false, "auth_immutable": false, "auth_clawback_enabled": false },
          "balances": [ { "balance": "10000.0000000", "buying_liabilities": "0.0000000", "selling_liabilities": "0.0000000", "asset_type": "native" } ],
          "signers": [ \(signersJson) ],
          "data": {},
          "num_sponsoring": 0,
          "num_sponsored": 0,
          "paging_token": "\(accountId)"
        }
        """
    }
}

final class CoveragePushTests: XCTestCase {

    let wallet = Wallet.testNet

    var richTomlMock: CovPushRichTomlMock!
    var minimalTomlMock: CovPushMinimalTomlMock!
    var codeNoIssuerTomlMock: CovPushCodeNoIssuerTomlMock!

    var anchorTomlMock: TomlResponseMock!
    var challengeMock: WebAuthChallengeResponseMock!
    var sendChallengeMock: WebAuthSendChallengeResponseMock!
    var kycMock: CovPushKycMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        richTomlMock = CovPushRichTomlMock(host: CovPushUtils.richTomlDomain)
        minimalTomlMock = CovPushMinimalTomlMock(host: CovPushUtils.minimalTomlDomain)
        codeNoIssuerTomlMock = CovPushCodeNoIssuerTomlMock(host: CovPushUtils.codeNoIssuerTomlDomain)

        anchorTomlMock = TomlResponseMock(host: CovPushUtils.anchorDomain,
                                          serverSigningKey: CovPushUtils.serverAccountId,
                                          authServer: CovPushUtils.webAuthEndpoint,
                                          kycServer: CovPushUtils.kycServer)
        challengeMock = WebAuthChallengeResponseMock(host: CovPushUtils.apiHost,
                                                     serverKeyPair: CovPushUtils.serverKeypair,
                                                     homeDomain: CovPushUtils.anchorDomain)
        sendChallengeMock = WebAuthSendChallengeResponseMock(host: CovPushUtils.apiHost)
        kycMock = CovPushKycMock(host: CovPushUtils.apiHost)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - helpers

    private func authToken() async throws -> AuthToken {
        let anchor = wallet.anchor(homeDomain: CovPushUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: CovPushUtils.userSecretSeed)
        return try await anchor.sep10.authenticate(userKeyPair: authKey)
    }

    private func sep12() async throws -> Sep12 {
        let token = try await authToken()
        return try await wallet.anchor(homeDomain: CovPushUtils.anchorDomain).sep12(authToken: token)
    }

    // MARK: - TomlInfo: rich parsing

    func testCovPushTomlInfoRichParsing() async throws {
        let info = try await wallet.anchor(homeDomain: CovPushUtils.richTomlDomain).info

        // Account-level fields.
        XCTAssertEqual("2.0.0", info.version)
        XCTAssertEqual(Network.testnet.passphrase, info.networkPassphrase)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/federation", info.federationServer)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/horizon", info.horizonUrl)
        XCTAssertEqual(CovPushUtils.serverAccountId, info.signingKey)
        XCTAssertEqual(CovPushUtils.serverAccountId, info.uriRequestSigningKey)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/sep31", info.directPaymentServer)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/sep38", info.anchorQuoteServer)
        XCTAssertEqual([CovPushUtils.account1, CovPushUtils.account2], info.accounts)

        // Documentation.
        guard let doc = info.documentaion else {
            XCTFail("expected documentation")
            return
        }
        XCTAssertEqual("CovPush Org", doc.orgName)
        XCTAssertEqual("CovPush DBA", doc.orgDba)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)", doc.orgUrl)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/logo.png", doc.orgLogo)
        XCTAssertEqual("An organization used for coverage tests.", doc.orgDescription)
        XCTAssertEqual("123 Test Street", doc.orgPhysicalAddress)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/address.pdf", doc.orgPhysicalAddressAttestation)
        XCTAssertEqual("+1 555 0100", doc.orgPhoneNumber)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/phone.pdf", doc.orgPhoneNumberAttestation)
        XCTAssertEqual("covpush", doc.orgKeybase)
        XCTAssertEqual("covpush", doc.orgTwitter)
        XCTAssertEqual("covpush", doc.orgGithub)
        XCTAssertEqual("info@\(CovPushUtils.richTomlDomain)", doc.orgOfficialEmail)
        XCTAssertEqual("support@\(CovPushUtils.richTomlDomain)", doc.orgSupportEmail)
        XCTAssertEqual("Test Authority", doc.orgLicensingAuthority)
        XCTAssertEqual("Test License", doc.orgLicenseType)
        XCTAssertEqual("LIC-12345", doc.orgLicenseNumber)

        // Principals.
        guard let principals = info.principals else {
            XCTFail("expected principals")
            return
        }
        XCTAssertEqual(2, principals.count)
        let alice = principals.first { $0.name == "Alice Example" }
        XCTAssertNotNil(alice)
        XCTAssertEqual("alice@\(CovPushUtils.richTomlDomain)", alice?.email)
        XCTAssertEqual("alice", alice?.keybase)
        XCTAssertEqual("alice_tg", alice?.telegram)
        XCTAssertEqual("alice_tw", alice?.twitter)
        XCTAssertEqual("alice_gh", alice?.github)
        XCTAssertEqual("aaa111", alice?.idPhotoHash)
        XCTAssertEqual("bbb222", alice?.verificationPhotoHash)
        let bob = principals.first { $0.name == "Bob Example" }
        XCTAssertNotNil(bob)
        XCTAssertEqual("bob@\(CovPushUtils.richTomlDomain)", bob?.email)
        XCTAssertNil(bob?.telegram)

        // Validators.
        guard let validators = info.validators else {
            XCTFail("expected validators")
            return
        }
        XCTAssertEqual(2, validators.count)
        let val1 = validators.first { $0.alias == "covpush-val-1" }
        XCTAssertNotNil(val1)
        XCTAssertEqual("CovPush Validator 1", val1?.displayName)
        XCTAssertEqual(CovPushUtils.validator1Key, val1?.publicKey)
        XCTAssertEqual("core1.\(CovPushUtils.richTomlDomain):11625", val1?.host)
        let val2 = validators.first { $0.alias == "covpush-val-2" }
        XCTAssertNotNil(val2)
        XCTAssertEqual(CovPushUtils.validator2Key, val2?.publicKey)

        // Currencies.
        guard let currencies = info.currencies else {
            XCTFail("expected currencies")
            return
        }
        XCTAssertEqual(2, currencies.count)

        let usdc = currencies.first { $0.code == "USDC" }
        XCTAssertNotNil(usdc)
        XCTAssertEqual(CovPushUtils.usdcIssuer, usdc?.issuer)
        XCTAssertEqual(2, usdc?.displayDecimals)
        XCTAssertEqual("USD Coin", usdc?.name)
        XCTAssertEqual("A US dollar stablecoin", usdc?.desc)
        XCTAssertEqual("No conditions apply", usdc?.conditions)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/usdc.png", usdc?.image)
        XCTAssertEqual("live", usdc?.status)
        XCTAssertEqual(1000000, usdc?.fixedNumber)
        XCTAssertEqual(2000000, usdc?.maxNumber)
        XCTAssertEqual(false, usdc?.isUnlimited)
        XCTAssertEqual(true, usdc?.isAssetAnchored)
        XCTAssertEqual("fiat", usdc?.anchorAssetType)
        XCTAssertEqual("USD", usdc?.anchorAsset)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/reserve.pdf", usdc?.attestationOfReserve)
        XCTAssertEqual("Contact support to redeem", usdc?.redemptionInstructions)
        XCTAssertEqual([CovPushUtils.account1, CovPushUtils.account2], usdc?.collateralAddresses)
        XCTAssertEqual(["msg1", "msg2"], usdc?.collateralAddressMessages)
        XCTAssertEqual(["sig1", "sig2"], usdc?.collateralAddressSignatures)
        XCTAssertEqual(true, usdc?.regulated)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/approve", usdc?.approvalServer)
        XCTAssertEqual("Must be a verified customer", usdc?.approvalCriteria)

        // assetId of the issued currency resolves to an IssuedAssetId.
        let usdcAssetId = try usdc!.assetId
        guard let issuedAssetId = usdcAssetId as? IssuedAssetId else {
            XCTFail("expected IssuedAssetId, got \(type(of: usdcAssetId))")
            return
        }
        XCTAssertEqual("USDC", issuedAssetId.code)
        XCTAssertEqual(CovPushUtils.usdcIssuer, issuedAssetId.issuer)

        // assetId of the native-code currency resolves to a NativeAssetId.
        let native = currencies.first { $0.code == "native" }
        XCTAssertNotNil(native)
        XCTAssertEqual(7, native?.displayDecimals)
        XCTAssertEqual("Lumens", native?.name)
        let nativeAssetId = try native!.assetId
        XCTAssertTrue(nativeAssetId is NativeAssetId)
        XCTAssertEqual("native", nativeAssetId.id)

        // sep31 / sep38 services derived from the toml.
        let services = info.services
        XCTAssertNotNil(services.sep31)
        XCTAssertEqual("https://\(CovPushUtils.richTomlDomain)/sep31", services.sep31?.directPaymentServer)

        withExtendedLifetime(richTomlMock) {}
    }

    // MARK: - TomlInfo: minimal toml -> nil sections

    func testCovPushTomlInfoMinimalNilSections() async throws {
        let info = try await wallet.anchor(homeDomain: CovPushUtils.minimalTomlDomain).info

        XCTAssertEqual("2.0.0", info.version)
        XCTAssertEqual(CovPushUtils.serverAccountId, info.signingKey)
        XCTAssertEqual("Minimal Org", info.documentaion?.orgName)

        // Absent sections are reported as nil.
        XCTAssertNil(info.principals)
        XCTAssertNil(info.currencies)
        XCTAssertNil(info.validators)

        withExtendedLifetime(minimalTomlMock) {}
    }

    // MARK: - TomlInfo: InfoCurrency.assetId throws when code present but issuer absent

    func testCovPushInfoCurrencyAssetIdThrowsWhenIssuerMissing() async throws {
        let info = try await wallet.anchor(homeDomain: CovPushUtils.codeNoIssuerTomlDomain).info

        guard let currencies = info.currencies, currencies.count == 1 else {
            XCTFail("expected exactly one currency")
            return
        }
        let currency = currencies[0]
        XCTAssertEqual("USDC", currency.code)
        XCTAssertNil(currency.issuer)

        XCTAssertThrowsError(try currency.assetId) { error in
            guard case ValidationError.invalidArgument(let message) = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
            XCTAssertTrue(message.contains("USDC"))
        }

        withExtendedLifetime(codeNoIssuerTomlMock) {}
    }

    // MARK: - Sep12.update

    func testCovPushSep12UpdateSuccess() async throws {
        let sep12 = try await sep12()
        let response = try await sep12.update(id: "covpush-customer-id",
                                              sep9Info: [Sep9PersonKeys.firstName: "Jane"])
        XCTAssertEqual("covpush-customer-id", response.id)
    }

    func testCovPushSep12UpdateNotFound() async throws {
        let sep12 = try await sep12()
        kycMock.putStatusCode = 404
        do {
            _ = try await sep12.update(id: "missing-customer",
                                       sep9Info: [Sep9PersonKeys.firstName: "Jane"])
            XCTFail("expected KycServiceError.notFound")
        } catch KycServiceError.notFound {
            // expected: 404 with a JSON error body maps to notFound.
        }
    }

    func testCovPushSep12UpdateBadRequest() async throws {
        let sep12 = try await sep12()
        kycMock.putStatusCode = 400
        do {
            _ = try await sep12.update(id: "covpush-customer-id",
                                       sep9Info: [Sep9PersonKeys.firstName: "Jane"])
            XCTFail("expected KycServiceError.badRequest")
        } catch KycServiceError.badRequest {
            // expected: 400 with a JSON error body maps to badRequest.
        }
    }

    // MARK: - Sep12.verify failure

    func testCovPushSep12VerifyNotFound() async throws {
        let sep12 = try await sep12()
        kycMock.verifyStatusCode = 404
        do {
            _ = try await sep12.verify(id: "missing-customer",
                                       verificationFields: ["mobile_number_verification": "123456"])
            XCTFail("expected KycServiceError.notFound")
        } catch KycServiceError.notFound {
            // expected
        }
    }

    // MARK: - Sep12.delete failure

    func testCovPushSep12DeleteNotFound() async throws {
        let sep12 = try await sep12()
        kycMock.deleteStatusCode = 404
        let accountId = try KeyPair(secretSeed: CovPushUtils.userSecretSeed).accountId
        do {
            try await sep12.delete(account: accountId)
            XCTFail("expected KycServiceError.notFound")
        } catch KycServiceError.notFound {
            // expected
        }
    }

    // MARK: - Sep7: chain nesting beyond the allowed maximum

    func testCovPushSep7ChainExceedsMaxNestedLevels() {
        // Build a chain of nested tx URIs deeper than maxAllowedChainingNestedLevels (7).
        // Each level wraps the previous one in a 'chain' query parameter.
        let xdr = "AAAAAgAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAGQABqQMAAAAAQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAAAAmJaAAAAAAAAAAAFw7E5LAAAAQBu4V+/lttEONNM6KFwdSf5TEEogyEBy0jTOHJKuUzKScpLHyvDJGY+xH9Ri4cIuA7AaB8aL+VdlucCfsNYpKAY="

        // Encoding the chain value with alphanumerics-only ensures the nested
        // '&chain=' / '?xdr=' separators are percent-encoded so the chain truly
        // nests (rather than flattening into sibling query items).
        func encoded(_ value: String) -> String {
            return value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
        }

        // Innermost level: a plain valid tx uri.
        var uri = "web+stellar:tx?xdr=\(encoded(xdr))"
        // Nest 9 additional chain levels so the deepest 'chain' is encountered while
        // level has already passed maxAllowedChainingNestedLevels (7).
        for _ in 0..<9 {
            uri = "web+stellar:tx?xdr=\(encoded(xdr))&chain=\(encoded(uri))"
        }

        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertNotNil(result.reason)
        XCTAssertTrue(result.reason!.contains("Chaining more then \(Sep7.maxAllowedChainingNestedLevels) nested levels is not allowed"),
                      "unexpected reason: \(result.reason ?? "nil")")
        XCTAssertEqual(Sep7OperationType.tx, result.operationType)
    }

    // MARK: - Watcher: watchOneTransaction / watchAsset result lifecycle

    func testCovPushWatchOneTransactionResult() throws {
        let anchor = wallet.anchor(homeDomain: CovPushUtils.anchorDomain)
        // Large poll delay so the timer never fires within the test; no network occurs.
        let watcher = anchor.sep24.watcher(pollDelay: 3600)
        let token = try AuthToken(jwt: CovPushUtils.jwt)

        let result = watcher.watchOneTransaction(authToken: token, id: "covpush-tx-1")
        XCTAssertEqual(Notification.Name("tx_covpush-tx-1"), result.notificationName)
        XCTAssertTrue(result.timer.isValid)

        result.stop()
        XCTAssertFalse(result.timer.isValid)
    }

    func testCovPushWatchAssetResult() throws {
        let anchor = wallet.anchor(homeDomain: CovPushUtils.anchorDomain)
        let watcher = anchor.sep6.watcher(pollDelay: 3600)
        let token = try AuthToken(jwt: CovPushUtils.jwt)

        let result = watcher.watchAsset(authToken: token, asset: CovPushUtils.usdcAsset)
        XCTAssertEqual(Notification.Name("txs_\(CovPushUtils.usdcAsset.id)"), result.notificationName)
        XCTAssertTrue(result.timer.isValid)

        result.stop()
        XCTAssertFalse(result.timer.isValid)
    }

    // MARK: - AccountRecover.deduceKey throwing branches via replaceDeviceKey

    func testCovPushReplaceDeviceKeyNoDeviceKeyThrows() async throws {
        // Account whose only weighted signer is a recovery signer -> no non-recovery
        // signer remains, so deduceKey throws "No device key is setup for this account".
        let accountKp = try SigningKeyPair(secretKey: CovPushUtils.userSecretSeed)
        let recoverySignerKp = SigningKeyPair.random
        let newKey = SigningKeyPair.random

        let horizonMock = CovPushHorizonAccountMock(
            accountId: accountKp.address,
            signers: [
                (key: accountKp.address, weight: 0),                 // master, weight 0 -> ignored
                (key: recoverySignerKp.address, weight: 5),          // recovery signer
            ])

        let serverKey = RecoveryServerKey(name: "covpush-server")
        let server = RecoveryServer(endpoint: "https://recovery.covpush.example",
                                    authEndpoint: "https://auth.covpush.example/auth",
                                    homeDomain: "recovery.covpush.example")
        let recovery = wallet.recovery(servers: [serverKey: server])
        let serverAuth: [RecoveryServerKey: RecoveryServerSigning] = [
            serverKey: RecoveryServerSigning(signerAddress: recoverySignerKp.address, authToken: "token")
        ]

        do {
            _ = try await recovery.replaceDeviceKey(account: accountKp,
                                                    newKey: newKey,
                                                    serverAuth: serverAuth)
            XCTFail("expected ValidationError.invalidArgument (no device key)")
        } catch ValidationError.invalidArgument(let message) {
            XCTAssertEqual("No device key is setup for this account", message)
        }

        withExtendedLifetime(horizonMock) {}
    }

    func testCovPushReplaceDeviceKeyAmbiguousDeviceKeyThrows() async throws {
        // Two non-recovery signers whose weights both differ from the single recovery
        // weight -> deduceKey cannot pick one and throws "Couldn't deduce lost key".
        let accountKp = try SigningKeyPair(secretKey: CovPushUtils.userSecretSeed)
        let recoverySignerKp = SigningKeyPair.random
        let device1Kp = SigningKeyPair.random
        let device2Kp = SigningKeyPair.random
        let newKey = SigningKeyPair.random

        let horizonMock = CovPushHorizonAccountMock(
            accountId: accountKp.address,
            signers: [
                (key: accountKp.address, weight: 0),         // master, ignored
                (key: recoverySignerKp.address, weight: 5),  // single recovery signer (weight 5)
                (key: device1Kp.address, weight: 10),        // non-recovery, weight 10
                (key: device2Kp.address, weight: 20),        // non-recovery, weight 20
            ])

        let serverKey = RecoveryServerKey(name: "covpush-server")
        let server = RecoveryServer(endpoint: "https://recovery.covpush.example",
                                    authEndpoint: "https://auth.covpush.example/auth",
                                    homeDomain: "recovery.covpush.example")
        let recovery = wallet.recovery(servers: [serverKey: server])
        let serverAuth: [RecoveryServerKey: RecoveryServerSigning] = [
            serverKey: RecoveryServerSigning(signerAddress: recoverySignerKp.address, authToken: "token")
        ]

        do {
            _ = try await recovery.replaceDeviceKey(account: accountKp,
                                                    newKey: newKey,
                                                    serverAuth: serverAuth)
            XCTFail("expected ValidationError.invalidArgument (couldn't deduce lost key)")
        } catch ValidationError.invalidArgument(let message) {
            XCTAssertTrue(message.contains("Couldn't deduce lost key"),
                          "unexpected message: \(message)")
        }

        withExtendedLifetime(horizonMock) {}
    }
}
