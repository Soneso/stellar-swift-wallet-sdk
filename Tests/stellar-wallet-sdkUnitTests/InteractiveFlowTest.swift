//
//  InteractiveFlowTest.swift
//  
//
//  Created by Christian Rogobete on 08.01.25.
//

import XCTest
import stellarsdk
import Foundation
@testable import stellar_wallet_sdk

final class InteractiveFlowTestUtils {

    static let anchorHost = "place.anchor.com"
    static let anchorWebAuthHost = "api.anchor.org"
    static let webAuthEndpoint = "https://\(anchorWebAuthHost)/auth"
    static let anchorInteractiveHost = "t24.anchor.org"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userAccountId = "GB4L7JUU5DENUXYH3ANTLVYQL66KQLDDJTN5SF7MWEDGWSGUA375V44V"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"
    
    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)
    static let userKeypair = try! KeyPair(secretSeed: userSecretSeed)
    
    static let existingTxId = "82fhs729f63dh0v4"
    static let extistingStellarTxId = "17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a"
    static let pendingTxId = "55fhs729f63dh0v5"
    
}

final class InteractiveFlowTest: XCTestCase {

    let wallet = Wallet.testNet
    var anchorTomlServerMock: TomlResponseMock!
    var challengeServerMock: WebAuthChallengeResponseMock!
    var sendChallengeServerMock: WebAuthSendChallengeResponseMock!
    var infoServerMock: InteractiveInfoResponseMock!
    var depositServerMock: InteractiveDepositResponseMock!
    var withdrawServerMock: InteractiveWithdrawResponseMock!
    var singleTxServerMock:InteractiveSingleTxResponseMock!
    var multipeTxServerMock:InteractiveMultipleTxResponseMock!

    var sep24FullTomlMock: TomlResponseMock!
    var sep24EmptyTomlMock: TomlResponseMock!
    var sep24ChallengeMock: WebAuthChallengeResponseMock!
    var sep24SendChallengeMock: WebAuthSendChallengeResponseMock!
    var sep24InteractiveInfoMock: Sep24TestInteractiveInfoMock!
    var sep24InteractiveInitMock: Sep24TestInteractiveInitMock!
    var sep24InteractiveTxMock: Sep24TestInteractiveTxMock!
    var sep24InteractiveTxsMock: Sep24TestInteractiveTxsMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        anchorTomlServerMock = TomlResponseMock(host: InteractiveFlowTestUtils.anchorHost,
                                                       serverSigningKey: InteractiveFlowTestUtils.serverAccountId,
                                                       authServer: InteractiveFlowTestUtils.webAuthEndpoint,
                                                       sep24TransferServer: "https://\(InteractiveFlowTestUtils.anchorInteractiveHost)")

        challengeServerMock = WebAuthChallengeResponseMock(host: InteractiveFlowTestUtils.anchorWebAuthHost,
                                                           serverKeyPair: InteractiveFlowTestUtils.serverKeypair)

        sendChallengeServerMock = WebAuthSendChallengeResponseMock(host: InteractiveFlowTestUtils.anchorWebAuthHost)
        infoServerMock = InteractiveInfoResponseMock(host: InteractiveFlowTestUtils.anchorInteractiveHost)
        depositServerMock = InteractiveDepositResponseMock(host: InteractiveFlowTestUtils.anchorInteractiveHost)
        withdrawServerMock = InteractiveWithdrawResponseMock(host: InteractiveFlowTestUtils.anchorInteractiveHost)
        singleTxServerMock = InteractiveSingleTxResponseMock(host: InteractiveFlowTestUtils.anchorInteractiveHost)
        multipeTxServerMock = InteractiveMultipleTxResponseMock(host: InteractiveFlowTestUtils.anchorInteractiveHost)

        sep24FullTomlMock = TomlResponseMock(host: Sep24TestUtils.fullAnchorDomain,
                                        serverSigningKey: Sep24TestUtils.serverAccountId,
                                        authServer: Sep24TestUtils.webAuthEndpoint,
                                        sep24TransferServer: Sep24TestUtils.interactiveServer,
                                        anchorQuoteServer: Sep24TestUtils.quoteServer,
                                        kycServer: Sep24TestUtils.kycServer)

        // No service URLs, only a signing key -> all services unavailable.
        sep24EmptyTomlMock = TomlResponseMock(host: Sep24TestUtils.emptyAnchorDomain,
                                         serverSigningKey: Sep24TestUtils.serverAccountId)

        sep24ChallengeMock = WebAuthChallengeResponseMock(host: Sep24TestUtils.apiHost,
                                                     serverKeyPair: Sep24TestUtils.serverKeypair,
                                                     homeDomain: Sep24TestUtils.fullAnchorDomain)
        sep24SendChallengeMock = WebAuthSendChallengeResponseMock(host: Sep24TestUtils.apiHost)

