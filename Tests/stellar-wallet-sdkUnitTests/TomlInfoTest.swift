//
//  TomlInfoTest.swift
//
//
//  Offline coverage for anchor/responses/TomlInfo.swift: full documentation /
//  principals / currencies / validators parsing, InfoCurrency.assetId resolution
//  and its throwing branch, and nil-section handling. All tests run fully offline
//  through the URLProtocol-based ServerMock.
//

import XCTest
import Foundation
import stellarsdk
@testable import stellar_wallet_sdk

final class TomlInfoTestUtils {

    // Hosts dedicated to this suite to avoid collisions with other suites.
    static let richTomlDomain = "rich.tomlinfotest.example"
    static let minimalTomlDomain = "minimal.tomlinfotest.example"
    static let codeNoIssuerTomlDomain = "codenoissuer.tomlinfotest.example"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"

    // Valid issuer / validator / collateral public keys.
    static let usdcIssuer = "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
    static let account1 = "GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
    static let account2 = "GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U"
    static let validator1Key = "GD5FXLMVZSNK2HXP4MQNQTL7QVNH4Z6V7FZTCXHJZ6XBTQ7XGV7M5HC2"
    static let validator2Key = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
}

/// stellar.toml with a rich DOCUMENTATION table, two PRINCIPALS, two CURRENCIES
/// (one native, one issued with the optional fields), two VALIDATORS, plus several
/// account-level fields.
class TomlInfoTestRichTomlMock: ResponsesMock {
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
        FEDERATION_SERVER="https://\(TomlInfoTestUtils.richTomlDomain)/federation"
        HORIZON_URL="https://\(TomlInfoTestUtils.richTomlDomain)/horizon"
        SIGNING_KEY="\(TomlInfoTestUtils.serverAccountId)"
        URI_REQUEST_SIGNING_KEY="\(TomlInfoTestUtils.serverAccountId)"
        DIRECT_PAYMENT_SERVER="https://\(TomlInfoTestUtils.richTomlDomain)/sep31"
        ANCHOR_QUOTE_SERVER="https://\(TomlInfoTestUtils.richTomlDomain)/sep38"
        ACCOUNTS=["\(TomlInfoTestUtils.account1)", "\(TomlInfoTestUtils.account2)"]

        [DOCUMENTATION]
        ORG_NAME="Example Org"
        ORG_DBA="Example DBA"
        ORG_URL="https://\(TomlInfoTestUtils.richTomlDomain)"
        ORG_LOGO="https://\(TomlInfoTestUtils.richTomlDomain)/logo.png"
        ORG_DESCRIPTION="An organization used for coverage tests."
        ORG_PHYSICAL_ADDRESS="123 Test Street"
        ORG_PHYSICAL_ADDRESS_ATTESTATION="https://\(TomlInfoTestUtils.richTomlDomain)/address.pdf"
        ORG_PHONE_NUMBER="+1 555 0100"
        ORG_PHONE_NUMBER_ATTESTATION="https://\(TomlInfoTestUtils.richTomlDomain)/phone.pdf"
        ORG_KEYBASE="example"
        ORG_TWITTER="example"
        ORG_GITHUB="example"
        ORG_OFFICIAL_EMAIL="info@\(TomlInfoTestUtils.richTomlDomain)"
        ORG_SUPPORT_EMAIL="support@\(TomlInfoTestUtils.richTomlDomain)"
        ORG_LICENSING_AUTHORITY="Test Authority"
        ORG_LICENSE_TYPE="Test License"
        ORG_LICENSE_NUMBER="LIC-12345"

        [[PRINCIPALS]]
        name="Alice Example"
        email="alice@\(TomlInfoTestUtils.richTomlDomain)"
        keybase="alice"
        telegram="alice_tg"
        twitter="alice_tw"
        github="alice_gh"
        id_photo_hash="aaa111"
        verification_photo_hash="bbb222"

        [[PRINCIPALS]]
        name="Bob Example"
        email="bob@\(TomlInfoTestUtils.richTomlDomain)"

        [[CURRENCIES]]
        code="native"
        display_decimals=7
        name="Lumens"
        desc="The native asset"
        status="live"

        [[CURRENCIES]]
        code="USDC"
        issuer="\(TomlInfoTestUtils.usdcIssuer)"
        display_decimals=2
        name="USD Coin"
        desc="A US dollar stablecoin"
        conditions="No conditions apply"
        image="https://\(TomlInfoTestUtils.richTomlDomain)/usdc.png"
        status="live"
        fixed_number=1000000
        max_number=2000000
        is_unlimited=false
        is_asset_anchored=true
        anchor_asset_type="fiat"
        anchor_asset="USD"
        attestation_of_reserve="https://\(TomlInfoTestUtils.richTomlDomain)/reserve.pdf"
        redemption_instructions="Contact support to redeem"
        collateral_addresses=["\(TomlInfoTestUtils.account1)", "\(TomlInfoTestUtils.account2)"]
        collateral_address_messages=["msg1", "msg2"]
        collateral_address_signatures=["sig1", "sig2"]
        regulated=true
        approval_server="https://\(TomlInfoTestUtils.richTomlDomain)/approve"
        approval_criteria="Must be a verified customer"

