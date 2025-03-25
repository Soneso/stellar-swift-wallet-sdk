//
//  RecoveryTest.swift
//  
//
//  Created by Christian Rogobete on 24.03.25.
//

import Foundation

import XCTest
import Foundation
import stellarsdk
@testable import stellar_wallet_sdk


final class RecoveryTestUtils {

    static let server1Keypair = try! KeyPair.generateRandomKeyPair()
    static let server1WebAuthDomain = "auth.example1.com"
    static let server1WebAuthEndpoint = "https://\(server1WebAuthDomain)/auth"
    static let server1HomeDomain = "recovery.example1.com"
    static let server1RecoveryEndpoint = "https://\(server1HomeDomain)"
    
    
    static let server2Keypair = try! KeyPair.generateRandomKeyPair()
    static let server2WebAuthDomain = "auth.example2.com"
    static let server2WebAuthEndpoint = "https://\(server2WebAuthDomain)/auth"
    static let server2HomeDomain = "recovery.example2.com"
    static let server2RecoveryEndpoint = "https://\(server2HomeDomain)"
    
    static let emailAuthToken = "super secure email login token"
    static let userKeypair = try! KeyPair.generateRandomKeyPair()
}

final class RecoveryTest: XCTestCase {
    
    let wallet = Wallet.testNet
    var accountKp:SigningKeyPair!
    var deviceKp:SigningKeyPair!
    var recoveryKp:SigningKeyPair!
    var sponsoredAccountKp:SigningKeyPair!
    var sponsorKp:SigningKeyPair!
    var sponsoredExistingAccountKp:SigningKeyPair!
    var newKey:SigningKeyPair!
    
    var identity1:[RecoveryAccountIdentity]!
    var identity2:[RecoveryAccountIdentity]!
    
    var first = RecoveryServerKey(name: "first")
    var second = RecoveryServerKey(name: "second")
    
    var firstServer = RecoveryServer(endpoint: RecoveryTestUtils.server1RecoveryEndpoint,
                                    authEndpoint: RecoveryTestUtils.server1WebAuthEndpoint,
                                    homeDomain: RecoveryTestUtils.server1HomeDomain)
    
    var secondServer = RecoveryServer(endpoint: RecoveryTestUtils.server2RecoveryEndpoint,
                                    authEndpoint: RecoveryTestUtils.server2WebAuthEndpoint,
                                    homeDomain: RecoveryTestUtils.server2HomeDomain)
    
    var servers:[RecoveryServerKey:RecoveryServer]!
    
    
    var server1TomlServerMock: TomlResponseMock!
    var server2TomlServerMock: TomlResponseMock!
    
    var server1ChallengeServerMock: WebAuthChallengeResponseMock!
    var server2ChallengeServerMock: WebAuthChallengeResponseMock!
    
    var server1SendChallengeServerMock: WebAuthSendChallengeResponseMock!
    var server2SendChallengeServerMock: WebAuthSendChallengeResponseMock!
    
    var server1RegistrationServerMock: RecoveryRegistrationServerMock!
    var server2RegistrationServerMock: RecoveryRegistrationServerMock!
    var server1SponsoredRegistrationServerMock: RecoveryRegistrationServerMock!
    var server2SponsoredRegistrationServerMock: RecoveryRegistrationServerMock!
    var server1SponsoredExistingRegistrationServerMock: RecoveryRegistrationServerMock!
    var server2SponsoredExistingRegistrationServerMock: RecoveryRegistrationServerMock!
    
    var server1DetailsServerMock: RecoveryDetailsServerMock!
    var server2DetailsServerMock: RecoveryDetailsServerMock!
    
    var server1RecoverMock:RecoveryRecoverServerMock!
    var server2RecoverMock:RecoveryRecoverServerMock!
    