        sep24InteractiveInfoMock = Sep24TestInteractiveInfoMock(host: Sep24TestUtils.interactiveHost)
        sep24InteractiveInitMock = Sep24TestInteractiveInitMock(host: Sep24TestUtils.interactiveHost)
        sep24InteractiveTxMock = Sep24TestInteractiveTxMock(host: Sep24TestUtils.interactiveHost)
        sep24InteractiveTxsMock = Sep24TestInteractiveTxsMock(host: Sep24TestUtils.interactiveHost)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - SEP-24 helpers

    private func sep24FullAnchor() -> Anchor {
        return wallet.anchor(homeDomain: Sep24TestUtils.fullAnchorDomain)
    }

    private func sep24AuthToken(for anchor: Anchor) async throws -> AuthToken {
        let authKey = try SigningKeyPair(secretKey: Sep24TestUtils.userSecretSeed)
        return try await anchor.sep10.authenticate(userKeyPair: authKey)
    }

    func testAll() async throws {
        try await infoTest()
        try await depositTest()
        try await withdrawTest()
        try await getTransactionTest()
        try await getTransactionsForAssetTest()
        try await watchOneTransactionTest()
        try await watchOnAssetTest()
    }
    
    func infoTest() async throws {
        let anchor = wallet.anchor(homeDomain: InteractiveFlowTestUtils.anchorHost)
        do {
            let info = try await anchor.sep24.info
            XCTAssertEqual(3, info.deposit.count)
            
            guard let depositAssetUSDC = info.deposit["USDC"] else {
                XCTFail("depost asset USDC not found")
                return
            }
            XCTAssertTrue(depositAssetUSDC.enabled)
            XCTAssertEqual(5.0, depositAssetUSDC.feeFixed)
            XCTAssertEqual(1.0, depositAssetUSDC.feePercent)
            XCTAssertNil(depositAssetUSDC.feeMinimum)
            XCTAssertEqual(0.1, depositAssetUSDC.minAmount)
            XCTAssertEqual(1000.0, depositAssetUSDC.maxAmount)
            
            guard let depositAssetETH = info.deposit["ETH"] else {
                XCTFail("depost asset ETH not found")
                return
            }
            XCTAssertTrue(depositAssetETH.enabled)
            XCTAssertEqual(0.002, depositAssetETH.feeFixed)
            XCTAssertEqual(0.0, depositAssetETH.feePercent)
            XCTAssertNil(depositAssetETH.feeMinimum)
            XCTAssertNil(depositAssetETH.minAmount)
            XCTAssertNil(depositAssetETH.maxAmount)
            
            guard let depositAssetNative = info.deposit["native"] else {
                XCTFail("depost asset native not found")
                return
            }
            XCTAssertTrue(depositAssetNative.enabled)
            XCTAssertEqual(0.00001, depositAssetNative.feeFixed)
            XCTAssertEqual(0.0, depositAssetNative.feePercent)
            XCTAssertNil(depositAssetNative.feeMinimum)
            XCTAssertNil(depositAssetNative.minAmount)
            XCTAssertNil(depositAssetNative.maxAmount)
            
            guard let withdrawAssetUSDC = info.withdraw["USDC"] else {
                XCTFail("withdraw asset USDC not found")
                return
            }
            XCTAssertTrue(withdrawAssetUSDC.enabled)
            XCTAssertEqual(5.0, withdrawAssetUSDC.feeMinimum)
            XCTAssertEqual(0.5, withdrawAssetUSDC.feePercent)
            XCTAssertNil(withdrawAssetUSDC.feeFixed)
            XCTAssertEqual(0.1, withdrawAssetUSDC.minAmount)
            XCTAssertEqual(1000.0, withdrawAssetUSDC.maxAmount)
            
            guard let withdrawAssetETH = info.withdraw["ETH"] else {
                XCTFail("withdraw asset ETH not found")
                return
            }
            XCTAssertFalse(withdrawAssetETH.enabled)
            
            guard let withdrawAssetNative = info.withdraw["native"] else {
                XCTFail("withdraw asset native not found")
                return
            }
            XCTAssertTrue(withdrawAssetNative.enabled)
            
            XCTAssertFalse(info.fee.enabled)
            
            guard let features = info.features else {
                XCTFail("features not found in info")
                return
            }
            
            XCTAssertTrue(features.accountCreation)
            XCTAssertTrue(features.claimableBalances)
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func depositTest() async throws {
        let anchor = wallet.anchor(homeDomain: InteractiveFlowTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: InteractiveFlowTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let anchorInfo = try await anchor.info
            guard let currencies = anchorInfo.currencies else {
                XCTFail("no currencies found in anchor stellar toml info")
                return
            }
            
            guard let usdcCurrencyInfo = currencies.filter({ $0.code == "USDC" }).first else {
                XCTFail("currency info for USDC not found in anchor stellar toml info")
                return
            }
            
            let usdcAssetId = try usdcCurrencyInfo.assetId
        
            var depositResponse = try await anchor.sep24.deposit(assetId: usdcAssetId, authToken: authToken)
            XCTAssertEqual("82fhs729f63dh0v4", depositResponse.id)
            XCTAssertEqual("completed", depositResponse.type)
            XCTAssertEqual("https://api.example.com/kycflow?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI", depositResponse.url)
            
            // optionally, one can also add sep-9 extra fields and/or files
            let extraFields:[String:String] = [Sep9PersonKeys.emailAddress:"mail@example.com",
                                               Sep9PersonKeys.mobileNumber:"+12383844421"]
            
            let photoIdFront:Data = "😃".data(using: .nonLossyASCII, allowLossyConversion: true)!
            let extraFiles:[String:Data] = [Sep9PersonKeys.photoIdFront:photoIdFront]
            
            depositResponse = try await anchor.sep24.deposit(assetId: usdcAssetId, 
                                                             authToken: authToken,
                                                             extraFields: extraFields,
                                                             extraFiles: extraFiles)
            XCTAssertEqual("82fhs729f63dh0v4", depositResponse.id)
            
            // Deposit with alternative account
            let recepientAccountId = "GC74AI6HKRZN3OUVDUGVEA46F35E6OFA2S3OJOH33XXWQHQ5OB5J7YYI"
            depositResponse = try await anchor.sep24.deposit(assetId: usdcAssetId,
                                                             authToken: authToken,
                                                             destinationAccount: recepientAccountId)
            XCTAssertEqual("82fhs729f63dh0v4", depositResponse.id)
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    
    func withdrawTest() async throws {
        let anchor = wallet.anchor(homeDomain: InteractiveFlowTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: InteractiveFlowTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let anchorInfo = try await anchor.info
            guard let currencies = anchorInfo.currencies else {
                XCTFail("no currencies found in anchor stellar toml info")
                return
            }
            
            guard let usdcCurrencyInfo = currencies.filter({ $0.code == "USDC" }).first else {
                XCTFail("currency info for USDC not found in anchor stellar toml info")
                return
            }
            
            let usdcAssetId = try usdcCurrencyInfo.assetId
            
            let withdrawResponse = try await anchor.sep24.withdraw(assetId: usdcAssetId, authToken: authToken)
            XCTAssertEqual("82fhs729f63dh0v4", withdrawResponse.id)
            XCTAssertEqual("completed", withdrawResponse.type)
            XCTAssertEqual("https://api.example.com/kycflow?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI", withdrawResponse.url)
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func getTransactionTest() async throws {
        let anchor = wallet.anchor(homeDomain: InteractiveFlowTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: InteractiveFlowTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            let tx = try await anchor.sep24.getTransactionBy(authToken: authToken, transactionId:InteractiveFlowTestUtils.existingTxId)
            XCTAssertEqual(InteractiveFlowTestUtils.existingTxId, tx.id)
            guard let tx = tx as? WithdrawalTransaction else {
                XCTFail("not a withdrawal tx as expected")
                return
            }
            XCTAssertEqual("510", tx.amountIn)
            XCTAssertEqual("490", tx.amountOut)
            XCTAssertEqual("5", tx.amountFee)
            XCTAssertEqual("https://youranchor.com/tx/242523523", tx.moreInfoUrl)
            XCTAssertEqual("17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a", tx.stellarTransactionId)
            XCTAssertEqual("1941491", tx.externalTransactionId)
            XCTAssertEqual("GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL", tx.withdrawAnchorAccount)
            XCTAssertEqual("186384", tx.withdrawalMemo)
            XCTAssertEqual("id", tx.withdrawalMemoType)
            guard let refunds = tx.refunds else {
                XCTFail("refunds not found as expected")
                return
            }
            XCTAssertEqual("10", refunds.amountRefunded)
            XCTAssertEqual("5", refunds.amountFee)
            XCTAssertEqual(1, refunds.payments.count)
            let refundPayment = refunds.payments.first!
            XCTAssertEqual("b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020", refundPayment.id)
            XCTAssertEqual("stellar", refundPayment.idType)
            XCTAssertEqual("10", refundPayment.amount)
            XCTAssertEqual("5", refundPayment.fee)
            
            let tx2 = try await anchor.sep24.getTransactionBy(authToken: authToken,
                                                              stellarTransactionId: InteractiveFlowTestUtils.extistingStellarTxId)
            XCTAssertEqual(InteractiveFlowTestUtils.existingTxId, tx2.id)
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func getTransactionsForAssetTest() async throws {
        let anchor = wallet.anchor(homeDomain: InteractiveFlowTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: InteractiveFlowTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            let txs = try await anchor.sep24.getTransactionsForAsset(authToken: authToken,
                                                                     asset: IssuedAssetId(code: "USDC",
                                                                                         issuer: "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"))
        
            guard let tx = txs.first else {
                XCTFail("no transaction obtained as expected")
                return
            }
            XCTAssertEqual(InteractiveFlowTestUtils.existingTxId, tx.id)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func watchOneTransactionTest() async throws {
        let anchor = wallet.anchor(homeDomain: InteractiveFlowTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: InteractiveFlowTestUtils.userSecretSeed)
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            let watcher = anchor.sep24.watcher()
            let result = watcher.watchOneTransaction(authToken: authToken, 
                                                     id: InteractiveFlowTestUtils.pendingTxId)
            let txObserver = TxObserver()
            NotificationCenter.default.addObserver(txObserver,
                                                   selector: #selector(txObserver.handleEvent(_:)),
                                                   name: result.notificationName,
                                                   object: nil)
            
            try! await Task.sleep(nanoseconds: UInt64(10 * Double(NSEC_PER_SEC)))
            result.stop()
            XCTAssertEqual(1, txObserver.successCount)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func watchOnAssetTest() async throws {
        let anchor = wallet.anchor(homeDomain: InteractiveFlowTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: InteractiveFlowTestUtils.userSecretSeed)
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            let watcher = anchor.sep24.watcher()
            let result = watcher.watchAsset(authToken: authToken, 
                                            asset: try IssuedAssetId(code: "ETH", 
                                                                     issuer: "GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U"))
            let txObserver = TxObserver()
            NotificationCenter.default.addObserver(txObserver,
                                                   selector: #selector(txObserver.handleEvent(_:)),
                                                   name: result.notificationName,
                                                   object: nil)
            
            try! await Task.sleep(nanoseconds: UInt64(25 * Double(NSEC_PER_SEC)))
            result.stop()
            XCTAssertEqual(3, txObserver.successCount)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }

    // MARK: - Sep24.swift validation / not-supported branches

    func testSep24DepositInteractiveFlowNotSupported() async throws {
        let anchor = wallet.anchor(homeDomain: Sep24TestUtils.emptyAnchorDomain)
        let token = try await sep24AuthToken(for: sep24FullAnchor())
        do {
            _ = try await anchor.sep24.deposit(assetId: Sep24TestUtils.usdcAsset, authToken: token)
            XCTFail("expected interactiveFlowNotSupported")
        } catch AnchorError.interactiveFlowNotSupported {
            // expected
        }
    }

    func testSep24WithdrawInteractiveFlowNotSupported() async throws {
        let anchor = wallet.anchor(homeDomain: Sep24TestUtils.emptyAnchorDomain)
        let token = try await sep24AuthToken(for: sep24FullAnchor())
        do {
            _ = try await anchor.sep24.withdraw(assetId: Sep24TestUtils.usdcAsset, authToken: token)
            XCTFail("expected interactiveFlowNotSupported")
        } catch AnchorError.interactiveFlowNotSupported {
            // expected
        }
    }

    func testSep24DepositAssetNotAccepted() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        // EUR is not present in the interactive info mock -> not accepted for deposit.
        let eur = try IssuedAssetId(code: "EUR", issuer: Sep24TestUtils.usdcAsset.issuer)
        do {
            _ = try await anchor.sep24.deposit(assetId: eur, authToken: token)
            XCTFail("expected assetNotAcceptedForDeposit")
        } catch InteractiveFlowError.assetNotAcceptedForDeposit(let assetId) {
            XCTAssertEqual("EUR", (assetId as? IssuedAssetId)?.code)
        }
    }

    func testSep24DepositAssetNotEnabled() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        // BTC is present but disabled for deposit in the interactive info mock.
        let btc = try IssuedAssetId(code: "BTC", issuer: Sep24TestUtils.usdcAsset.issuer)
        do {
            _ = try await anchor.sep24.deposit(assetId: btc, authToken: token)
            XCTFail("expected assetNotEnabledForDeposit")
        } catch InteractiveFlowError.assetNotEnabledForDeposit(let assetId) {
            XCTAssertEqual("BTC", (assetId as? IssuedAssetId)?.code)
        }
    }

    func testSep24WithdrawAssetNotAccepted() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        let eur = try IssuedAssetId(code: "EUR", issuer: Sep24TestUtils.usdcAsset.issuer)
        do {
            _ = try await anchor.sep24.withdraw(assetId: eur, authToken: token)
            XCTFail("expected assetNotAcceptedForWithdrawal")
        } catch InteractiveFlowError.assetNotAcceptedForWithdrawal(let assetId) {
            XCTAssertEqual("EUR", (assetId as? IssuedAssetId)?.code)
        }
    }

    func testSep24WithdrawAssetNotEnabled() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        // BTC is present but disabled for withdrawal in the interactive info mock.
        let btc = try IssuedAssetId(code: "BTC", issuer: Sep24TestUtils.usdcAsset.issuer)
        do {
            _ = try await anchor.sep24.withdraw(assetId: btc, authToken: token)
            XCTFail("expected assetNotEnabledForWithdrawal")
        } catch InteractiveFlowError.assetNotEnabledForWithdrawal(let assetId) {
            XCTAssertEqual("BTC", (assetId as? IssuedAssetId)?.code)
        }
    }

    func testSep24GetTransactionByRequiresAnId() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token)
            XCTFail("expected ValidationError.invalidArgument")
        } catch ValidationError.invalidArgument(let message) {
            XCTAssertTrue(message.contains("transactionId"))
        }
    }

    func testSep24DepositServerError() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        // USDC deposit is enabled in info but the init endpoint returns a 400 anchor error.
        do {
            _ = try await anchor.sep24.deposit(assetId: Sep24TestUtils.usdcAsset, authToken: token)
            XCTFail("expected InteractiveServiceError.anchorError")
        } catch InteractiveServiceError.anchorError(let message) {
            XCTAssertEqual("deposit temporarily disabled", message)
        }
    }

    func testSep24WithdrawServerNotFound() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        sep24InteractiveInitMock.withdrawStatusCode = 404
        do {
            _ = try await anchor.sep24.withdraw(assetId: Sep24TestUtils.usdcAsset, authToken: token)
            XCTFail("expected InteractiveServiceError.notFound")
        } catch InteractiveServiceError.notFound {
            // expected
        }
    }

    // MARK: - InteractiveFlowTransaction.fromTx parsing edge cases

    func testGetTransactionInvalidStatus() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "bad-status")
            XCTFail("expected invalidAnchorResponse for invalid status")
        } catch AnchorError.invalidAnchorResponse(let message) {
            XCTAssertTrue(message.contains("status"))
        }
    }

    func testGetTransactionInvalidKind() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "bad-kind")
            XCTFail("expected invalidAnchorResponse for invalid kind")
        } catch AnchorError.invalidAnchorResponse(let message) {
            XCTAssertTrue(message.contains("kind"))
        }
    }

    func testGetTransactionUnsupportedKind() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        // kind "deposit-exchange" is a valid TransactionKind but unsupported by fromTx (default branch).
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "exchange-kind")
            XCTFail("expected invalidAnchorResponse for unsupported kind")
        } catch AnchorError.invalidAnchorResponse(let message) {
            XCTAssertTrue(message.contains("kind"))
        }
    }

    func testGetIncompleteDepositTransaction() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "incomplete-deposit")
        XCTAssertEqual("incomplete-deposit", tx.id)
        XCTAssertEqual(.incomplete, tx.transactionStatus)
        guard let incomplete = tx as? IncompleteDepositTransaction else {
            XCTFail("expected IncompleteDepositTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual("GDESTINATIONACCOUNT", incomplete.to)
        XCTAssertEqual("https://anchor.example/more", incomplete.moreInfoUrl)
    }

    func testGetIncompleteWithdrawalTransaction() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "incomplete-withdrawal")
        XCTAssertEqual(.incomplete, tx.transactionStatus)
        guard let incomplete = tx as? IncompleteWithdrawalTransaction else {
            XCTFail("expected IncompleteWithdrawalTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual("GSOURCEACCOUNT", incomplete.from)
    }

    func testGetErrorDepositTransaction() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "error-deposit")
        XCTAssertEqual(.error, tx.transactionStatus)
        guard let errorTx = tx as? ErrorTransaction else {
            XCTFail("expected ErrorTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual(.deposit, errorTx.kind)
        XCTAssertEqual("something went wrong", errorTx.message)
        XCTAssertEqual(true, errorTx.refunded)
        XCTAssertEqual("18.34", errorTx.amountIn)
        XCTAssertEqual("GDEPOSITTO", errorTx.to)
        XCTAssertEqual("memodeposit", errorTx.depositMemo)
        XCTAssertEqual("text", errorTx.depositMemoType)
        XCTAssertEqual("balance-id-xyz", errorTx.claimableBalanceId)
    }

    func testGetErrorWithdrawalTransaction() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "error-withdrawal")
        guard let errorTx = tx as? ErrorTransaction else {
            XCTFail("expected ErrorTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual(.withdrawal, errorTx.kind)
        XCTAssertEqual("GANCHORACCOUNT", errorTx.withdrawAnchorAccount)
        XCTAssertEqual("777", errorTx.withdrawalMemo)
        XCTAssertEqual("id", errorTx.withdrawalMemoType)
    }

    func testGetDepositTransactionWithRefunds() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "deposit-complete")
        guard let deposit = tx as? DepositTransaction else {
            XCTFail("expected DepositTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual(.completed, deposit.transactionStatus)
        XCTAssertEqual("GFROMADDR", deposit.from)
        XCTAssertEqual("GTOADDR", deposit.to)
        XCTAssertEqual("dmemo", deposit.depositMemo)
        XCTAssertEqual("text", deposit.depositMemoType)
        XCTAssertEqual(true, deposit.kycVerified)
        XCTAssertEqual("stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN", deposit.amountInAsset)
        guard let refunds = deposit.refunds else {
            XCTFail("expected refunds")
            return
        }
        XCTAssertEqual("10", refunds.amountRefunded)
        XCTAssertEqual("5", refunds.amountFee)
        XCTAssertEqual(2, refunds.payments.count)
        XCTAssertEqual("p1", refunds.payments[0].id)
        XCTAssertEqual("stellar", refunds.payments[0].idType)
        XCTAssertEqual("external", refunds.payments[1].idType)
    }

    func testGetDepositTransactionWithoutRefunds() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "deposit-norefund")
        guard let deposit = tx as? DepositTransaction else {
            XCTFail("expected DepositTransaction, got \(type(of: tx))")
            return
        }
        // refunds object absent -> nil (Refunds.fromSep24Refund returns nil).
        XCTAssertNil(deposit.refunds)
        XCTAssertNil(deposit.amountInAsset)
        XCTAssertNil(deposit.kycVerified)
        XCTAssertEqual(.pendingAnchor, deposit.transactionStatus)
    }

    func testGetTransactionMalformedJson() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "malformed")
            XCTFail("expected parsingResponseFailed")
        } catch InteractiveServiceError.parsingResponseFailed {
            // expected
        }
    }

    func testGetTransactionsForAssetNotSupported() async throws {
        let anchor = wallet.anchor(homeDomain: Sep24TestUtils.emptyAnchorDomain)
        let token = try await sep24AuthToken(for: sep24FullAnchor())
        do {
            _ = try await anchor.sep24.getTransactionsForAsset(authToken: token, asset: Sep24TestUtils.usdcAsset)
            XCTFail("expected interactiveFlowNotSupported")
        } catch AnchorError.interactiveFlowNotSupported {
            // expected
        }
    }

    func testGetTransactionsForAssetMixedKinds() async throws {
        let anchor = sep24FullAnchor()
        let token = try await sep24AuthToken(for: anchor)
        let txs = try await anchor.sep24.getTransactionsForAsset(authToken: token, asset: Sep24TestUtils.usdcAsset)
        XCTAssertEqual(2, txs.count)
        XCTAssertTrue(txs[0] is DepositTransaction)
        XCTAssertTrue(txs[1] is WithdrawalTransaction)
    }

    // MARK: - Sep24Info parsing edge cases

    func testSep24InfoDefaultsWhenFeeAndFeaturesMissing() async throws {
        let anchor = sep24FullAnchor()
        sep24InteractiveInfoMock.useMinimalInfo = true
        let info = try await anchor.sep24.info
        // No fee block -> Sep24ServiceFee disabled default.
        XCTAssertFalse(info.fee.enabled)
        XCTAssertFalse(info.fee.authenticationRequired)
        // No features block -> features nil.
        XCTAssertNil(info.features)
        // Empty deposit/withdraw maps.
        XCTAssertTrue(info.deposit.isEmpty)
        XCTAssertTrue(info.withdraw.isEmpty)
    }

    func testSep24InfoMalformedJson() async throws {
        let anchor = sep24FullAnchor()
        sep24InteractiveInfoMock.malformed = true
        do {
            _ = try await anchor.sep24.info
            XCTFail("expected parsingResponseFailed")
        } catch InteractiveServiceError.parsingResponseFailed {
            // expected
        }
    }

    func testSep24InfoServiceAssetLookup() async throws {
        let anchor = sep24FullAnchor()
        let info = try await anchor.sep24.info
        XCTAssertNotNil(info.depositServiceAsset(assetId: Sep24TestUtils.usdcAsset))
        XCTAssertNotNil(info.withdrawServiceAsset(assetId: Sep24TestUtils.usdcAsset))
        let native = NativeAssetId()
        XCTAssertNotNil(info.depositServiceAsset(assetId: native))
        let unknown = try IssuedAssetId(code: "EUR", issuer: Sep24TestUtils.usdcAsset.issuer)
        XCTAssertNil(info.depositServiceAsset(assetId: unknown))
    }
}

class InteractiveInfoResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.requestSuccess()
        }
        
        return RequestMock(host: host,
                           path: "/info",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestSuccess() -> String {
        return "{  \"deposit\": {    \"USDC\": {      \"enabled\": true,      \"fee_fixed\": 5,      \"fee_percent\": 1,      \"min_amount\": 0.1,      \"max_amount\": 1000    },    \"ETH\": {      \"enabled\": true,      \"fee_fixed\": 0.002,      \"fee_percent\": 0    },    \"native\": {      \"enabled\": true,      \"fee_fixed\": 0.00001,      \"fee_percent\": 0    }  },  \"withdraw\": {    \"USDC\": {      \"enabled\": true,      \"fee_minimum\": 5,      \"fee_percent\": 0.5,      \"min_amount\": 0.1,      \"max_amount\": 1000    },    \"ETH\": {      \"enabled\": false    },    \"native\": {      \"enabled\": true    }  },  \"fee\": {    \"enabled\": false  },  \"features\": {    \"account_creation\": true,    \"claimable_balances\": true  }}"
        
    }
}

class InteractiveDepositResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.requestSuccess()
        }
        
        return RequestMock(host: host,
                           path: "/transactions/deposit/interactive",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    func requestSuccess() -> String {
        return "{  \"type\": \"completed\",  \"url\": \"https://api.example.com/kycflow?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI\",  \"id\": \"82fhs729f63dh0v4\"}"
        
    }
}

class InteractiveWithdrawResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.requestSuccess()
        }
        
        return RequestMock(host: host,
                           path: "/transactions/withdraw/interactive",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    func requestSuccess() -> String {
        return "{  \"type\": \"completed\",  \"url\": \"https://api.example.com/kycflow?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI\",  \"id\": \"82fhs729f63dh0v4\"}"
        
    }
}

class InteractiveSingleTxResponseMock: ResponsesMock {
    var host: String
    var pendingCount = 0
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let txId = mock.variables["id"], txId == InteractiveFlowTestUtils.existingTxId {
                mock.statusCode = 200
                return self?.requestSuccess(txId: txId)
            } else if let stellarTransactionId = mock.variables["stellar_transaction_id"],
                        stellarTransactionId == InteractiveFlowTestUtils.extistingStellarTxId {
                mock.statusCode = 200
                return self?.requestSuccess(txId: InteractiveFlowTestUtils.existingTxId)
            } else if let txId = mock.variables["id"], txId == InteractiveFlowTestUtils.pendingTxId {
                mock.statusCode = 200
                if let count = self?.pendingCount, count < 2  {
                    self?.pendingCount += 1
                    return self?.requestPendingTx()
                    
                }
                return self?.requestSuccess(txId: txId)
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/transaction",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestSuccess(txId:String) -> String {
        return "{  \"transaction\": {      \"id\": \"\(txId)\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"completed_at\": \"2017-03-20T17:09:58Z\",      \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }}"
    }
    