        [[VALIDATORS]]
        ALIAS="example-val-1"
        DISPLAY_NAME="Example Validator 1"
        PUBLIC_KEY="\(TomlInfoTestUtils.validator1Key)"
        HOST="core1.\(TomlInfoTestUtils.richTomlDomain):11625"
        HISTORY="https://\(TomlInfoTestUtils.richTomlDomain)/history/1/"

        [[VALIDATORS]]
        ALIAS="example-val-2"
        DISPLAY_NAME="Example Validator 2"
        PUBLIC_KEY="\(TomlInfoTestUtils.validator2Key)"
        HOST="core2.\(TomlInfoTestUtils.richTomlDomain):11625"
        """
    }
}

/// stellar.toml with only the minimum required account-level fields plus a
/// DOCUMENTATION table and no PRINCIPALS / CURRENCIES / VALIDATORS sections.
class TomlInfoTestMinimalTomlMock: ResponsesMock {
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
        SIGNING_KEY="\(TomlInfoTestUtils.serverAccountId)"

        [DOCUMENTATION]
        ORG_NAME="Minimal Org"
        """
    }
}

/// stellar.toml with a single currency that has a code but no issuer, used to
/// exercise the InfoCurrency.assetId throwing branch.
class TomlInfoTestCodeNoIssuerTomlMock: ResponsesMock {
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
        SIGNING_KEY="\(TomlInfoTestUtils.serverAccountId)"

        [DOCUMENTATION]
        ORG_NAME="Code No Issuer Org"

