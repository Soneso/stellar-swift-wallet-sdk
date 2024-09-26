//
//  StellarTest.swift
//  
//
//  Created by Christian Rogobete on 20.09.24.
//

import XCTest
@testable import stellar_wallet_sdk

final class StellarTest: XCTestCase {
    let wallet = Wallet.testNet
    let accountKeyPair = Wallet.testNet.stellar.account.createKeyPair()
    
    override func setUp() async throws {
        try await super.setUp()
        try await wallet.stellar.fundTestNetAccount(address: accountKeyPair.address)
        
    }

    func testGetInfo() async throws {
        let accountInfo = try await wallet.stellar.account.getInfo(accountAddress: accountKeyPair.address)
        XCTAssertTrue(accountInfo.balances.count > 0)
    }
    
    func testCreateAccount() async throws {
        let stellar = wallet.stellar
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: accountKeyPair)
        
        // keypair identifying the new account to be created
        let newAccountKeyPair = stellar.account.createKeyPair()
        
        // create transaction
        let tx = try txBuilder.createAccount(newAccount: newAccountKeyPair, startingBalance: 100.1).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        
        // submit transaction
        let success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        let accountInfo = try await stellar.account.getInfo(accountAddress: newAccountKeyPair.address)
        let balances = accountInfo.balances
        XCTAssertEqual(1, balances.count)
        XCTAssertEqual("native", balances.first!.assetType)
        XCTAssertEqual(Double(balances.first!.balance), 100.1)
    }
    
    func testCreateSponsoredAccount() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let sponsorKeyPair = accountKeyPair
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        
        // keypair identifying the new account to be created
        let newAccountKeyPair = account.createKeyPair()
        
        // create transaction
        let tx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                      buildingFunction: { (builder) in builder.createAccount(newAccount: newAccountKeyPair)},
                                      sponsoredAccount: newAccountKeyPair).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        stellar.sign(tx: tx, keyPair: newAccountKeyPair)
        
        // submit transaction
        let success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        let accountInfo = try await account.getInfo(accountAddress: newAccountKeyPair.address)
        let balances = accountInfo.balances
        XCTAssertEqual(1, balances.count)
        XCTAssertEqual("native", balances.first!.assetType)
        XCTAssertEqual(Double(balances.first!.balance), 0.0)
    }
    
    func testLockMasterKey() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        // keypairs & account id
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        let newAccountAddress = newAccountPublicKeyPair.address
        
        // fund the new test account
        try await stellar.fundTestNetAccount(address: newAccountAddress)
        
        // create transaction
        let tx = try await stellar.transaction(sourceAddress:newAccountPublicKeyPair).lockAccountMasterKey().build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: newAccountSigningKeyPair)
        
        // submit transaction
        let success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        let accountInfo = try await account.getInfo(accountAddress: newAccountAddress)
        let signers = accountInfo.signers
        
        XCTAssertEqual(1, signers.count)
        XCTAssertEqual(0, signers.first!.weight)
    }
    
    func testSponsoredLockMasterKey() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let sponsorKeyPair = accountKeyPair
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        
        // keypairs identifying the new account to be locked
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        let newAccountAddress = newAccountPublicKeyPair.address
        
        // fund the new test account
        try await stellar.fundTestNetAccount(address: newAccountAddress)
        
        // create transaction
        let tx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                      buildingFunction: { (builder) in builder.lockAccountMasterKey()},
                                      sponsoredAccount: newAccountPublicKeyPair).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        stellar.sign(tx: tx, keyPair: newAccountSigningKeyPair)
        
        // submit transaction
        let success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        let accountInfo = try await account.getInfo(accountAddress: newAccountAddress)
        let signers = accountInfo.signers
        
        XCTAssertEqual(1, signers.count)
        XCTAssertEqual(0, signers.first!.weight)
    }
    
    
    func testAddAndRemoveAccountSigner() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        // keypairs & account id
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        
        // create transaction (add signer)
        var tx = try await stellar.transaction(sourceAddress:accountKeyPair)
            .addAccountSigner(signerAddress: newAccountPublicKeyPair, signerWeight: 11)
            .build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        
        // submit transaction
        var success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        var accountInfo = try await account.getInfo(accountAddress: accountKeyPair.address)
        var signers = accountInfo.signers
        
        XCTAssertEqual(2, signers.count)
        var signerFound = false
        for signer in signers {
            if (signer.weight == 11) {
                signerFound = true
                break
            }
        }
        XCTAssertTrue(signerFound)
        
        // create transaction (remove signer)
        tx = try await stellar.transaction(sourceAddress:accountKeyPair)
            .removeAccountSigner(signerAddress: newAccountPublicKeyPair)
            .build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        accountInfo = try await account.getInfo(accountAddress: accountKeyPair.address)
        signers = accountInfo.signers
        XCTAssertEqual(1, signers.count)
        XCTAssertNotEqual(11, signers.first!.weight)
        
    }
    
    func testSponsoredAddAndRemoveAccountSigner() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let sponsorKeyPair = accountKeyPair
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        
        // keypairs identifying the new account to be locked
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        let newAccountAddress = newAccountPublicKeyPair.address
        
        // fund the new test account
        try await stellar.fundTestNetAccount(address: newAccountAddress)
        
        // public keypair of new signer
        let newSignerPublicKeyPair = account.createKeyPair().toPublicKeyPair()
        
        // create sponsored transaction (add signer)
        var tx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                      buildingFunction: { (builder) in builder.addAccountSigner(signerAddress: newSignerPublicKeyPair, signerWeight: 11)},
                                      sponsoredAccount: newAccountPublicKeyPair).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        stellar.sign(tx: tx, keyPair: newAccountSigningKeyPair)
        
        // submit transaction
        var success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        var newAccountInfo = try await account.getInfo(accountAddress: newAccountAddress)
        var signers = newAccountInfo.signers
        
        XCTAssertEqual(2, signers.count)
        var signerFound = false
        for signer in signers {
            if (signer.weight == 11) {
                signerFound = true
                break
            }
        }
        XCTAssertTrue(signerFound)
        
        // create sponsored transaction (remove signer)
        tx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                      buildingFunction: { (builder) in try! builder.removeAccountSigner(signerAddress: newSignerPublicKeyPair)},
                                      sponsoredAccount: newAccountPublicKeyPair).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        stellar.sign(tx: tx, keyPair: newAccountSigningKeyPair)
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        newAccountInfo = try await account.getInfo(accountAddress: newAccountAddress)
        signers = newAccountInfo.signers
        
        XCTAssertEqual(1, signers.count)
        XCTAssertNotEqual(11, signers.first!.weight)
    }
    
    func testAccountMerge() async throws {
        let stellar = wallet.stellar
        
        // create 2 new accounts for testing and fund them
        let sourceAccountKeyPair = stellar.account.createKeyPair()
        let sourceAccountAddress = sourceAccountKeyPair.address
        try await stellar.fundTestNetAccount(address: sourceAccountAddress)
        
        let destinationAccountKeyPair = stellar.account.createKeyPair()
        let destinationAccountAddress = destinationAccountKeyPair.address
        try await stellar.fundTestNetAccount(address: destinationAccountAddress)
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(
            sourceAddress: accountKeyPair,
            baseFee: 1000)
        
        // create transaction
        let mergeTxn = try txBuilder.accountMerge(
            destinationAddress: destinationAccountAddress,
            sourceAddress: sourceAccountAddress
        ).build()
        
        // sign transaction
        stellar.sign(tx: mergeTxn, keyPair: accountKeyPair)
        stellar.sign(tx: mergeTxn, keyPair: sourceAccountKeyPair)
        
        // submit transaction
        let success = try await stellar.submitTransaction(signedTransaction: mergeTxn)
        XCTAssertTrue(success)
        
        // validate
        let sourceExists = try await stellar.account.accountExists(accountAddress: sourceAccountAddress)
        XCTAssertFalse(sourceExists)
        
        let accountInfo = try await stellar.account.getInfo(accountAddress: destinationAccountAddress)
        let balances = accountInfo.balances
        XCTAssertEqual(1, balances.count)
        XCTAssertEqual("native", balances.first!.assetType)
        XCTAssertTrue(Double(balances.first!.balance)! > 10.000)
    }
    
    
    func testSetTreshold() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        // create a new account for testing and fund it
        let sourceAccountKeyPair = account.createKeyPair()
        let sourceAccountAddress = sourceAccountKeyPair.address
        try await stellar.fundTestNetAccount(address: sourceAccountAddress)
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(
            sourceAddress: sourceAccountKeyPair)
        
        // create transaction
        let tx = try txBuilder.setThreshold(low: 1, medium: 10, high: 30).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: sourceAccountKeyPair)
        
        // submit transaction
        let success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        let accountInfo = try await account.getInfo(accountAddress: sourceAccountAddress)
        
        XCTAssertEqual(1, accountInfo.thresholds.lowThreshold)
        XCTAssertEqual(10, accountInfo.thresholds.medThreshold)
        XCTAssertEqual(30, accountInfo.thresholds.highThreshold)
    }
    
    func testSponsoredSetTreshold() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let sponsorKeyPair = accountKeyPair
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        
        // keypairs identifying the new account to be used
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        let newAccountAddress = newAccountPublicKeyPair.address
        
        // fund the new test account
        try await stellar.fundTestNetAccount(address: newAccountAddress)
        
        // create transaction
        let tx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                      buildingFunction: { (builder) in builder.setThreshold(low: 1, medium: 10, high: 30)},
                                      sponsoredAccount: newAccountPublicKeyPair).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        stellar.sign(tx: tx, keyPair: newAccountSigningKeyPair)
        
        // submit transaction
        let success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        let accountInfo = try await account.getInfo(accountAddress: newAccountAddress)        
        XCTAssertEqual(1, accountInfo.thresholds.lowThreshold)
        XCTAssertEqual(10, accountInfo.thresholds.medThreshold)
        XCTAssertEqual(30, accountInfo.thresholds.highThreshold)
    }
}