    override func setUp() {
        URLProtocol.registerClass(ServerMock.self)
        
        accountKp = try! SigningKeyPair(keyPair: RecoveryTestUtils.userKeypair)
        deviceKp = wallet.stellar.account.createKeyPair()
        recoveryKp = wallet.stellar.account.createKeyPair()
        sponsoredAccountKp = wallet.stellar.account.createKeyPair()
        sponsorKp = wallet.stellar.account.createKeyPair()
        sponsoredExistingAccountKp = wallet.stellar.account.createKeyPair()
        newKey = wallet.stellar.account.createKeyPair()
        
        identity1 = [
            RecoveryAccountIdentity(role:RecoveryRole.owner, 
                                    authMethods: [RecoveryAccountAuthMethod(type:RecoveryType.stellarAddress,
                                                                            value:recoveryKp.address)]
                                   )
        ]
        
        identity2 = [
            RecoveryAccountIdentity(role:RecoveryRole.owner,
                                    authMethods: [RecoveryAccountAuthMethod(type:RecoveryType.email,
                                                                            value:"my-email@example.com")]
                                   )
        ]
        
        servers = [first: firstServer, second:secondServer]
        
        server1TomlServerMock = TomlResponseMock(host: RecoveryTestUtils.server1HomeDomain,
                                                 serverSigningKey: RecoveryTestUtils.server1Keypair.accountId,
                                                 authServer: RecoveryTestUtils.server1WebAuthEndpoint)
        
        server2TomlServerMock = TomlResponseMock(host: RecoveryTestUtils.server2HomeDomain,
                                                 serverSigningKey: RecoveryTestUtils.server2Keypair.accountId,
                                                 authServer: RecoveryTestUtils.server2WebAuthEndpoint)
        
        server1ChallengeServerMock = WebAuthChallengeResponseMock(host: RecoveryTestUtils.server1WebAuthDomain,
                                                                  serverKeyPair: RecoveryTestUtils.server1Keypair,
                                                                  homeDomain: RecoveryTestUtils.server1HomeDomain)
        
        server2ChallengeServerMock = WebAuthChallengeResponseMock(host: RecoveryTestUtils.server2WebAuthDomain,
                                                                  serverKeyPair: RecoveryTestUtils.server2Keypair,
                                                                  homeDomain: RecoveryTestUtils.server2HomeDomain)
        
        server1SendChallengeServerMock = WebAuthSendChallengeResponseMock(host: RecoveryTestUtils.server1WebAuthDomain)
        server2SendChallengeServerMock = WebAuthSendChallengeResponseMock(host: RecoveryTestUtils.server2WebAuthDomain)
        
        server1RegistrationServerMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: accountKp.address)
        server2RegistrationServerMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: accountKp.address)
        
        server1SponsoredRegistrationServerMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: sponsoredAccountKp.address)
        server2SponsoredRegistrationServerMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: sponsoredAccountKp.address)
        
        server1SponsoredExistingRegistrationServerMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: sponsoredExistingAccountKp.address)
        server2SponsoredExistingRegistrationServerMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: sponsoredExistingAccountKp.address)
    
        server1DetailsServerMock = RecoveryDetailsServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: accountKp.address)
        server2DetailsServerMock = RecoveryDetailsServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: accountKp.address)
        server1RecoverMock = RecoveryRecoverServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: accountKp.address, signingAddress: RecoveryTestUtils.server1Keypair.accountId)
        server2RecoverMock = RecoveryRecoverServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: accountKp.address, signingAddress: RecoveryTestUtils.server2Keypair.accountId)
        
    }
    
    func testAll() async throws {
        try await registerTest()
        try await registerWithSponsorAndNotExistingAccountTest()
        try await registerWithSponsorAndExistingAccountTest()
        try await getAccountInfoTest()
        try await recoverWalletTest()
    }
    
    func registerTest() async throws {
        try await wallet.stellar.fundTestNetAccount(address: accountKp.address)
        let recoverableWallet = try await createRecoverableWallet(accKp: accountKp)
        XCTAssertFalse(recoverableWallet.signers.isEmpty)
        let transaction = recoverableWallet.transaction
        try transaction.sign(keyPair: accountKp.keyPair, network: Network.testnet)
        let submitSuccess = try await wallet.stellar.submitTransaction(signedTransaction: transaction)
        XCTAssertTrue(submitSuccess)
        try await validateSigners(accountAddress: accountKp.address,
                                  deviceSigner: deviceKp.address,
                                  recoverySigners: recoverableWallet.signers)
        
    }
    
    func registerWithSponsorAndNotExistingAccountTest() async throws {
        try await wallet.stellar.fundTestNetAccount(address: sponsorKp.address)
        let recoverableWallet = try await createRecoverableWallet(accKp: sponsoredAccountKp, sponsor: sponsorKp)
        XCTAssertFalse(recoverableWallet.signers.isEmpty)
        let transaction = recoverableWallet.transaction
        try transaction.sign(keyPair: sponsoredAccountKp.keyPair, network: Network.testnet)
        try transaction.sign(keyPair: sponsorKp.keyPair, network: Network.testnet)
        let submitSuccess = try await wallet.stellar.submitTransaction(signedTransaction: transaction)
        XCTAssertTrue(submitSuccess)
        try await validateSigners(accountAddress: sponsoredAccountKp.address,
                                  deviceSigner: deviceKp.address,
                                  recoverySigners: recoverableWallet.signers)
        
        
    }
    
    func registerWithSponsorAndExistingAccountTest() async throws {
        try await wallet.stellar.fundTestNetAccount(address: sponsoredExistingAccountKp.address)
        let recoverableWallet = try await createRecoverableWallet(accKp: sponsoredExistingAccountKp, sponsor: sponsorKp)
        XCTAssertFalse(recoverableWallet.signers.isEmpty)
        let transaction = recoverableWallet.transaction
        try transaction.sign(keyPair: sponsoredExistingAccountKp.keyPair, network: Network.testnet)
        try transaction.sign(keyPair: sponsorKp.keyPair, network: Network.testnet)
        let submitSuccess = try await wallet.stellar.submitTransaction(signedTransaction: transaction)
        XCTAssertTrue(submitSuccess)
        try await validateSigners(accountAddress: sponsoredAccountKp.address,
                                  deviceSigner: deviceKp.address,
                                  recoverySigners: recoverableWallet.signers)
        
        
    }
    
    func getAccountInfoTest() async throws {

        let recovery = wallet.recovery(servers: servers)
        let sep10S1 = try await recovery.sep10Auth(key: first)
        let auth1Token = try await sep10S1.authenticate(userKeyPair: recoveryKp)
        let response = try await recovery.getAccountInfo(accountAddress: accountKp,
                                                         auth: [first:auth1Token.jwt, second:RecoveryTestUtils.emailAuthToken])
        
        XCTAssertFalse(response.isEmpty)
        let accountInfoS1 = response[first]
        let accountInfoS2 = response[second]
        XCTAssertEqual(accountInfoS1?.address.address, accountKp.address)
        XCTAssertEqual(accountInfoS1?.signers.first?.key.address, RecoveryTestUtils.server1Keypair.accountId)
        XCTAssertEqual(accountInfoS1?.identities.first?.role, RecoveryRole.owner)
        XCTAssertTrue(accountInfoS1?.identities.first?.authenticated ?? false)
        
        XCTAssertEqual(accountInfoS2?.address.address, accountKp.address)
        XCTAssertEqual(accountInfoS2?.signers.first?.key.address, RecoveryTestUtils.server2Keypair.accountId)
        XCTAssertEqual(accountInfoS2?.identities.first?.role, RecoveryRole.owner)
        XCTAssertTrue(accountInfoS2?.identities.first?.authenticated ?? false)
    }
    
    func recoverWalletTest() async throws {

        let recovery = wallet.recovery(servers: servers)
        
        // prepare auth
        let sep10S1 = try await recovery.sep10Auth(key: first)
        let auth1Token = try await sep10S1.authenticate(userKeyPair: recoveryKp)
        let serverAuth:[RecoveryServerKey:RecoveryServerSigning] = [
            first: RecoveryServerSigning(signerAddress: RecoveryTestUtils.server1Keypair.accountId , authToken: auth1Token.jwt),
            second: RecoveryServerSigning(signerAddress: RecoveryTestUtils.server2Keypair.accountId , authToken: RecoveryTestUtils.emailAuthToken),
        ]
        
        // recover with known lost key
        let signedReplaceKeyTx = try await recovery.replaceDeviceKey(account: accountKp,
                                                                     newKey: newKey,
                                                                     serverAuth: serverAuth,
                                                                     lostKey: deviceKp)
        XCTAssertEqual(signedReplaceKeyTx.sourceAccount.keyPair.accountId, accountKp.address)
        let submitSuccess = try await wallet.stellar.submitTransaction(signedTransaction: signedReplaceKeyTx)
        XCTAssertTrue(submitSuccess)
        try await validateSigners(accountAddress: accountKp.address,
                                  deviceSigner: newKey.address,
                                  recoverySigners: [RecoveryTestUtils.server1Keypair.accountId, RecoveryTestUtils.server2Keypair.accountId])
        
        
    }
    
    func createRecoverableWallet(accKp:AccountKeyPair, sponsor:AccountKeyPair? = nil) async throws  -> RecoverableWallet {
        let recovery = wallet.recovery(servers: servers)
        
        let config = RecoverableWalletConfig(accountAddress: accKp,
                                             deviceAddress: deviceKp,
                                             accountThreshold: AccountThreshold(low: 10, medium: 10, high: 10),
                                             accountIdentity: [first : identity1, second: identity2],
                                             signerWeight: SignerWeight(device: 10, recoveryServer: 5),
                                             sponsorAddress: sponsor)
        
        return try await recovery.createRecoverableWallet(config: config)
    }
    
    func validateSigners(accountAddress:String, deviceSigner:String, recoverySigners:[String], notSigner:String? = nil) async throws -> Void {
        let account = try await wallet.stellar.account.getInfo(accountAddress: accountAddress)
        let signers = account.signers
        var deviceSignerFound = false
        var notSignerFound = false
        var foundRecoverySigners = 0
        for signer in signers {
            if (signer.key == accountAddress) {
                XCTAssertEqual(0, signer.weight)
            }
            if (signer.key == deviceSigner) {
                XCTAssertEqual(10, signer.weight)
                deviceSignerFound = true
            }
            if let notSigner = notSigner {
                if signer.key == notSigner && signer.weight != 0 {
                    notSignerFound = true
                }
            }
            for recoverySigner in recoverySigners {
                if signer.key == recoverySigner {
                    XCTAssertEqual(5, signer.weight)
                    foundRecoverySigners += 1
                }
            }
        }
        XCTAssertTrue(deviceSignerFound)
        XCTAssertEqual(2, foundRecoverySigners)
        XCTAssertFalse(notSignerFound)
    }
}


