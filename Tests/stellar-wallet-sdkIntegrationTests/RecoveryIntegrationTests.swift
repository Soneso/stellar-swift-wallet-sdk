//
//  RecoveryIntegrationTests.swift
//  stellar-wallet-sdkIntegrationTests
//
//  Integration tests for SEP-30 Recovery protocol with multiple servers
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class RecoveryIntegrationTests: IntegrationTestCase {
    
    var recovery: Recovery!
    var accountKp: SigningKeyPair!
    var deviceKp: SigningKeyPair!
    var recoveryKp: SigningKeyPair!
    
    override func setUp() {
        super.setUp()
        
        // Skip if Docker is not available
        do {
            try requireDocker()
        } catch {
            return
        }
        
        // Setup recovery service with two test servers
        let servers: [RecoveryServerKey: RecoveryServer] = [
            RecoveryServerKey(name: "server1"): RecoveryServer(
                endpoint: TestConstants.DockerServices.recoveryServer1Endpoint,
                authEndpoint: TestConstants.DockerServices.recoveryServer1AuthEndpoint,
                homeDomain: "soneso.com/r1"
            ),
            RecoveryServerKey(name: "server2"): RecoveryServer(
                endpoint: TestConstants.DockerServices.recoveryServer2Endpoint,
                authEndpoint: TestConstants.DockerServices.recoveryServer2AuthEndpoint,
                homeDomain: "soneso.com/r2"
            )
        ]
        
        recovery = wallet.recovery(servers: servers)
    }
    
    override func tearDown() {
        recovery = nil
        accountKp = nil
        deviceKp = nil
        recoveryKp = nil
        super.tearDown()
    }
    
    // MARK: - Complete Recovery Flow Test
    
    func testCompleteRecoveryFlow() async throws {
        try requireDocker()
        
        // Create and fund test accounts
        accountKp = try await createAndFundAccount()
        deviceKp = try await createAndFundAccount()
        recoveryKp = try await createAndFundAccount()
        
        print("Test accounts created:")
        print("  Account: \(accountKp.address)")
        print("  Device: \(deviceKp.address)")
        print("  Recovery: \(recoveryKp.address)")
        
        // Setup server keys
        let server1Key = RecoveryServerKey(name: "server1")
        let server2Key = RecoveryServerKey(name: "server2")
        
        // Create SEP-30 identities
        let identity1 = RecoveryAccountIdentity(
            role: RecoveryRole.owner,
            authMethods: [
                RecoveryAccountAuthMethod(
                    type: RecoveryType.stellarAddress,
                    value: recoveryKp.address
                )
            ]
        )
        
        let identity2 = RecoveryAccountIdentity(
            role: RecoveryRole.owner,
            authMethods: [
                RecoveryAccountAuthMethod(
                    type: RecoveryType.stellarAddress,
                    value: recoveryKp.address
                ),
                RecoveryAccountAuthMethod(
                    type: RecoveryType.email,
                    value: "my-email@example.com"
                )
            ]
        )
        
        // Create recoverable wallet
        let config = RecoverableWalletConfig(
            accountAddress: accountKp,
            deviceAddress: deviceKp,
            accountThreshold: AccountThreshold(low: 10, medium: 10, high: 10),
            accountIdentity: [
                server1Key: [identity1],
                server2Key: [identity2]
            ],
            signerWeight: SignerWeight(device: 10, recoveryServer: 5),
            sponsorAddress: nil
        )
        
        let recoverableWallet = try await recovery.createRecoverableWallet(config: config)
        
        // Sign and submit transaction
        stellar.sign(tx: recoverableWallet.transaction, keyPair: accountKp)
        let isSuccess = try await stellar.submitTransaction(signedTransaction: recoverableWallet.transaction)
        XCTAssertTrue(isSuccess)
        
        print("Recoverable wallet created successfully")
        
        // Verify account setup
        let accountDetails = try await stellar.account.getInfo(accountAddress: accountKp.address)
        
        var signers = accountDetails.signers
        let weights = signers.map { Int($0.weight) }.sorted()
        XCTAssertEqual(weights, [0, 5, 5, 10])
        
        // Verify account weight is 0
        let accountSigner = signers.first { $0.key == accountKp.address }
        XCTAssertEqual(accountSigner?.weight, 0)
        
        // Verify device weight is 10
        let deviceSigner = signers.first { $0.key == deviceKp.address }
        XCTAssertEqual(deviceSigner?.weight, 10)
        
        print("Account setup verified - signers weights: \(weights)")
        
        // Get account info
        let sep10Server1 = try await recovery.sep10Auth(key: server1Key)
        let authToken1 = try await sep10Server1.authenticate(
            userKeyPair: recoveryKp,
            memoId: nil,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        let authMap = [server1Key: authToken1.jwt]
        let accountInfoMap = try await recovery.getAccountInfo(
            accountAddress: accountKp,
            auth: authMap
        )
        
        guard let accountInfo = accountInfoMap[server1Key] else {
            XCTFail("Error retrieving account info from server \(server1Key)")
            return
        }
        
        XCTAssertEqual(accountInfo.address.address, accountKp.address)
        XCTAssertEqual(accountInfo.identities[0].role, RecoveryRole.owner)
        XCTAssertEqual(accountInfo.signers.count, 1)
        print("Account info retrieved successfully")
        
        // Recover wallet - replace device key
        let sep10Server2 = try await recovery.sep10Auth(key: server2Key)
        let authToken2 = try await sep10Server2.authenticate(
            userKeyPair: recoveryKp,
            memoId: nil,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        // Create new device key
        let newDeviceKp = try await createAndFundAccount()
        print("New device key created: \(newDeviceKp.address)")
        
        // Get recovery signer addresses
        let recoverySignerAddress1 = accountInfo.signers[0].key.address
        guard let recoverySignerAddress2 = recoverableWallet.signers.filter({$0 !=  recoverySignerAddress1}).first else {
            XCTFail("Error retrieving signer addresses from server \(server2Key)")
            return
        }
        
        // Create signer auth map
        let signerAuthMap: [RecoveryServerKey: RecoveryServerSigning] = [
            server1Key: RecoveryServerSigning(
                signerAddress: recoverySignerAddress1,
                authToken: authToken1.jwt
            ),
            server2Key: RecoveryServerSigning(
                signerAddress: recoverySignerAddress2,
                authToken: authToken2.jwt
            )
        ]
        
        // Replace device key
        let recoveryTransaction = try await recovery.replaceDeviceKey(
            account: accountKp,
            newKey: newDeviceKp,
            serverAuth: signerAuthMap
        )
        
        // Submit recovery transaction
        let recoverySuccess = try await stellar.submitTransaction(signedTransaction: recoveryTransaction)
        XCTAssertTrue(recoverySuccess)
        
        print("Device key replaced successfully")
        
        // Verify device key was replaced

        let finalDetails = try await stellar.account.getInfo(accountAddress: accountKp.address)
        
        signers = finalDetails.signers
        
        // Old device key should not exist
        let oldDeviceSigner = signers.first { $0.key == deviceKp.address }
        XCTAssertNil(oldDeviceSigner)
        
        // New device key should have weight 10
        let newDeviceSigner = signers.first { $0.key == newDeviceKp.address }
        XCTAssertEqual(newDeviceSigner?.weight, 10)
        
        print("Recovery verified - new device key has correct weight")
    }
}
