//
//  RecoveryTest.swift
//
//
//  Created by Christian Rogobete on 24.03.25.
//

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

    static let horizonHost = "horizon-testnet.stellar.org"

    /// Derives the G... account id of an ed25519 signer key contained in a SetOptions operation.
    static func signerAccountId(_ key: SignerKeyXDR) -> String? {
        switch key {
        case .ed25519(let data):
            return try? PublicKey([UInt8](data.wrapped)).accountId
        default:
            return nil
        }
    }
}

final class RecoveryTest: XCTestCase {

    let wallet = Wallet.testNet

    // Per-scenario account key pairs. A distinct account per scenario keeps every
    // Horizon mock a fixed precondition rather than a stateful simulation.
    var noSponsorAccountKp:SigningKeyPair!          // exists, only master signer
    var sponsoredNewAccountKp:SigningKeyPair!       // does not exist yet (404)
    var sponsoredExistingAccountKp:SigningKeyPair!  // exists, only master signer
    var sponsorKp:SigningKeyPair!                   // funded sponsor account
    var replaceAccountKp:SigningKeyPair!            // exists with device + 2 recovery signers
    var infoAccountKp:SigningKeyPair!               // for getAccountInfo (recovery details server)

    var deviceKp:SigningKeyPair!
    var recoveryKp:SigningKeyPair!
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

    // Registration (SEP-30 enroll) mocks, one per account that gets enrolled.
    var server1RegNoSponsorMock: RecoveryRegistrationServerMock!
    var server2RegNoSponsorMock: RecoveryRegistrationServerMock!
    var server1RegSponsoredNewMock: RecoveryRegistrationServerMock!
    var server2RegSponsoredNewMock: RecoveryRegistrationServerMock!
    var server1RegSponsoredExistingMock: RecoveryRegistrationServerMock!
    var server2RegSponsoredExistingMock: RecoveryRegistrationServerMock!

    var server1DetailsServerMock: RecoveryDetailsServerMock!
    var server2DetailsServerMock: RecoveryDetailsServerMock!

    var server1RecoverMock:RecoveryRecoverServerMock!
    var server2RecoverMock:RecoveryRecoverServerMock!

    // Horizon account mocks.
    var horizonNoSponsorMock: RecoveryHorizonAccountMock!
    var horizonSponsoredExistingMock: RecoveryHorizonAccountMock!
    var horizonSponsorMock: RecoveryHorizonAccountMock!
    var horizonReplaceMock: RecoveryHorizonAccountMock!
    var horizonNotFoundMock: RecoveryHorizonNotFoundMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        deviceKp = wallet.stellar.account.createKeyPair()
        recoveryKp = wallet.stellar.account.createKeyPair()
        newKey = wallet.stellar.account.createKeyPair()

        noSponsorAccountKp = wallet.stellar.account.createKeyPair()
        sponsoredNewAccountKp = wallet.stellar.account.createKeyPair()
        sponsoredExistingAccountKp = wallet.stellar.account.createKeyPair()
        sponsorKp = wallet.stellar.account.createKeyPair()
        replaceAccountKp = wallet.stellar.account.createKeyPair()
        infoAccountKp = try! SigningKeyPair(keyPair: RecoveryTestUtils.userKeypair)

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

