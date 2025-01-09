//
//  AuthTest.swift
//  
//
//  Created by Christian Rogobete on 02.12.24.
//

import XCTest
import stellarsdk
import Foundation
@testable import stellar_wallet_sdk

final class AuthTestUtils {

    static let anchorDomain = "place.anchor.com"
    static let anchorWebAuthDomain = "api.anchor.org"
    static let webAuthEndpoint = "https://\(anchorWebAuthDomain)/auth"
    static let clientDomain = "api.client.org"
    static let clientSignerUrl = "https://\(clientDomain)/auth"
    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userAccountId = "GB4L7JUU5DENUXYH3ANTLVYQL66KQLDDJTN5SF7MWEDGWSGUA375V44V"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"
    static let clientAccountId = "GBMR7A2B6O73HNRMH2LA5VZPVXIGGKFDZDXJXJXWUF5NX2RY73N4IFOA"
    static let clientSecretSeed = "SAWJ3S2JBMPI2F2K6DFAUPCROT3RA46XZXAC5EIJAD7K5C7FCUWEKVSB"
    static let wrongSecretSeed = "SAT4GUGO2N7RVVVD2TSL7TZ6T5A6PM7PJD5NUGQI5DDH67XO4KNO2QOW"
    static let jwtSuccess = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0"
    
    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)
    static let clientKeypair = try! KeyPair(secretSeed: clientSecretSeed)
    static let userKeypair = try! KeyPair(secretSeed: userSecretSeed)
    
    static let testMemoValid:UInt64 = 19989123;
    // this are used to generate errors in the mocks, that have to be handled by the sep-10 client validation
    static let testMemoInvalidSeqNr:UInt64 = 100;
    static let testMemoInvalidFirstOpSrcAcc:UInt64 = 101;
    static let testMemoInvalidSecondOpSrcAcc:UInt64 = 102;
    static let testMemoInvalidHomeDomain:UInt64 = 103;
    static let testMemoInvalidWebAuthDomain:UInt64 = 104;
    static let testMemoInvalidTimebounds:UInt64 = 105;
    static let testMemoInvalidOperationType:UInt64 = 106;
    static let testMemoInvalidSignature:UInt64 = 107;
    static let testMemoMultipleSignature:UInt64 = 108;
    
}

final class AuthTest: XCTestCase {
    let wallet = Wallet.testNet
    var anchorTomlServerMock: WebAuthTomlResponseMock!
    var clientTomlServerMock: WebAuthTomlResponseMock!
    var challengeServerMock: WebAuthChallengeResponseMock!
    var sendChallengeServerMock: WebAuthSendChallengeResponseMock!
    var clientSignerServerMock: ClientSignerResponseMock!
    
    override func setUp() {
        URLProtocol.registerClass(ServerMock.self)
        
        anchorTomlServerMock = WebAuthTomlResponseMock(address: AuthTestUtils.anchorDomain, 
                                                       serverSigningKey: AuthTestUtils.serverAccountId,
                                                       authServer: AuthTestUtils.webAuthEndpoint)
        
        clientTomlServerMock = WebAuthTomlResponseMock(address: AuthTestUtils.clientDomain,
                                                       serverSigningKey: AuthTestUtils.clientAccountId)
        
        challengeServerMock = WebAuthChallengeResponseMock(address: AuthTestUtils.anchorWebAuthDomain,
                                                           serverKeyPair: AuthTestUtils.serverKeypair)
        
        sendChallengeServerMock = WebAuthSendChallengeResponseMock(address: AuthTestUtils.anchorWebAuthDomain)
        
        clientSignerServerMock = ClientSignerResponseMock(address: AuthTestUtils.clientDomain)
    }
    
    func testAll() async throws {
        try await basicSuccessTest()
        try await clientDomainSuccessTest()
        try await basicMemoSuccessTest()
        try await getChallengeInvalidSeqNrTest()
        try await getChallengeInvalidSecondOpSrcAccTest()
        try await getChallengeInvalidHomeDomainTest()
        try await getChallengeInvalidWebAuthDomainTest()
        try await getChallengeInvalidTimeboundsTest()
        try await getChallengeInvalidOperationTypeTest()
        try await getChallengeInvalidSignatureTest()
        try await getChallengeMultipleSignaturesTest()
    }
    
    func basicSuccessTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func clientDomainSuccessTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        let clientDomainSigner = try DomainSigner(url: AuthTestUtils.clientSignerUrl)
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey,
                                                         clientDomain: AuthTestUtils.clientDomain,
                                                         clientDomainSigner: clientDomainSigner)
            
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func basicMemoSuccessTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoValid)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func getChallengeInvalidSeqNrTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidSeqNr)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .sequenceNumberNot0:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testGetChallengeInvalidFirstOpSrcAcc() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidFirstOpSrcAcc)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidSourceAccount:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidSecondOpSrcAccTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidSecondOpSrcAcc)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidSourceAccount:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidHomeDomainTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidHomeDomain)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidHomeDomain:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidWebAuthDomainTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidWebAuthDomain)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidWebAuthDomain:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidTimeboundsTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidTimebounds)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidTimeBounds:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidOperationTypeTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidOperationType)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidOperationType:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidSignatureTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidSignature)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidSignature:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeMultipleSignaturesTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoMultipleSignature)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .signatureNotFound:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
}

