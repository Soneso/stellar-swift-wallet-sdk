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
    static let jwtSuccess = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0"
    
    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)
    static let userKeypair = try! KeyPair(secretSeed: userSecretSeed)
    
    static let existingTxId = "82fhs729f63dh0v4"
    
}

final class InteractiveFlowTest: XCTestCase {

    let wallet = Wallet.testNet
    var anchorTomlServerMock: InteractiveTomlResponseMock!
    var challengeServerMock: IfWebAuthChallengeResponseMock!
    var sendChallengeServerMock: IfWebAuthSendChallengeResponseMock!
    var infoServerMock: InteractiveInfoResponseMock!
    var depositServerMock: InteractiveDepositResponseMock!
    var withdrawServerMock: InteractiveWithdrawResponseMock!
    var singleTxServerMock:InteractiveSingleTxResponseMock!

    override func setUp() {
        URLProtocol.registerClass(ServerMock.self)
        
        anchorTomlServerMock = InteractiveTomlResponseMock(host: InteractiveFlowTestUtils.anchorHost,
                                                       serverSigningKey: InteractiveFlowTestUtils.serverAccountId,
                                                       authServer: InteractiveFlowTestUtils.webAuthEndpoint)
        
        challengeServerMock = IfWebAuthChallengeResponseMock(host: InteractiveFlowTestUtils.anchorWebAuthHost,
                                                           serverKeyPair: InteractiveFlowTestUtils.serverKeypair)
        
        sendChallengeServerMock = IfWebAuthSendChallengeResponseMock(host: InteractiveFlowTestUtils.anchorWebAuthHost)
        infoServerMock = InteractiveInfoResponseMock(host: InteractiveFlowTestUtils.anchorInteractiveHost)
        depositServerMock = InteractiveDepositResponseMock(host: InteractiveFlowTestUtils.anchorInteractiveHost)
        withdrawServerMock = InteractiveWithdrawResponseMock(host: InteractiveFlowTestUtils.anchorInteractiveHost)
        singleTxServerMock = InteractiveSingleTxResponseMock(host: InteractiveFlowTestUtils.anchorInteractiveHost)
    }
    
    func testAll() async throws {
        try await infoTest()
        try await depositTest()
        try await withdrawTest()
        try await getSingleTxTest()
    }
    
    func infoTest() async throws {
        let anchor = wallet.anchor(homeDomain: InteractiveFlowTestUtils.anchorHost)
        do {
            let info = try await anchor.sep24.serviceInfo
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
            
            let depositResponse = try await anchor.sep24.deposit(assetId: usdcAssetId, authToken: authToken)
            XCTAssertEqual("82fhs729f63dh0v4", depositResponse.id)
            XCTAssertEqual("completed", depositResponse.type)
            XCTAssertEqual("https://api.example.com/kycflow?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI", depositResponse.url)
            
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
    
    func getSingleTxTest() async throws {
        let anchor = wallet.anchor(homeDomain: InteractiveFlowTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: InteractiveFlowTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            let tx = try await anchor.sep24.getTransaction(transactionId:InteractiveFlowTestUtils.existingTxId , authToken: authToken)
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
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
}

class InteractiveTomlResponseMock: ResponsesMock {
    var host: String
    var serverSigningKey: String
    var authServer: String?
    
    init(host:String, serverSigningKey: String, authServer: String? = nil) {
        self.host = host
        self.serverSigningKey = serverSigningKey
        self.authServer = authServer
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        
        let handler: MockHandler = { [weak self] mock, request in
            return self?.stellarToml
        }
        
        return RequestMock(host: host,
                           path: "/.well-known/stellar.toml",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    var stellarToml:String {
        get {
            return """
                # Sample stellar.toml
                VERSION="2.0.0"
                NETWORK_PASSPHRASE="\(Network.testnet.passphrase)"
                TRANSFER_SERVER_SEP0024="https://\(InteractiveFlowTestUtils.anchorInteractiveHost)"
                SIGNING_KEY="\(serverSigningKey)"
            """ + (authServer == nil ? "" : """
                WEB_AUTH_ENDPOINT="\(authServer!)"
            """) +
            """
                [[CURRENCIES]]
                code="USDC"
                issuer="GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
                display_decimals=2

                [[CURRENCIES]]
                code="ETH"
                issuer="GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U"
                display_decimals=7
            """
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
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let txId = mock.variables["id"], txId == InteractiveFlowTestUtils.existingTxId {
                mock.statusCode = 200
                return self?.requestSuccess()
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
    
    func requestSuccess() -> String {
        return "{  \"transaction\": {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"completed_at\": \"2017-03-20T17:09:58Z\",      \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }}"
    }
}

class IfWebAuthChallengeResponseMock: ResponsesMock {
    var host: String
    var serverKeyPair: KeyPair
    
    init(host:String, serverKeyPair:KeyPair) {
        self.host = host
        self.serverKeyPair = serverKeyPair
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let account = mock.variables["account"] {
                mock.statusCode = 200
                return self?.requestSuccess(account: account)
            }
            mock.statusCode = 400
            return """
                {"error": "Bad request"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/auth",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func generateNonce(length: Int) -> String? {
        let nonce = NSMutableData(length: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, nonce!.length, nonce!.mutableBytes)
        if result == errSecSuccess {
            return (nonce! as Data).base64EncodedString()
        } else {
            return nil
        }
    }
    
    func getValidTimeBounds() -> TransactionPreconditions {
        return TransactionPreconditions(timeBounds: TimeBounds(minTime: UInt64(Date().timeIntervalSince1970),
                                                               maxTime: UInt64(Date().timeIntervalSince1970 + 300)))
    }
    
    func getValidFirstManageDataOp (accountId: String) -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: accountId, name: "\(AuthTestUtils.anchorDomain) auth", data: generateNonce(length: 64)?.data(using: .utf8))
    }
    
    func getValidSecondManageDataOp () -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: serverKeyPair.accountId, name: "web_auth_domain", data: host.data(using: .utf8))
    }
    
    func getResponseJson(_ transaction:Transaction) -> String {
        return """
                {
                "transaction": "\(try! transaction.encodedEnvelope())"
                }
                """
    }
    
    func getValidTxAccount() -> Account {
        return Account(keyPair: serverKeyPair, sequenceNumber: -1)
    }
    
    func requestSuccess(account: String) -> String {
 
        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [getValidFirstManageDataOp(accountId: account), getValidSecondManageDataOp()],
                                           memo: nil,
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
}

class IfWebAuthSendChallengeResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let data = request.httpBodyStream?.readfully(), let json = try! JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String:Any] {
                if let _ = json["transaction"] as? String {
                    mock.statusCode = 200
                    return self?.requestSuccess()
                }
            }
            mock.statusCode = 400
            return """
                {"error": "Bad request"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/auth",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    func requestSuccess() -> String {
        return """
        {
        "token": "\(InteractiveFlowTestUtils.jwtSuccess)"
        }
        """
    }
}