        server1RegNoSponsorMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: noSponsorAccountKp.address)
        server2RegNoSponsorMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: noSponsorAccountKp.address)

        server1RegSponsoredNewMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: sponsoredNewAccountKp.address)
        server2RegSponsoredNewMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: sponsoredNewAccountKp.address)

        server1RegSponsoredExistingMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: sponsoredExistingAccountKp.address)
        server2RegSponsoredExistingMock = RecoveryRegistrationServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: sponsoredExistingAccountKp.address)

        server1DetailsServerMock = RecoveryDetailsServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: infoAccountKp.address)
        server2DetailsServerMock = RecoveryDetailsServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: infoAccountKp.address)

        server1RecoverMock = RecoveryRecoverServerMock(host: RecoveryTestUtils.server1HomeDomain, accountId: replaceAccountKp.address, signingAddress: RecoveryTestUtils.server1Keypair.accountId)
        server2RecoverMock = RecoveryRecoverServerMock(host: RecoveryTestUtils.server2HomeDomain, accountId: replaceAccountKp.address, signingAddress: RecoveryTestUtils.server2Keypair.accountId)

        // Horizon account states (fixed preconditions per scenario).
        horizonNoSponsorMock = RecoveryHorizonAccountMock(accountId: noSponsorAccountKp.address,
                                                          signers: [RecoveryHorizonSigner(key: noSponsorAccountKp.address, weight: 1)])
        // sponsoredNewAccountKp intentionally NOT registered -> wildcard 404 mock returns notFound.
        horizonSponsoredExistingMock = RecoveryHorizonAccountMock(accountId: sponsoredExistingAccountKp.address,
                                                                  signers: [RecoveryHorizonSigner(key: sponsoredExistingAccountKp.address, weight: 1)])
        horizonSponsorMock = RecoveryHorizonAccountMock(accountId: sponsorKp.address,
                                                        signers: [RecoveryHorizonSigner(key: sponsorKp.address, weight: 1)])
        horizonReplaceMock = RecoveryHorizonAccountMock(accountId: replaceAccountKp.address,
                                                        signers: [
                                                            RecoveryHorizonSigner(key: replaceAccountKp.address, weight: 0),
                                                            RecoveryHorizonSigner(key: deviceKp.address, weight: 10),
                                                            RecoveryHorizonSigner(key: RecoveryTestUtils.server1Keypair.accountId, weight: 5),
                                                            RecoveryHorizonSigner(key: RecoveryTestUtils.server2Keypair.accountId, weight: 5),
                                                        ])

        // Wildcard 404 fallback MUST be registered last so the specific /accounts/{id}
        // mocks above take precedence (ServerMock returns the first matching mock).
        horizonNotFoundMock = RecoveryHorizonNotFoundMock()
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: createRecoverableWallet

    func testCreateRecoverableWalletNoSponsor() async throws {
        let recoverableWallet = try await createRecoverableWallet(accKp: noSponsorAccountKp)

        // signers must be exactly the two recovery server signing keys.
        XCTAssertEqual(2, recoverableWallet.signers.count)
        XCTAssertTrue(recoverableWallet.signers.contains(RecoveryTestUtils.server1Keypair.accountId))
        XCTAssertTrue(recoverableWallet.signers.contains(RecoveryTestUtils.server2Keypair.accountId))

        let tx = recoverableWallet.transaction
        // source account is the account itself (no sponsor).
        XCTAssertEqual(noSponsorAccountKp.address, tx.sourceAccount.keyPair.accountId)

        let ops = tx.operations
        // master(0) + 2 recovery signers + device signer + thresholds = 5 ops.
        XCTAssertEqual(5, ops.count)
        try assertRegisterOperations(ops: ops,
                                     accountId: noSponsorAccountKp.address,
                                     deviceAddress: deviceKp.address,
                                     recoverySigners: recoverableWallet.signers,
                                     startIndex: 0,
                                     opSourceShouldBeAccount: true)
    }

    func testCreateRecoverableWalletSponsoredNotExisting() async throws {
        let recoverableWallet = try await createRecoverableWallet(accKp: sponsoredNewAccountKp, sponsor: sponsorKp)

        XCTAssertEqual(2, recoverableWallet.signers.count)
        XCTAssertTrue(recoverableWallet.signers.contains(RecoveryTestUtils.server1Keypair.accountId))
        XCTAssertTrue(recoverableWallet.signers.contains(RecoveryTestUtils.server2Keypair.accountId))

        let tx = recoverableWallet.transaction
        // source account is the sponsor (account does not exist yet).
        XCTAssertEqual(sponsorKp.address, tx.sourceAccount.keyPair.accountId)

        let ops = tx.operations
        // BeginSponsoring + CreateAccount + register(5) + EndSponsoring = 8 ops.
        XCTAssertEqual(8, ops.count)

        guard let beginOp = ops[0] as? BeginSponsoringFutureReservesOperation else {
            return XCTFail("expected BeginSponsoringFutureReservesOperation at index 0")
        }
        XCTAssertEqual(sponsoredNewAccountKp.address, beginOp.sponsoredId)

        guard let createOp = ops[1] as? CreateAccountOperation else {
            return XCTFail("expected CreateAccountOperation at index 1")
        }
        XCTAssertEqual(sponsoredNewAccountKp.address, createOp.destination.accountId)
        XCTAssertEqual(Decimal(0), createOp.startBalance)

        try assertRegisterOperations(ops: ops,
                                     accountId: sponsoredNewAccountKp.address,
                                     deviceAddress: deviceKp.address,
                                     recoverySigners: recoverableWallet.signers,
                                     startIndex: 2,
                                     opSourceShouldBeAccount: true)

        XCTAssertTrue(ops[7] is EndSponsoringFutureReservesOperation)
        let endOp = ops[7] as! EndSponsoringFutureReservesOperation
        XCTAssertEqual(sponsoredNewAccountKp.address, endOp.sourceAccountId)
    }

    func testCreateRecoverableWalletSponsoredExisting() async throws {
        let recoverableWallet = try await createRecoverableWallet(accKp: sponsoredExistingAccountKp, sponsor: sponsorKp)

        XCTAssertEqual(2, recoverableWallet.signers.count)

        let tx = recoverableWallet.transaction
        // source account is the existing account.
        XCTAssertEqual(sponsoredExistingAccountKp.address, tx.sourceAccount.keyPair.accountId)

        let ops = tx.operations
        // BeginSponsoring + register(5) + EndSponsoring = 7 ops (no CreateAccount, account exists).
        XCTAssertEqual(7, ops.count)

        guard let beginOp = ops[0] as? BeginSponsoringFutureReservesOperation else {
            return XCTFail("expected BeginSponsoringFutureReservesOperation at index 0")
        }
        XCTAssertEqual(sponsoredExistingAccountKp.address, beginOp.sponsoredId)
        XCTAssertFalse(ops[1] is CreateAccountOperation)

        try assertRegisterOperations(ops: ops,
                                     accountId: sponsoredExistingAccountKp.address,
                                     deviceAddress: deviceKp.address,
                                     recoverySigners: recoverableWallet.signers,
                                     startIndex: 1,
                                     opSourceShouldBeAccount: true)

        XCTAssertTrue(ops[6] is EndSponsoringFutureReservesOperation)
    }

    func testCreateRecoverableWalletSameDeviceAndAccountKeyFails() async throws {
        let recovery = wallet.recovery(servers: servers)
        let config = RecoverableWalletConfig(accountAddress: noSponsorAccountKp,
                                             deviceAddress: noSponsorAccountKp, // same as account
                                             accountThreshold: AccountThreshold(low: 10, medium: 10, high: 10),
                                             accountIdentity: [first : identity1, second: identity2],
                                             signerWeight: SignerWeight(device: 10, recoveryServer: 5))
        do {
            _ = try await recovery.createRecoverableWallet(config: config)
            XCTFail("expected ValidationError.invalidArgument")
        } catch ValidationError.invalidArgument(_) {
            // expected
        }
    }

    func testCreateRecoverableWalletAccountNotExistingAndNotSponsoredFails() async throws {
        // sponsoredNewAccountKp has no Horizon mock (returns 404) and no sponsor is given.
        let recovery = wallet.recovery(servers: servers)
        let config = RecoverableWalletConfig(accountAddress: sponsoredNewAccountKp,
                                             deviceAddress: deviceKp,
                                             accountThreshold: AccountThreshold(low: 10, medium: 10, high: 10),
                                             accountIdentity: [first : identity1, second: identity2],
                                             signerWeight: SignerWeight(device: 10, recoveryServer: 5))
        do {
            _ = try await recovery.createRecoverableWallet(config: config)
            XCTFail("expected ValidationError.invalidArgument (account does not exist and is not sponsored)")
        } catch ValidationError.invalidArgument(_) {
            // expected
        }
    }

    func testCreateRecoverableWalletSponsorNotExistingFails() async throws {
        // account exists, but sponsor (sponsoredNewAccountKp used as sponsor) does not.
        let recovery = wallet.recovery(servers: servers)
        let config = RecoverableWalletConfig(accountAddress: noSponsorAccountKp,
                                             deviceAddress: deviceKp,
                                             accountThreshold: AccountThreshold(low: 10, medium: 10, high: 10),
                                             accountIdentity: [first : identity1, second: identity2],
                                             signerWeight: SignerWeight(device: 10, recoveryServer: 5),
                                             sponsorAddress: sponsoredNewAccountKp) // no Horizon mock -> 404
        do {
            _ = try await recovery.createRecoverableWallet(config: config)
            XCTFail("expected ValidationError.invalidArgument (sponsor account does not exist)")
        } catch ValidationError.invalidArgument(_) {
            // expected
        }
    }

    func testCreateRecoverableWalletMissingIdentityFails() async throws {
        let recovery = wallet.recovery(servers: servers)
        let config = RecoverableWalletConfig(accountAddress: noSponsorAccountKp,
                                             deviceAddress: deviceKp,
                                             accountThreshold: AccountThreshold(low: 10, medium: 10, high: 10),
                                             accountIdentity: [first : identity1], // second server identity missing
                                             signerWeight: SignerWeight(device: 10, recoveryServer: 5))
        do {
            _ = try await recovery.createRecoverableWallet(config: config)
            XCTFail("expected ValidationError.invalidArgument (missing account identity)")
        } catch ValidationError.invalidArgument(_) {
            // expected
        }
    }

    // MARK: getAccountInfo

    func testGetAccountInfo() async throws {

        let recovery = wallet.recovery(servers: servers)
        let sep10S1 = try await recovery.sep10Auth(key: first)
        let auth1Token = try await sep10S1.authenticate(userKeyPair: recoveryKp)
        let response = try await recovery.getAccountInfo(accountAddress: infoAccountKp,
                                                         auth: [first:auth1Token.jwt, second:RecoveryTestUtils.emailAuthToken])

        XCTAssertFalse(response.isEmpty)
        let accountInfoS1 = response[first]
        let accountInfoS2 = response[second]
        XCTAssertEqual(accountInfoS1?.address.address, infoAccountKp.address)
        XCTAssertEqual(accountInfoS1?.signers.first?.key.address, RecoveryTestUtils.server1Keypair.accountId)
        XCTAssertEqual(accountInfoS1?.identities.first?.role, RecoveryRole.owner)
        XCTAssertTrue(accountInfoS1?.identities.first?.authenticated ?? false)

        XCTAssertEqual(accountInfoS2?.address.address, infoAccountKp.address)
        XCTAssertEqual(accountInfoS2?.signers.first?.key.address, RecoveryTestUtils.server2Keypair.accountId)
        XCTAssertEqual(accountInfoS2?.identities.first?.role, RecoveryRole.owner)
        XCTAssertTrue(accountInfoS2?.identities.first?.authenticated ?? false)
    }

    func testGetAccountInfoUnknownServerKeyFails() async throws {
        let recovery = wallet.recovery(servers: servers)
        let unknown = RecoveryServerKey(name: "unknown")
        do {
            _ = try await recovery.getAccountInfo(accountAddress: infoAccountKp,
                                                  auth: [unknown: RecoveryTestUtils.emailAuthToken])
            XCTFail("expected ValidationError.invalidArgument (key not in servers map)")
        } catch ValidationError.invalidArgument(_) {
            // expected
        }
    }

    // MARK: replaceDeviceKey / recovery

    func testReplaceDeviceKeyWithKnownLostKey() async throws {

        let serverAuth = try await prepareServerAuth()
        let recovery = wallet.recovery(servers: servers)

        let signedReplaceKeyTx = try await recovery.replaceDeviceKey(account: replaceAccountKp,
                                                                     newKey: newKey,
                                                                     serverAuth: serverAuth,
                                                                     lostKey: deviceKp)

        // Source account is the recovered account.
        XCTAssertEqual(replaceAccountKp.address, signedReplaceKeyTx.sourceAccount.keyPair.accountId)

        let ops = signedReplaceKeyTx.operations
        // remove lost signer + add new signer = 2 ops (no sponsor).
        XCTAssertEqual(2, ops.count)

        guard let removeOp = ops[0] as? SetOptionsOperation, let removeSigner = removeOp.signer else {
            return XCTFail("expected SetOptionsOperation (remove) at index 0")
        }
        XCTAssertEqual(replaceAccountKp.address, removeOp.sourceAccountId)
        XCTAssertEqual(deviceKp.address, RecoveryTestUtils.signerAccountId(removeSigner))
        XCTAssertEqual(0, removeOp.signerWeight) // lost key removed

        guard let addOp = ops[1] as? SetOptionsOperation, let addSigner = addOp.signer else {
            return XCTFail("expected SetOptionsOperation (add) at index 1")
        }
        XCTAssertEqual(replaceAccountKp.address, addOp.sourceAccountId)
        XCTAssertEqual(newKey.address, RecoveryTestUtils.signerAccountId(addSigner))
        // new key inherits the lost key's weight (device weight was 10 in the mocked account).
        XCTAssertEqual(10, addOp.signerWeight)

        // Transaction carries the two recovery-server signatures.
        XCTAssertEqual(2, signedReplaceKeyTx.transactionXDR.signatures.count)
    }

    func testReplaceDeviceKeyDeducedLostKey() async throws {
        // No lostKey provided: deduceKey must pick the single non-recovery signer (device key).
        let serverAuth = try await prepareServerAuth()
        let recovery = wallet.recovery(servers: servers)

        let signedReplaceKeyTx = try await recovery.replaceDeviceKey(account: replaceAccountKp,
                                                                     newKey: newKey,
                                                                     serverAuth: serverAuth)

        XCTAssertEqual(replaceAccountKp.address, signedReplaceKeyTx.sourceAccount.keyPair.accountId)
        let ops = signedReplaceKeyTx.operations
        XCTAssertEqual(2, ops.count)

        guard let removeOp = ops[0] as? SetOptionsOperation, let removeSigner = removeOp.signer else {
            return XCTFail("expected SetOptionsOperation (remove) at index 0")
        }
        // deduced lost key is the device key.
        XCTAssertEqual(deviceKp.address, RecoveryTestUtils.signerAccountId(removeSigner))
        XCTAssertEqual(0, removeOp.signerWeight)

        guard let addOp = ops[1] as? SetOptionsOperation, let addSigner = addOp.signer else {
            return XCTFail("expected SetOptionsOperation (add) at index 1")
        }
        XCTAssertEqual(newKey.address, RecoveryTestUtils.signerAccountId(addSigner))
        XCTAssertEqual(10, addOp.signerWeight)
    }

    func testReplaceDeviceKeyLostKeyNotBelongingFails() async throws {
        let serverAuth = try await prepareServerAuth()
        let recovery = wallet.recovery(servers: servers)

        // newKey is not a signer on the replace account.
        let strangerKey = wallet.stellar.account.createKeyPair()
        do {
            _ = try await recovery.replaceDeviceKey(account: replaceAccountKp,
                                                    newKey: newKey,
                                                    serverAuth: serverAuth,
                                                    lostKey: strangerKey)
            XCTFail("expected ValidationError.invalidArgument (lost key doesn't belong to the account)")
        } catch ValidationError.invalidArgument(_) {
            // expected
        }
    }

    func testReplaceDeviceKeyAccountNotExistingFails() async throws {
        let serverAuth = try await prepareServerAuth()
        let recovery = wallet.recovery(servers: servers)

        // sponsoredNewAccountKp has no Horizon mock -> 404.
        do {
            _ = try await recovery.replaceDeviceKey(account: sponsoredNewAccountKp,
                                                    newKey: newKey,
                                                    serverAuth: serverAuth,
                                                    lostKey: deviceKp)
            XCTFail("expected ValidationError.invalidArgument (account doesn't exist)")
        } catch ValidationError.invalidArgument(_) {
            // expected
        }
    }

    // MARK: helpers

    private func prepareServerAuth() async throws -> [RecoveryServerKey:RecoveryServerSigning] {
        let recovery = wallet.recovery(servers: servers)
        let sep10S1 = try await recovery.sep10Auth(key: first)
        let auth1Token = try await sep10S1.authenticate(userKeyPair: recoveryKp)
        return [
            first: RecoveryServerSigning(signerAddress: RecoveryTestUtils.server1Keypair.accountId, authToken: auth1Token.jwt),
            second: RecoveryServerSigning(signerAddress: RecoveryTestUtils.server2Keypair.accountId, authToken: RecoveryTestUtils.emailAuthToken),
        ]
    }

    private func createRecoverableWallet(accKp:AccountKeyPair, sponsor:AccountKeyPair? = nil) async throws -> RecoverableWallet {
        let recovery = wallet.recovery(servers: servers)

        let config = RecoverableWalletConfig(accountAddress: accKp,
                                             deviceAddress: deviceKp,
                                             accountThreshold: AccountThreshold(low: 10, medium: 10, high: 10),
                                             accountIdentity: [first : identity1, second: identity2],
                                             signerWeight: SignerWeight(device: 10, recoveryServer: 5),
                                             sponsorAddress: sponsor)

        return try await recovery.createRecoverableWallet(config: config)
    }

    /// Asserts the SetOptions sequence produced by Recovery.register():
    /// master key weight 0, one SetOptions per signer with the correct weight
    /// (recovery=5, device=10), then the threshold SetOptions (10/10/10).
    private func assertRegisterOperations(ops:[stellarsdk.Operation],
                                          accountId:String,
                                          deviceAddress:String,
                                          recoverySigners:[String],
                                          startIndex:Int,
                                          opSourceShouldBeAccount:Bool) throws {
        // 1) master key weight 0
        guard let masterOp = ops[startIndex] as? SetOptionsOperation else {
            return XCTFail("expected SetOptionsOperation (master) at index \(startIndex)")
        }
        XCTAssertEqual(0, masterOp.masterKeyWeight)
        XCTAssertNil(masterOp.signer)
        if opSourceShouldBeAccount {
            XCTAssertEqual(accountId, masterOp.sourceAccountId)
        }

        // 2..4) three signer SetOptions (2 recovery @5, 1 device @10), order preserved.
        var foundDeviceSigner = false
        var foundRecoverySigners = 0
        for i in 0..<3 {
            guard let signerOp = ops[startIndex + 1 + i] as? SetOptionsOperation,
                  let signer = signerOp.signer else {
                return XCTFail("expected SetOptionsOperation (signer) at index \(startIndex + 1 + i)")
            }
            if opSourceShouldBeAccount {
                XCTAssertEqual(accountId, signerOp.sourceAccountId)
            }
            let signerAddr = RecoveryTestUtils.signerAccountId(signer)
            if signerAddr == deviceAddress {
                XCTAssertEqual(10, signerOp.signerWeight)
                foundDeviceSigner = true
            } else if let signerAddr = signerAddr, recoverySigners.contains(signerAddr) {
                XCTAssertEqual(5, signerOp.signerWeight)
                foundRecoverySigners += 1
            } else {
                XCTFail("unexpected signer \(signerAddr ?? "nil")")
            }
        }
        XCTAssertTrue(foundDeviceSigner)
        XCTAssertEqual(2, foundRecoverySigners)

        // 5) thresholds
        guard let thresholdOp = ops[startIndex + 4] as? SetOptionsOperation else {
            return XCTFail("expected SetOptionsOperation (thresholds) at index \(startIndex + 4)")
        }
        XCTAssertEqual(10, thresholdOp.lowThreshold)
        XCTAssertEqual(10, thresholdOp.mediumThreshold)
        XCTAssertEqual(10, thresholdOp.highThreshold)
        XCTAssertNil(thresholdOp.signer)
        if opSourceShouldBeAccount {
            XCTAssertEqual(accountId, thresholdOp.sourceAccountId)
        }
    }

    // MARK: - Recovery model types

    func testRecoveryServerKeyEqualityAndHash() {
        let a = RecoveryServerKey(name: "server1")
        let b = RecoveryServerKey(name: "server1")
        let c = RecoveryServerKey(name: "server2")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(a.hashValue, b.hashValue)

        var dict: [RecoveryServerKey: Int] = [:]
        dict[a] = 1
        dict[b] = 2 // overwrites because a == b
        dict[c] = 3
        XCTAssertEqual(2, dict.count)
        XCTAssertEqual(2, dict[a])
    }

    func testRecoveryServerProperties() throws {
        let signer = try DomainSigner(url: RecoveryModelTestFixtures.signerUrl)
        let server = RecoveryServer(endpoint: "https://recovery.example.com",
                                    authEndpoint: "https://auth.example.com",
                                    homeDomain: "recovery.example.com",
                                    walletSigner: signer,
                                    clientDomain: "client.example.com")
        XCTAssertEqual("https://recovery.example.com", server.endpoint)
        XCTAssertEqual("https://auth.example.com", server.authEndpoint)
        XCTAssertEqual("recovery.example.com", server.homeDomain)
        XCTAssertTrue(server.walletSigner is DomainSigner)
        XCTAssertEqual("client.example.com", server.clientDomain)
    }

    func testRecoveryServerOptionalDefaults() {
        let server = RecoveryServer(endpoint: "https://recovery.example.com",
                                    authEndpoint: "https://auth.example.com",
                                    homeDomain: "recovery.example.com")
        XCTAssertNil(server.walletSigner)
        XCTAssertNil(server.clientDomain)
    }

    func testRecoveryServerSigning() {
        let signing = RecoveryServerSigning(signerAddress: RecoveryModelTestFixtures.serverAccountId,
                                            authToken: "jwt-token")
        XCTAssertEqual(RecoveryModelTestFixtures.serverAccountId, signing.signerAddress)
        XCTAssertEqual("jwt-token", signing.authToken)
    }

    func testSignerWeight() {
        let w = SignerWeight(device: 10, recoveryServer: 5)
        XCTAssertEqual(10, w.device)
        XCTAssertEqual(5, w.recoveryServer)
    }

    func testAccountThreshold() {
        let t = AccountThreshold(low: 1, medium: 2, high: 3)
        XCTAssertEqual(1, t.low)
        XCTAssertEqual(2, t.medium)
        XCTAssertEqual(3, t.high)
    }

    func testRecoveryRoleRawValues() {
        XCTAssertEqual("owner", RecoveryRole.owner.rawValue)
        XCTAssertEqual("sender", RecoveryRole.sender.rawValue)
        XCTAssertEqual("receiver", RecoveryRole.receiver.rawValue)
        XCTAssertEqual(.owner, RecoveryRole(rawValue: "owner"))
        XCTAssertNil(RecoveryRole(rawValue: "admin"))
    }

    func testRecoveryTypeRawValues() {
        XCTAssertEqual("stellar_address", RecoveryType.stellarAddress.rawValue)
        XCTAssertEqual("phone_number", RecoveryType.phoneNumber.rawValue)
        XCTAssertEqual("email", RecoveryType.email.rawValue)
        XCTAssertEqual(.email, RecoveryType(rawValue: "email"))
        XCTAssertNil(RecoveryType(rawValue: "carrier_pigeon"))
    }

    func testRecoveryAccountAuthMethodToSep30() {
        let method = RecoveryAccountAuthMethod(type: .email, value: "user@example.com")
        XCTAssertEqual(.email, method.type)
        XCTAssertEqual("user@example.com", method.value)

        let sep30 = method.toSEP30AuthMethod()
        XCTAssertEqual("email", sep30.type)
        XCTAssertEqual("user@example.com", sep30.value)
    }

    func testRecoveryAccountIdentityToSep30() {
        let m1 = RecoveryAccountAuthMethod(type: .email, value: "user@example.com")
        let m2 = RecoveryAccountAuthMethod(type: .phoneNumber, value: "+1555")
        let identity = RecoveryAccountIdentity(role: .owner, authMethods: [m1, m2])
        XCTAssertEqual(.owner, identity.role)
        XCTAssertEqual(2, identity.authMethods.count)

        let sep30 = identity.toSEP30RequestIdentity()
        XCTAssertEqual("owner", sep30.role)
        XCTAssertEqual(2, sep30.authMethods.count)
        XCTAssertEqual("email", sep30.authMethods[0].type)
        XCTAssertEqual("phone_number", sep30.authMethods[1].type)
    }

    func testAccountSigner() {
        let kp = SigningKeyPair.random
        let signer = AccountSigner(address: kp, weight: 7)
        XCTAssertEqual(kp.address, signer.address.address)
        XCTAssertEqual(7, signer.weight)
    }

    func testRecoverableWalletConfig() throws {
        let accountKp = SigningKeyPair.random
        let deviceKp = SigningKeyPair.random
        let threshold = AccountThreshold(low: 10, medium: 10, high: 10)
        let serverKey = RecoveryServerKey(name: "server1")
        let identity = RecoveryAccountIdentity(role: .owner,
                                               authMethods: [RecoveryAccountAuthMethod(type: .email, value: "a@b.c")])
        let weight = SignerWeight(device: 10, recoveryServer: 5)

        let config = RecoverableWalletConfig(accountAddress: accountKp,
                                             deviceAddress: deviceKp,
                                             accountThreshold: threshold,
                                             accountIdentity: [serverKey: [identity]],
                                             signerWeight: weight)
        XCTAssertEqual(accountKp.address, config.accountAddress.address)
        XCTAssertEqual(deviceKp.address, config.deviceAddress.address)
        XCTAssertEqual(10, config.accountThreshold.high)
        XCTAssertEqual(1, config.accountIdentity.count)
        XCTAssertEqual(10, config.signerWeight.device)
        XCTAssertNil(config.sponsorAddress)

        let sponsorKp = SigningKeyPair.random
        let sponsored = RecoverableWalletConfig(accountAddress: accountKp,
                                                deviceAddress: deviceKp,
                                                accountThreshold: threshold,
                                                accountIdentity: [serverKey: [identity]],
                                                signerWeight: weight,
                                                sponsorAddress: sponsorKp)
        XCTAssertNotNil(sponsored.sponsorAddress)
        XCTAssertEqual(sponsorKp.address, sponsored.sponsorAddress?.address)
    }

    func testRecoverableWalletHoldsTransactionAndSigners() throws {
        let sourceKp = SigningKeyPair.random
        let account = Account(keyPair: sourceKp.keyPair, sequenceNumber: 1)
        let op = try PaymentOperation(sourceAccountId: sourceKp.address,
                                      destinationAccountId: RecoveryModelTestFixtures.issuer,
                                      asset: Asset(type: AssetType.ASSET_TYPE_NATIVE)!,
                                      amount: 1)
        let tx = try Transaction(sourceAccount: account, operations: [op], memo: Memo.none)
        let recoverable = RecoverableWallet(transaction: tx, signers: ["signer1", "signer2"])
        XCTAssertTrue(recoverable.transaction === tx)
        XCTAssertEqual(["signer1", "signer2"], recoverable.signers)
    }

    func testRecoverableIdentityFromResponseValid() throws {
        let response = try RecoveryModelTestFixtures.decodeSep30Identity(json: """
            {"role": "owner", "authenticated": true}
            """)
        let identity = try RecoverableIdentity(response: response)
        XCTAssertEqual(.owner, identity.role)
        XCTAssertEqual(true, identity.authenticated)
    }

    func testRecoverableIdentityFromResponseMissingRoleThrows() throws {
        let response = try RecoveryModelTestFixtures.decodeSep30Identity(json: "{}")
        XCTAssertThrowsError(try RecoverableIdentity(response: response)) { error in
            guard case RecoveryServiceError.parsingResponseFailed = error else {
                return XCTFail("expected parsingResponseFailed, got \(error)")
            }
        }
    }

    func testRecoverableIdentityFromResponseUnknownRoleThrows() throws {
        let response = try RecoveryModelTestFixtures.decodeSep30Identity(json: """
            {"role": "wizard"}
            """)
        XCTAssertThrowsError(try RecoverableIdentity(response: response)) { error in
            guard case RecoveryServiceError.parsingResponseFailed = error else {
                return XCTFail("expected parsingResponseFailed, got \(error)")
            }
        }
    }

    func testRecoverableSignerFromResponseValid() throws {
        let response = try RecoveryModelTestFixtures.decodeSep30Signer(json: """
            {"key": "\(RecoveryModelTestFixtures.issuer)"}
            """)
        let signer = try RecoverableSigner(response: response)
        XCTAssertEqual(RecoveryModelTestFixtures.issuer, signer.key.address)
        XCTAssertNil(signer.added)
    }

    func testRecoverableSignerFromResponseInvalidKeyThrows() throws {
        let response = try RecoveryModelTestFixtures.decodeSep30Signer(json: """
            {"key": "NOT_A_KEY"}
            """)
        XCTAssertThrowsError(try RecoverableSigner(response: response)) { error in
            guard case RecoveryServiceError.parsingResponseFailed = error else {
                return XCTFail("expected parsingResponseFailed, got \(error)")
            }
        }
    }

    func testRecoverableAccountInfoFromResponse() throws {
        let response = try RecoveryModelTestFixtures.decodeSep30Account(json: """
            {
              "address": "\(RecoveryModelTestFixtures.otherIssuer)",
              "identities": [{"role": "owner", "authenticated": true}],
              "signers": [{"key": "\(RecoveryModelTestFixtures.issuer)"}]
            }
            """)
        let info = try RecoverableAccountInfo(response: response)
        XCTAssertEqual(RecoveryModelTestFixtures.otherIssuer, info.address.address)
        XCTAssertEqual(1, info.identities.count)
        XCTAssertEqual(.owner, info.identities[0].role)
        XCTAssertEqual(1, info.signers.count)
        XCTAssertEqual(RecoveryModelTestFixtures.issuer, info.signers[0].key.address)
    }

    // MARK: - AccountRecover.deduceKey throwing branches via replaceDeviceKey

    func testReplaceDeviceKeyNoDeviceKeyThrows() async throws {
        // Account whose only weighted signer is a recovery signer -> no non-recovery
        // signer remains, so deduceKey throws "No device key is setup for this account".
        let accountKp = try SigningKeyPair(secretKey: RecoverDeduceUtils.userSecretSeed)
        let recoverySignerKp = SigningKeyPair.random
        let newKey = SigningKeyPair.random

        let horizonMock = RecoverDeduceHorizonAccountMock(
            accountId: accountKp.address,
            signers: [
                (key: accountKp.address, weight: 0),                 // master, weight 0 -> ignored
                (key: recoverySignerKp.address, weight: 5),          // recovery signer
            ])

        let serverKey = RecoveryServerKey(name: "deduce-server")
        let server = RecoveryServer(endpoint: "https://recovery.deduce.example",
                                    authEndpoint: "https://auth.deduce.example/auth",
                                    homeDomain: "recovery.deduce.example")
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

    func testReplaceDeviceKeyAmbiguousDeviceKeyThrows() async throws {
        // Two non-recovery signers whose weights both differ from the single recovery
        // weight -> deduceKey cannot pick one and throws "Couldn't deduce lost key".
        let accountKp = try SigningKeyPair(secretKey: RecoverDeduceUtils.userSecretSeed)
        let recoverySignerKp = SigningKeyPair.random
        let device1Kp = SigningKeyPair.random
        let device2Kp = SigningKeyPair.random
        let newKey = SigningKeyPair.random

        let horizonMock = RecoverDeduceHorizonAccountMock(
            accountId: accountKp.address,
            signers: [
                (key: accountKp.address, weight: 0),         // master, ignored
                (key: recoverySignerKp.address, weight: 5),  // single recovery signer (weight 5)
                (key: device1Kp.address, weight: 10),        // non-recovery, weight 10
                (key: device2Kp.address, weight: 20),        // non-recovery, weight 20
            ])

        let serverKey = RecoveryServerKey(name: "deduce-server")
        let server = RecoveryServer(endpoint: "https://recovery.deduce.example",
                                    authEndpoint: "https://auth.deduce.example/auth",
                                    homeDomain: "recovery.deduce.example")
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

/// Fixtures for the folded recovery-model tests, prefixed to avoid collisions
/// with the names already used in this suite.
final class RecoveryModelTestFixtures {
    static let issuer = "GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
    static let otherIssuer = "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"

    static let signerHost = "domain-signer.recoverymodel.example"
    static let signerUrl = "https://\(signerHost)/sign"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"

    /// The SEP-30 response model types in the underlying iOS SDK only expose a
    /// Decodable initializer, so these helpers build them by decoding JSON.
    static func decodeSep30Identity(json: String) throws -> SEP30ResponseIdentity {
        return try JSONDecoder().decode(SEP30ResponseIdentity.self, from: json.data(using: .utf8)!)
    }

    static func decodeSep30Signer(json: String) throws -> SEP30ResponseSigner {
        return try JSONDecoder().decode(SEP30ResponseSigner.self, from: json.data(using: .utf8)!)
    }

    static func decodeSep30Account(json: String) throws -> Sep30AccountResponse {
        return try JSONDecoder().decode(Sep30AccountResponse.self, from: json.data(using: .utf8)!)
    }
}


// MARK: - Recovery SEP-30 mocks

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


// MARK: - Horizon account mock

struct RecoveryHorizonSigner {
    let key: String
    let weight: Int
}

/// Mocks GET https://horizon-testnet.stellar.org/accounts/{accountId} returning a fixed,
/// valid Horizon AccountResponse for the given account and signer set. Any account id that
/// is not explicitly registered is served a 404 notFound by the wildcard fallback
/// (RecoveryHorizonNotFoundMock), which the suite registers last.
class RecoveryHorizonAccountMock: ResponsesMock {
    let accountId: String
    let signers: [RecoveryHorizonSigner]

    init(accountId: String, signers: [RecoveryHorizonSigner]) {
        self.accountId = accountId
        self.signers = signers
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            mock.statusCode = 200
            return self.accountJson()
        }
        return RequestMock(host: RecoveryTestUtils.horizonHost,
                           path: "/accounts/\(accountId)",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    private func accountJson() -> String {
        let signersJson = signers.map { signer in
            """
            {
              "weight": \(signer.weight),
              "key": "\(signer.key)",
              "type": "ed25519_public_key"
            }
            """
        }.joined(separator: ",")

        return """
        {
          "_links": {
            "self": { "href": "https://\(RecoveryTestUtils.horizonHost)/accounts/\(accountId)" },
            "transactions": { "href": "https://\(RecoveryTestUtils.horizonHost)/accounts/\(accountId)/transactions{?cursor,limit,order}", "templated": true },
            "operations": { "href": "https://\(RecoveryTestUtils.horizonHost)/accounts/\(accountId)/operations{?cursor,limit,order}", "templated": true },
            "payments": { "href": "https://\(RecoveryTestUtils.horizonHost)/accounts/\(accountId)/payments{?cursor,limit,order}", "templated": true },
            "effects": { "href": "https://\(RecoveryTestUtils.horizonHost)/accounts/\(accountId)/effects{?cursor,limit,order}", "templated": true },
            "offers": { "href": "https://\(RecoveryTestUtils.horizonHost)/accounts/\(accountId)/offers{?cursor,limit,order}", "templated": true },
            "trades": { "href": "https://\(RecoveryTestUtils.horizonHost)/accounts/\(accountId)/trades{?cursor,limit,order}", "templated": true },
            "data": { "href": "https://\(RecoveryTestUtils.horizonHost)/accounts/\(accountId)/data/{key}", "templated": true }
          },
          "id": "\(accountId)",
          "account_id": "\(accountId)",
          "sequence": "4233721387843585",
          "subentry_count": 0,
          "last_modified_ledger": 985731,
          "last_modified_time": "2024-01-01T00:00:00Z",
          "thresholds": {
            "low_threshold": 0,
            "med_threshold": 0,
            "high_threshold": 0
          },
          "flags": {
            "auth_required": false,
            "auth_revocable": false,
            "auth_immutable": false,
            "auth_clawback_enabled": false
          },
          "balances": [
            {
              "balance": "10000.0000000",
              "buying_liabilities": "0.0000000",
              "selling_liabilities": "0.0000000",
              "asset_type": "native"
            }
          ],
          "signers": [
            \(signersJson)
          ],
          "data": {},
          "num_sponsoring": 0,
          "num_sponsored": 0,
          "paging_token": "\(accountId)"
        }
        """
    }
}

/// Wildcard fallback: any /accounts/* GET that is not matched by a specific
/// RecoveryHorizonAccountMock returns a Horizon 404 notFound. Registered explicitly
/// per scenario where a 404 precondition is required.
class RecoveryHorizonNotFoundMock: ResponsesMock {
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 404
            return self?.resourceMissingResponse()
        }
        return RequestMock(host: RecoveryTestUtils.horizonHost,
                           path: "/accounts/*",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
}


// MARK: - deduceKey (replaceDeviceKey) support

final class RecoverDeduceUtils {
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"
}

/// Mocks GET https://horizon-testnet.stellar.org/accounts/{accountId} returning a
/// fixed, valid Horizon AccountResponse for the given account and signer set.
///
/// The deduceKey branch tests only ever fetch the account from Horizon before the
/// expected ValidationError is thrown, so this mock clears any other registered
/// handlers on construction. That removes the suite's wildcard /accounts/* 404
/// fallback (registered last in RecoveryTest.setUp), which would otherwise match
/// before this account-specific mock and turn the account into a 404.
class RecoverDeduceHorizonAccountMock: ResponsesMock {
    let accountId: String
    let signers: [(key: String, weight: Int)]

    init(accountId: String, signers: [(key: String, weight: Int)]) {
        self.accountId = accountId
        self.signers = signers
        ServerMock.removeAll()
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
