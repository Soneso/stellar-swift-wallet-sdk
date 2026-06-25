//
//  WalletConfigTest.swift
//
//
//  Offline unit tests covering the configuration model types of the wallet sdk:
//  Wallet, StellarConfig, AppConfig and Config.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

/// Test fixtures namespaced with the WalletConfigTest prefix to avoid collisions with other suites.
final class WalletConfigTestUtils {
    static let signerHost = "domain-signer.walletconfig.example"
    static let signerUrl = "https://\(signerHost)/sign"
}

final class WalletConfigTest: XCTestCase {

    let wallet = Wallet.testNet

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    func testStellarConfigTestNet() {
        let cfg = StellarConfig.testNet
        XCTAssertEqual(Network.testnet.passphrase, cfg.network.passphrase)
        XCTAssertEqual(StellarSDK.testNetUrl, cfg.horizonUrl)
        XCTAssertEqual(100, cfg.baseFee)
        XCTAssertEqual(300, cfg.txTimeout)
    }

    func testStellarConfigPublicNet() {
        let cfg = StellarConfig.publicNet
        XCTAssertEqual(Network.public.passphrase, cfg.network.passphrase)
        XCTAssertEqual(StellarSDK.publicNetUrl, cfg.horizonUrl)
    }

    func testStellarConfigFutureNet() {
        let cfg = StellarConfig.futureNet
        XCTAssertEqual(Network.futurenet.passphrase, cfg.network.passphrase)
        XCTAssertEqual(StellarSDK.futureNetUrl, cfg.horizonUrl)
    }

    func testStellarConfigCustomValues() {
        let cfg = StellarConfig(network: Network.testnet,
                                horizonUrl: "https://custom.horizon.example",
                                baseFee: 250,
                                txTimeout: 120)
        XCTAssertEqual("https://custom.horizon.example", cfg.horizonUrl)
        XCTAssertEqual(250, cfg.baseFee)
        XCTAssertEqual(120, cfg.txTimeout)
    }

    func testAppConfigDefaults() {
        let cfg = AppConfig()
        XCTAssertTrue(cfg.defaultSigner is DefaultSigner)
        XCTAssertNil(cfg.defaultClientDomain)
    }

    func testAppConfigCustomSignerAndDomain() throws {
        let domainSigner = try DomainSigner(url: WalletConfigTestUtils.signerUrl)
        let cfg = AppConfig(defaultSigner: domainSigner, defaultClientDomain: "client.example")
        XCTAssertTrue(cfg.defaultSigner is DomainSigner)
        XCTAssertEqual("client.example", cfg.defaultClientDomain)
    }

    func testConfigHoldsStellarAndApp() {
        let stellarCfg = StellarConfig.testNet
        let appCfg = AppConfig()
        let config = Config(stellar: stellarCfg, app: appCfg)
        XCTAssertTrue(config.stellar === stellarCfg)
        XCTAssertTrue(config.app === appCfg)
    }

    func testWalletTestNet() {
        let w = Wallet.testNet
        XCTAssertEqual(Network.testnet.passphrase, w.stellarConfig.network.passphrase)
        XCTAssertEqual(StellarSDK.testNetUrl, w.stellarConfig.horizonUrl)
        XCTAssertTrue(w.appConfig.defaultSigner is DefaultSigner)
    }

    func testWalletPublicNet() {
        let w = Wallet.publicNet
        XCTAssertEqual(Network.public.passphrase, w.stellarConfig.network.passphrase)
    }

    func testWalletFutureNet() {
        let w = Wallet.futureNet
        XCTAssertEqual(Network.futurenet.passphrase, w.stellarConfig.network.passphrase)
    }

    func testWalletConvenienceInitUsesDefaultAppConfig() {
        let w = Wallet(stellarConfig: StellarConfig.testNet)
        XCTAssertTrue(w.appConfig.defaultSigner is DefaultSigner)
        XCTAssertNil(w.appConfig.defaultClientDomain)
    }

    func testWalletAnchorReturnsConfiguredHomeDomain() {
        let anchor = wallet.anchor(homeDomain: "my.anchor.example")
        XCTAssertEqual("my.anchor.example", anchor.homeDomain)
    }

    func testWalletVersionNumberIsSet() {
        XCTAssertFalse(Wallet.versionNumber.isEmpty)
    }
}
