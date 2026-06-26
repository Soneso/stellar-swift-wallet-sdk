//
//  AnchorTest.swift
//
//
//  Offline coverage for Anchor.swift service-discovery error branches and
//  stellar.toml info parsing edge cases.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class AnchorTestUtils {

    // Domain that resolves to a stellar.toml exposing SEP-24, SEP-10, KYC and quote services.
    static let fullAnchorDomain = "full.anchortest.com"
    // Domain whose stellar.toml only exposes a signing key (no services at all).
    static let emptyAnchorDomain = "empty.anchortest.com"

    static let apiHost = "api.anchortest.org"
    static let webAuthEndpoint = "https://\(apiHost)/auth"

    static let interactiveHost = "sep24.anchortest.org"
    static let quoteHost = "sep38.anchortest.org"
    static let kycHost = "sep12.anchortest.org"

    static let interactiveServer = "https://\(interactiveHost)"
    static let quoteServer = "http://\(quoteHost)/quotes-sep38"
    static let kycServer = "http://\(kycHost)/kyc"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"

    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)

    static let usdcAsset = try! IssuedAssetId(code: "USDC",
                                              issuer: "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM")
}

final class AnchorTest: XCTestCase {

    let wallet = Wallet.testNet
    var fullTomlMock: TomlResponseMock!
    var emptyTomlMock: TomlResponseMock!
    var challengeMock: WebAuthChallengeResponseMock!
    var sendChallengeMock: WebAuthSendChallengeResponseMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        fullTomlMock = TomlResponseMock(host: AnchorTestUtils.fullAnchorDomain,
                                        serverSigningKey: AnchorTestUtils.serverAccountId,
                                        authServer: AnchorTestUtils.webAuthEndpoint,
                                        sep24TransferServer: AnchorTestUtils.interactiveServer,
                                        anchorQuoteServer: AnchorTestUtils.quoteServer,
                                        kycServer: AnchorTestUtils.kycServer)

        // No service URLs, only a signing key -> all services unavailable.
        emptyTomlMock = TomlResponseMock(host: AnchorTestUtils.emptyAnchorDomain,
                                         serverSigningKey: AnchorTestUtils.serverAccountId)

        challengeMock = WebAuthChallengeResponseMock(host: AnchorTestUtils.apiHost,
                                                     serverKeyPair: AnchorTestUtils.serverKeypair,
                                                     homeDomain: AnchorTestUtils.fullAnchorDomain)
        sendChallengeMock = WebAuthSendChallengeResponseMock(host: AnchorTestUtils.apiHost)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - helpers

    private func fullAnchor() -> Anchor {
        return wallet.anchor(homeDomain: AnchorTestUtils.fullAnchorDomain)
    }

    private func authToken(for anchor: Anchor) async throws -> AuthToken {
        let authKey = try SigningKeyPair(secretKey: AnchorTestUtils.userSecretSeed)
        return try await anchor.sep10.authenticate(userKeyPair: authKey)
    }

    // MARK: - Anchor.swift service-discovery error branches

    func testSep10NotSupportedWhenNoWebAuth() async throws {
        let anchor = wallet.anchor(homeDomain: AnchorTestUtils.emptyAnchorDomain)
        do {
            _ = try await anchor.sep10
            XCTFail("expected AnchorAuthError.notSupported")
        } catch AnchorAuthError.notSupported {
            // expected
        }
    }

    func testSep38QuoteServerNotFound() async throws {
        let anchor = wallet.anchor(homeDomain: AnchorTestUtils.emptyAnchorDomain)
        do {
            _ = try await anchor.sep38(authToken: nil)
            XCTFail("expected AnchorError.quoteServerNotFound")
        } catch AnchorError.quoteServerNotFound {
            // expected
        }
    }

    func testSep12KycServerNotFound() async throws {
        let anchor = wallet.anchor(homeDomain: AnchorTestUtils.emptyAnchorDomain)
        let token = try await fullAnchor().sep10.authenticate(
            userKeyPair: try SigningKeyPair(secretKey: AnchorTestUtils.userSecretSeed))
        do {
            _ = try await anchor.sep12(authToken: token)
            XCTFail("expected AnchorError.kycServerNotFound")
        } catch AnchorError.kycServerNotFound {
            // expected
        }
    }

    func testTomlInfoServicesAndHasAuth() async throws {
        let info = try await fullAnchor().info
        XCTAssertTrue(info.hasAuth)
        let services = info.services
        XCTAssertNotNil(services.sep10)
        XCTAssertEqual(AnchorTestUtils.webAuthEndpoint, services.sep10?.webAuthEndpoint)
        XCTAssertEqual(AnchorTestUtils.serverAccountId, services.sep10?.signingKey)
        XCTAssertNotNil(services.sep24)
        XCTAssertTrue(services.sep24?.hasAuth ?? false)
        XCTAssertEqual(AnchorTestUtils.interactiveServer, services.sep24?.transferServerSep24)
        XCTAssertNotNil(services.sep12)
        XCTAssertEqual(AnchorTestUtils.kycServer, services.sep12?.kycServer)
        // sep6 transfer server and sep31 direct payment server are not configured here.
        XCTAssertNil(services.sep6)
        XCTAssertNil(services.sep31)

        // currencies parsed from [[CURRENCIES]] entries with assetId resolution.
        guard let currencies = info.currencies else {
            XCTFail("currencies expected")
            return
        }
        XCTAssertEqual(2, currencies.count)
        let usdc = currencies.first { $0.code == "USDC" }
        XCTAssertNotNil(usdc)
        XCTAssertEqual(2, usdc?.displayDecimals)
        let usdcAssetId = try usdc!.assetId
        XCTAssertTrue(usdcAssetId is IssuedAssetId)
        XCTAssertEqual("USDC", (usdcAssetId as! IssuedAssetId).code)
    }

    func testEmptyTomlServicesAllNil() async throws {
        let info = try await wallet.anchor(homeDomain: AnchorTestUtils.emptyAnchorDomain).info
        XCTAssertFalse(info.hasAuth)
        let services = info.services
        XCTAssertNil(services.sep6)
        XCTAssertNil(services.sep10)
        XCTAssertNil(services.sep12)
        XCTAssertNil(services.sep24)
        XCTAssertNil(services.sep31)
    }
}