class WebAuthTomlResponseMock: ResponsesMock {
    var address: String
    var serverSigningKey: String
    var authServer: String?
    
    init(address:String, serverSigningKey: String, authServer: String? = nil) {
        self.address = address
        self.serverSigningKey = serverSigningKey
        self.authServer = authServer
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        
        let handler: MockHandler = { [weak self] mock, request in
            return self?.stellarToml
        }
        
        return RequestMock(host: address,
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
                SIGNING_KEY="\(serverSigningKey)"
            """ + (authServer == nil ? "" : """
                WEB_AUTH_ENDPOINT="\(authServer!)"
            """)
        }
    }
}

class WebAuthChallengeResponseMock: ResponsesMock {
    var address: String
    var serverKeyPair: KeyPair
    
    init(address:String, serverKeyPair:KeyPair) {
        self.address = address
        self.serverKeyPair = serverKeyPair
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let account = mock.variables["account"] {
                mock.statusCode = 200
                
                let memo:UInt64? = mock.variables["memo"] == nil ? nil : UInt64(mock.variables["memo"]!)
                if(memo == nil || memo == AuthTestUtils.testMemoValid) {
                    return self?.requestSuccess(account: account, memo:memo)
                } else if let memo = memo {
                    if (memo == AuthTestUtils.testMemoInvalidSeqNr) {
                        return self?.requestChallengeInvalidSequenceNumber(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidFirstOpSrcAcc) {
                        return self?.requestChallengeInvalidFirstOpSrcAcc(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidSecondOpSrcAcc) {
                        return self?.requestChallengeInvalidSecondOpSrcAcc(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidHomeDomain) {
                        return self?.requestChallengeInvalidHomeDomain(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidWebAuthDomain) {
                        return self?.requestChallengeInvalidWebAuthDomain(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidTimebounds) {
                        return self?.requestChallengeInvalidTimebounds(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidOperationType) {
                        return self?.requestChallengeInvalidOperationType(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidSignature) {
                        return self?.requestChallengeInvalidSignature(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoMultipleSignature) {
                        return self?.requestChallengeMultipleSignature(account: account, memo:memo)
                    }
                }
            }
            mock.statusCode = 400
            return """
                {"error": "Bad request"}
            """
        }
        
        return RequestMock(host: address,
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
    
    func getInvalidTimeBounds() -> TransactionPreconditions {
        return TransactionPreconditions(timeBounds: TimeBounds(minTime: UInt64(Date().timeIntervalSince1970) - 700,
                                                               maxTime: UInt64(Date().timeIntervalSince1970 - 400)))
    }
    
    func getValidFirstManageDataOp (accountId: String) -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: accountId, name: "\(AuthTestUtils.anchorDomain) auth", data: generateNonce(length: 64)?.data(using: .utf8))
    }
    
    func getInvalidHomeDomainFirstOp (accountId: String) -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: accountId, name: "fake.com auth", data: generateNonce(length: 64)?.data(using: .utf8))
    }
    
    func getValidSecondManageDataOp () -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: serverKeyPair.accountId, name: "web_auth_domain", data: address.data(using: .utf8))
    }
    
    func getSecondManageDataOpInvalidSourceAccount () -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: AuthTestUtils.userAccountId, // invalid, must be server account id
                                   name: "web_auth_domain",
                                   data: address.data(using: .utf8))
    }
    
    func getInvalidWebAuthOp () -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: serverKeyPair.accountId, name: "web_auth_domain", data: "api.fake.org".data(using: .utf8))
    }
    
    func getMemo(_ memo:UInt64? = nil) -> Memo {
        var txmemo = Memo.none
        if let memoval = memo {
            txmemo = Memo.id(memoval)
        }
        return txmemo
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
    
    func requestSuccess(account: String, memo:UInt64? = nil) -> String {
 
        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [getValidFirstManageDataOp(accountId: account),getValidSecondManageDataOp()],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidSequenceNumber(account: String, memo:UInt64? = nil) -> String {
 
        let transaction = try! Transaction(sourceAccount: Account(keyPair: serverKeyPair, sequenceNumber: 2803983),
                                           operations: [getValidFirstManageDataOp(accountId: account),getValidSecondManageDataOp()],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidFirstOpSrcAcc(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: AuthTestUtils.serverAccountId), // invalid, because must be user account
                                            getValidSecondManageDataOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidSecondOpSrcAcc(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getSecondManageDataOpInvalidSourceAccount()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidHomeDomain(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getInvalidHomeDomainFirstOp(accountId: account),
                                            getSecondManageDataOpInvalidSourceAccount()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidWebAuthDomain(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getInvalidWebAuthOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidTimebounds(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getValidSecondManageDataOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getInvalidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidOperationType(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getValidSecondManageDataOp(),
                                            PaymentOperation(sourceAccountId: AuthTestUtils.userAccountId,
                                                             destinationAccountId: serverKeyPair.accountId,
                                                             asset: NativeAssetId().toAsset(),
                                                             amount: 100)
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidSignature(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getValidSecondManageDataOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        
        try! transaction.sign(keyPair: KeyPair.generateRandomKeyPair(), network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeMultipleSignature(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getValidSecondManageDataOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        try! transaction.sign(keyPair: KeyPair.generateRandomKeyPair(), network: .testnet)
        
        return getResponseJson(transaction)
    }
}

class WebAuthSendChallengeResponseMock: ResponsesMock {
    var address: String
    
    init(address:String) {
        self.address = address
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let data = request.httpBodyStream?.readfully(), let json = try! JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String:Any] {
                if let key = json["transaction"] as? String {
                    let transactionEnvelope = try! TransactionEnvelopeXDR(xdr: key)
                    let transactionHash = try! [UInt8](transactionEnvelope.txHash(network: .testnet))
                    
                    // validate signature
                    var userSignatureFound = false
                    var clientSignatureFound = false
                    for signature in transactionEnvelope.txSignatures {
                        if !userSignatureFound {
                            userSignatureFound = try! AuthTestUtils.userKeypair.verify(signature: [UInt8](signature.signature), message: transactionHash)
                        }
                        if !clientSignatureFound {
                            clientSignatureFound = try! AuthTestUtils.clientKeypair.verify(signature: [UInt8](signature.signature), message: transactionHash)
                        }
                    }
                    var needsClientSignature = false
                    for operationXDR in transactionEnvelope.txOperations {
                        let operationBodyXDR = operationXDR.body
                        switch operationBodyXDR {
                        case .manageData(let manageDataOperation):
                            if (manageDataOperation.dataName == "client_domain") {
                                needsClientSignature = true
                            }
                            break
                        default:
                            break
                        }
                    }
                    
                    if needsClientSignature && !clientSignatureFound {
                        mock.statusCode = 404
                        return """
                            {"error": "client domain signature not found"}
                        """
                    }
                    
                    if userSignatureFound {
                        mock.statusCode = 200
                        return self?.requestSuccess()
                    }
                }
            }
            mock.statusCode = 400
            return """
                {"error": "Bad request"}
            """
        }
        
        return RequestMock(host: address,
                           path: "/auth",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    func requestSuccess() -> String {
        return """
        {
        "token": "\(AuthTestUtils.jwtSuccess)"
        }
        """
    }
}


class ClientSignerResponseMock: ResponsesMock {
    var address: String
    
    init(address:String) {
        self.address = address
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let data = request.httpBodyStream?.readfully(), let json = try! JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String:Any] {
                if let tx = json["transaction"] as? String {
                    let signedTx = try! self?.signTx(txEnvelopeXdr: tx, seed: AuthTestUtils.clientSecretSeed)
                    mock.statusCode = 200
                    return self?.requestSuccess(signedTx: signedTx!)
                }
            }
            mock.statusCode = 400
            return """
                {"error": "Bad request"}
            """
        }
        
        return RequestMock(host: address,
                           path: "/auth",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    func signTx(txEnvelopeXdr:String, seed:String) throws -> String {
        let envelopeXDR = try TransactionEnvelopeXDR(xdr: txEnvelopeXdr)
        let transactionHash = try [UInt8](envelopeXDR.txHash(network: .testnet))
        let clientDomainAccountKey = try! KeyPair(secretSeed:seed)
        let signature = clientDomainAccountKey.signDecorated(transactionHash)
        envelopeXDR.appendSignature(signature: signature)
        let encoded = try XDREncoder.encode(envelopeXDR)
        return Data(bytes: encoded, count: encoded.count).base64EncodedString()
    }
    
    func requestSuccess(signedTx:String) -> String {
        return """
        {
        "transaction": "\(signedTx)",
        "network_passphrase": "\(Network.testnet.passphrase)"
        }
        """
    }
}

final class AuthTestRemote: XCTestCase {
    
    func testStellarAnchorBasics() async throws {
        let wallet = Wallet.testNet
        let anchor = wallet.anchor(homeDomain: "testanchor.stellar.org")
        let info = try await anchor.info
        XCTAssertEqual("https://testanchor.stellar.org/auth", info.webAuthEndpoint)
        XCTAssertEqual("GCUZ6YLL5RQBTYLTTQLPCM73C5XAIUGK2TIMWQH7HPSGWVS2KJ2F3CHS", info.signingKey)
        
        let sep10 = try await anchor.sep10
        let accountKeyPair = wallet.stellar.account.createKeyPair()
        let authToken = try await sep10.authenticate(userKeyPair: accountKeyPair)
        XCTAssertEqual("https://testanchor.stellar.org/auth", authToken.issuer)
    }
}