class RecoveryRegistrationServerMock: ResponsesMock {
    var host: String
    var accountId: String
    
    init(host:String, accountId:String) {
        self.host = host
        self.accountId = accountId
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            if self?.host == RecoveryTestUtils.server1HomeDomain {
                return self?.registerSuccess(accountId:self!.accountId , signerKey: RecoveryTestUtils.server1Keypair.accountId)
            } else if self?.host == RecoveryTestUtils.server2HomeDomain {
                return self?.registerSuccess(accountId:self!.accountId, signerKey: RecoveryTestUtils.server2Keypair.accountId)
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/accounts/\(accountId)",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    func registerSuccess(accountId:String, signerKey:String) -> String {
        return "{  \"address\": \"\(accountId)\",  \"identities\": [    { \"role\": \"owner\" } ],  \"signers\": [    { \"key\": \"\(signerKey)\" }  ]}"
         
    }
}

class RecoveryDetailsServerMock: ResponsesMock {
    var host: String
    var accountId: String
    
    init(host:String, accountId:String) {
        self.host = host
        self.accountId = accountId
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            if self?.host == RecoveryTestUtils.server1HomeDomain {
                return self?.detailsSuccess(accountId:self!.accountId , signerKey: RecoveryTestUtils.server1Keypair.accountId)
            } else if self?.host == RecoveryTestUtils.server2HomeDomain {
                return self?.detailsSuccess(accountId:self!.accountId, signerKey: RecoveryTestUtils.server2Keypair.accountId)
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/accounts/\(accountId)",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func detailsSuccess(accountId:String, signerKey:String) -> String {
        return "{  \"address\": \"\(accountId)\",  \"identities\": [    { \"role\": \"owner\", \"authenticated\": true } ],  \"signers\": [    { \"key\": \"\(signerKey)\" }  ]}"
         
         
    }
}

class RecoveryRecoverServerMock: ResponsesMock {
    var host: String
    var accountId: String
    var signingAddress: String
    private let jsonDecoder = JSONDecoder()
    