        [[CURRENCIES]]
        code="USDC"
        display_decimals=2
        """
    }
}

final class TomlInfoTest: XCTestCase {

    let wallet = Wallet.testNet

    var richTomlMock: TomlInfoTestRichTomlMock!
    var minimalTomlMock: TomlInfoTestMinimalTomlMock!
    var codeNoIssuerTomlMock: TomlInfoTestCodeNoIssuerTomlMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        richTomlMock = TomlInfoTestRichTomlMock(host: TomlInfoTestUtils.richTomlDomain)
        minimalTomlMock = TomlInfoTestMinimalTomlMock(host: TomlInfoTestUtils.minimalTomlDomain)
        codeNoIssuerTomlMock = TomlInfoTestCodeNoIssuerTomlMock(host: TomlInfoTestUtils.codeNoIssuerTomlDomain)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - TomlInfo: rich parsing

    func testTomlInfoRichParsing() async throws {
        let info = try await wallet.anchor(homeDomain: TomlInfoTestUtils.richTomlDomain).info

        // Account-level fields.
        XCTAssertEqual("2.0.0", info.version)
        XCTAssertEqual(Network.testnet.passphrase, info.networkPassphrase)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/federation", info.federationServer)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/horizon", info.horizonUrl)
        XCTAssertEqual(TomlInfoTestUtils.serverAccountId, info.signingKey)
        XCTAssertEqual(TomlInfoTestUtils.serverAccountId, info.uriRequestSigningKey)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/sep31", info.directPaymentServer)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/sep38", info.anchorQuoteServer)
        XCTAssertEqual([TomlInfoTestUtils.account1, TomlInfoTestUtils.account2], info.accounts)

        // Documentation.
        guard let doc = info.documentaion else {
            XCTFail("expected documentation")
            return
        }
        XCTAssertEqual("Example Org", doc.orgName)
        XCTAssertEqual("Example DBA", doc.orgDba)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)", doc.orgUrl)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/logo.png", doc.orgLogo)
        XCTAssertEqual("An organization used for coverage tests.", doc.orgDescription)
        XCTAssertEqual("123 Test Street", doc.orgPhysicalAddress)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/address.pdf", doc.orgPhysicalAddressAttestation)
        XCTAssertEqual("+1 555 0100", doc.orgPhoneNumber)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/phone.pdf", doc.orgPhoneNumberAttestation)
        XCTAssertEqual("example", doc.orgKeybase)
        XCTAssertEqual("example", doc.orgTwitter)
        XCTAssertEqual("example", doc.orgGithub)
        XCTAssertEqual("info@\(TomlInfoTestUtils.richTomlDomain)", doc.orgOfficialEmail)
        XCTAssertEqual("support@\(TomlInfoTestUtils.richTomlDomain)", doc.orgSupportEmail)
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
        XCTAssertEqual("alice@\(TomlInfoTestUtils.richTomlDomain)", alice?.email)
        XCTAssertEqual("alice", alice?.keybase)
        XCTAssertEqual("alice_tg", alice?.telegram)
        XCTAssertEqual("alice_tw", alice?.twitter)
        XCTAssertEqual("alice_gh", alice?.github)
        XCTAssertEqual("aaa111", alice?.idPhotoHash)
        XCTAssertEqual("bbb222", alice?.verificationPhotoHash)
        let bob = principals.first { $0.name == "Bob Example" }
        XCTAssertNotNil(bob)
        XCTAssertEqual("bob@\(TomlInfoTestUtils.richTomlDomain)", bob?.email)
        XCTAssertNil(bob?.telegram)

        // Validators.
        guard let validators = info.validators else {
            XCTFail("expected validators")
            return
        }
        XCTAssertEqual(2, validators.count)
        let val1 = validators.first { $0.alias == "example-val-1" }
        XCTAssertNotNil(val1)
        XCTAssertEqual("Example Validator 1", val1?.displayName)
        XCTAssertEqual(TomlInfoTestUtils.validator1Key, val1?.publicKey)
        XCTAssertEqual("core1.\(TomlInfoTestUtils.richTomlDomain):11625", val1?.host)
        let val2 = validators.first { $0.alias == "example-val-2" }
        XCTAssertNotNil(val2)
        XCTAssertEqual(TomlInfoTestUtils.validator2Key, val2?.publicKey)

        // Currencies.
        guard let currencies = info.currencies else {
            XCTFail("expected currencies")
            return
        }
        XCTAssertEqual(2, currencies.count)

        let usdc = currencies.first { $0.code == "USDC" }
        XCTAssertNotNil(usdc)
        XCTAssertEqual(TomlInfoTestUtils.usdcIssuer, usdc?.issuer)
        XCTAssertEqual(2, usdc?.displayDecimals)
        XCTAssertEqual("USD Coin", usdc?.name)
        XCTAssertEqual("A US dollar stablecoin", usdc?.desc)
        XCTAssertEqual("No conditions apply", usdc?.conditions)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/usdc.png", usdc?.image)
        XCTAssertEqual("live", usdc?.status)
        XCTAssertEqual(1000000, usdc?.fixedNumber)
        XCTAssertEqual(2000000, usdc?.maxNumber)
        XCTAssertEqual(false, usdc?.isUnlimited)
        XCTAssertEqual(true, usdc?.isAssetAnchored)
        XCTAssertEqual("fiat", usdc?.anchorAssetType)
        XCTAssertEqual("USD", usdc?.anchorAsset)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/reserve.pdf", usdc?.attestationOfReserve)
        XCTAssertEqual("Contact support to redeem", usdc?.redemptionInstructions)
        XCTAssertEqual([TomlInfoTestUtils.account1, TomlInfoTestUtils.account2], usdc?.collateralAddresses)
        XCTAssertEqual(["msg1", "msg2"], usdc?.collateralAddressMessages)
        XCTAssertEqual(["sig1", "sig2"], usdc?.collateralAddressSignatures)
        XCTAssertEqual(true, usdc?.regulated)
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/approve", usdc?.approvalServer)
        XCTAssertEqual("Must be a verified customer", usdc?.approvalCriteria)

        // assetId of the issued currency resolves to an IssuedAssetId.
        let usdcAssetId = try usdc!.assetId
        guard let issuedAssetId = usdcAssetId as? IssuedAssetId else {
            XCTFail("expected IssuedAssetId, got \(type(of: usdcAssetId))")
            return
        }
        XCTAssertEqual("USDC", issuedAssetId.code)
        XCTAssertEqual(TomlInfoTestUtils.usdcIssuer, issuedAssetId.issuer)

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
        XCTAssertEqual("https://\(TomlInfoTestUtils.richTomlDomain)/sep31", services.sep31?.directPaymentServer)

        withExtendedLifetime(richTomlMock) {}
    }

    // MARK: - TomlInfo: minimal toml -> nil sections

    func testTomlInfoMinimalNilSections() async throws {
        let info = try await wallet.anchor(homeDomain: TomlInfoTestUtils.minimalTomlDomain).info

        XCTAssertEqual("2.0.0", info.version)
        XCTAssertEqual(TomlInfoTestUtils.serverAccountId, info.signingKey)
        XCTAssertEqual("Minimal Org", info.documentaion?.orgName)

        // Absent sections are reported as nil.
        XCTAssertNil(info.principals)
        XCTAssertNil(info.currencies)
        XCTAssertNil(info.validators)

        withExtendedLifetime(minimalTomlMock) {}
    }

    // MARK: - TomlInfo: InfoCurrency.assetId throws when code present but issuer absent

    func testInfoCurrencyAssetIdThrowsWhenIssuerMissing() async throws {
        let info = try await wallet.anchor(homeDomain: TomlInfoTestUtils.codeNoIssuerTomlDomain).info

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
}