    func requestPendingTx() -> String {
        return "{  \"transaction\": {      \"id\": \"55fhs729f63dh0v5\",      \"kind\": \"withdrawal\",      \"status\": \"pending_external\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }}";
        
    }
}

class InteractiveMultipleTxResponseMock: ResponsesMock {
    var host: String
    var pendingCount = 0
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let assetCode =  mock.variables["asset_code"], assetCode == "USDC" {
                mock.statusCode = 200
                return self?.requestPendingTrsansactions1()
            } else if let assetCode =  mock.variables["asset_code"], assetCode == "ETH" {
                mock.statusCode = 200
                self?.pendingCount += 1
                if let count = self?.pendingCount {
                    if (count == 1) {
                        return self?.requestPendingTrsansactions1()
                    } else if (count == 2) {
                        return self?.requestPendingTrsansactions2()
                    } else if (count == 3) {
                        return self?.requestPendingTrsansactions3()
                    }
                }
                return self?.requestPendingTransactionsCompleted()
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/transactions",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestPendingTrsansactions1() -> String {
        return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"52fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}"
    }
    
    func requestPendingTrsansactions2() -> String {
        return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"52fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}"
        
    }
    
    func requestPendingTrsansactions3() -> String {
        return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"52fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}"
        
    }
    
    func requestPendingTransactionsCompleted() -> String {
        return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"52fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}"
    }
}

