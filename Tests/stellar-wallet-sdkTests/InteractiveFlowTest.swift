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

    override func setUp() {
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