    init(host:String, accountId:String, signingAddress:String) {
        self.host = host
        self.accountId = accountId
        self.signingAddress = signingAddress
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            if let data = request.httpBodyStream?.readfully() {
                let requestTx = try! self!.jsonDecoder.decode(TxMockDecodable.self, from: data)
                let tx = try! Transaction(envelopeXdr: requestTx.transaction)
                if self?.host == RecoveryTestUtils.server1HomeDomain {
                    try! tx.sign(keyPair: RecoveryTestUtils.server1Keypair, network: Network.testnet)
                    return self!.signedResponse(signature: tx.transactionXDR.signatures.last!.signature.base64EncodedString())
                } else if self?.host == RecoveryTestUtils.server2HomeDomain {
                    try! tx.sign(keyPair: RecoveryTestUtils.server2Keypair, network: Network.testnet)
                    return self!.signedResponse(signature: tx.transactionXDR.signatures.last!.signature.base64EncodedString())
                }
            }
            
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/accounts/\(accountId)/sign/\(signingAddress)",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    func signedResponse(signature:String) -> String {
        return "{  \"signature\": \"\(signature)\",  \"network_passphrase\": \"Test SDF Network ; September 2015\"}";
         
    }
}

public struct TxMockDecodable: Decodable {

    public var transaction: String
    
    /// Properties to encode and decode
    private enum CodingKeys: String, CodingKey {
        case transaction
    }
    
    /**
     Initializer - creates a new instance by decoding from the given decoder.
     
     - Parameter decoder: The decoder containing the data
     */
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        transaction = try values.decode(String.self, forKey: .transaction)
    }
}