final class Sep24TestUtils {

    // Domain that resolves to a stellar.toml exposing SEP-24, SEP-10, KYC and quote services.
    static let fullAnchorDomain = "full.sep24test.com"
    // Domain whose stellar.toml only exposes a signing key (no services at all).
    static let emptyAnchorDomain = "empty.sep24test.com"

    static let apiHost = "api.sep24test.org"
    static let webAuthEndpoint = "https://\(apiHost)/auth"

    static let interactiveHost = "sep24.sep24test.org"
    static let quoteHost = "sep38.sep24test.org"
    static let kycHost = "sep12.sep24test.org"

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

// MARK: - Namespaced mocks

class Sep24TestInteractiveInfoMock: ResponsesMock {
    var host: String
    var malformed = false
    var useMinimalInfo = false

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            if self.malformed {
                mock.statusCode = 200
                return "{ this is not json "
            }
            mock.statusCode = 200
            return self.useMinimalInfo ? self.minimalInfo : self.fullInfo
        }
        return RequestMock(host: host,
                           path: "/info",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    // USDC enabled for deposit and withdraw, BTC present but disabled, native enabled.
    let fullInfo = """
    {
      "deposit": {
        "USDC": { "enabled": true, "fee_fixed": 5, "fee_percent": 1, "min_amount": 0.1, "max_amount": 1000 },
        "BTC": { "enabled": false },
        "native": { "enabled": true }
      },
      "withdraw": {
        "USDC": { "enabled": true, "fee_minimum": 5, "fee_percent": 0.5 },
        "BTC": { "enabled": false },
        "native": { "enabled": true }
      },
      "fee": { "enabled": false },
      "features": { "account_creation": true, "claimable_balances": false }
    }
    """

    let minimalInfo = """
    {
      "deposit": {},
      "withdraw": {}
    }
    """
}

class Sep24TestInteractiveInitMock: ResponsesMock {
    var host: String
    // deposit always returns a 400 anchor error for coverage of the failure mapping.
    var withdrawStatusCode = 200

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            if request.url?.path.contains("withdraw") ?? false {
                mock.statusCode = self.withdrawStatusCode
                if self.withdrawStatusCode == 404 {
                    return "{\"error\": \"not found\"}"
                }
                return "{ \"type\": \"completed\", \"url\": \"https://anchor.example/flow\", \"id\": \"wid\" }"
            }
            // deposit
            mock.statusCode = 400
            return "{\"error\": \"deposit temporarily disabled\"}"
        }
        return RequestMock(host: host,
                           path: "/transactions/*/interactive",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
}

class Sep24TestInteractiveTxMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            let id = mock.variables["id"] ?? ""
            switch id {
            case "bad-status":
                mock.statusCode = 200
                return self.tx(id: id, kind: "deposit", status: "totally_invalid")
            case "bad-kind":
                mock.statusCode = 200
                return self.tx(id: id, kind: "nonsense", status: "completed")
            case "exchange-kind":
                mock.statusCode = 200
                return self.tx(id: id, kind: "deposit-exchange", status: "completed")
            case "incomplete-deposit":
                mock.statusCode = 200
                return self.incompleteDeposit
            case "incomplete-withdrawal":
                mock.statusCode = 200
                return self.incompleteWithdrawal
            case "error-deposit":
                mock.statusCode = 200
                return self.errorDeposit
            case "error-withdrawal":
                mock.statusCode = 200
                return self.errorWithdrawal
            case "deposit-complete":
                mock.statusCode = 200
                return self.depositComplete
            case "deposit-norefund":
                mock.statusCode = 200
                return self.depositNoRefund
            case "malformed":
                mock.statusCode = 200
                return "{ not valid json"
            default:
                mock.statusCode = 404
                return "{\"error\": \"not found\"}"
            }
        }
        return RequestMock(host: host,
                           path: "/transaction",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    private func tx(id: String, kind: String, status: String) -> String {
        return """
        { "transaction": { "id": "\(id)", "kind": "\(kind)", "status": "\(status)", "started_at": "2017-03-20T17:00:02Z" } }
        """
    }

    let incompleteDeposit = """
    { "transaction": { "id": "incomplete-deposit", "kind": "deposit", "status": "incomplete",
      "started_at": "2017-03-20T17:00:02Z", "more_info_url": "https://anchor.example/more", "to": "GDESTINATIONACCOUNT" } }
    """

    let incompleteWithdrawal = """
    { "transaction": { "id": "incomplete-withdrawal", "kind": "withdrawal", "status": "incomplete",
      "started_at": "2017-03-20T17:00:02Z", "from": "GSOURCEACCOUNT" } }
    """

    let errorDeposit = """
    { "transaction": { "id": "error-deposit", "kind": "deposit", "status": "error",
      "started_at": "2017-03-20T17:00:02Z", "message": "something went wrong", "refunded": true,
      "amount_in": "18.34", "amount_out": "18.24", "amount_fee": "0.1",
      "to": "GDEPOSITTO", "deposit_memo": "memodeposit", "deposit_memo_type": "text",
      "claimable_balance_id": "balance-id-xyz" } }
    """

    let errorWithdrawal = """
    { "transaction": { "id": "error-withdrawal", "kind": "withdrawal", "status": "error",
      "started_at": "2017-03-20T17:00:02Z", "message": "withdraw failed",
      "withdraw_anchor_account": "GANCHORACCOUNT", "withdraw_memo": "777", "withdraw_memo_type": "id" } }
    """

    let depositComplete = """
    { "transaction": { "id": "deposit-complete", "kind": "deposit", "status": "completed",
      "started_at": "2017-03-20T17:00:02Z", "completed_at": "2017-03-20T17:09:58Z",
      "kyc_verified": true, "from": "GFROMADDR", "to": "GTOADDR",
      "deposit_memo": "dmemo", "deposit_memo_type": "text",
      "amount_in": "18.34", "amount_in_asset": "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN",
      "amount_out": "18.24", "amount_fee": "0.1",
      "refunds": { "amount_refunded": "10", "amount_fee": "5", "payments": [
        { "id": "p1", "id_type": "stellar", "amount": "6", "fee": "3" },
        { "id": "p2", "id_type": "external", "amount": "4", "fee": "2" }
      ] } } }
    """

    let depositNoRefund = """
    { "transaction": { "id": "deposit-norefund", "kind": "deposit", "status": "pending_anchor",
      "started_at": "2017-03-20T17:00:02Z", "amount_in": "18.34", "amount_out": "18.24", "amount_fee": "0.1" } }
    """
}

class Sep24TestInteractiveTxsMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.success
        }
        return RequestMock(host: host,
                           path: "/transactions",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    let success = """
    { "transactions": [
      { "id": "d1", "kind": "deposit", "status": "completed", "started_at": "2017-03-20T17:00:02Z",
        "amount_in": "10", "amount_out": "9", "amount_fee": "1" },
      { "id": "w1", "kind": "withdrawal", "status": "pending_anchor", "started_at": "2017-03-20T17:00:02Z",
        "amount_in": "10", "amount_out": "9", "amount_fee": "1", "from": "GFROM" }
    ] }
    """
}
