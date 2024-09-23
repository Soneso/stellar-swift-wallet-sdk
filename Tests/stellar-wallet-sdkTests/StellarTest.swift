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
        let newAccount = try await stellar.account.getInfo(accountAddress: newAccountKeyPair.address)
        let balances = newAccount.balances
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
        let newAccount = try await account.getInfo(accountAddress: newAccountKeyPair.address)
        let balances = newAccount.balances
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
        let newAccount = try await account.getInfo(accountAddress: newAccountAddress)
        let signers = newAccount.signers
        
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
        let newAccount = try await account.getInfo(accountAddress: newAccountAddress)
        let signers = newAccount.signers
        
        XCTAssertEqual(1, signers.count)
        XCTAssertEqual(0, signers.first!.weight)
    }
    
}
