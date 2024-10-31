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
    
    func testAddAndRemoveAssetSupport() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        // define asset
        let assetCode = "USDC"
        let assetIssuerAccountId = "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5"
        let asset = try IssuedAssetId(
            code: assetCode,
            issuer: assetIssuerAccountId)
        
        // create transaction (add trustline)
        var tx = try await stellar.transaction(sourceAddress:accountKeyPair)
            .addAssetSupport(asset: asset, limit: 100)
            .build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        
        // submit transaction
        var success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        var accountInfo = try await account.getInfo(accountAddress: accountKeyPair.address)
        var balances = accountInfo.balances
        
        XCTAssertEqual(2, balances.count)
        var trustlineFound = false
        for balance in balances {
            if (balance.assetCode == assetCode) {
                XCTAssertEqual(balance.assetIssuer, assetIssuerAccountId)
                XCTAssertEqual(100, Double(balance.limit))
                trustlineFound = true
                break
            }
        }
        XCTAssertTrue(trustlineFound)
        
        // create transaction (remove trustline)
        tx = try await stellar.transaction(sourceAddress:accountKeyPair)
            .removeAssetSupport(asset: asset)
            .build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        accountInfo = try await account.getInfo(accountAddress: accountKeyPair.address)
        balances = accountInfo.balances
        XCTAssertEqual(1, balances.count)
        
    }
    
    func testSponsoredAddAndRemoveAssetSupport() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let sponsorKeyPair = accountKeyPair
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        
        // keypairs identifying the new account to be sponsored
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        let newAccountAddress = newAccountPublicKeyPair.address
        
        // fund the new test account
        try await stellar.fundTestNetAccount(address: newAccountAddress)
        
        // define asset
        let assetCode = "USDC"
        let assetIssuerAccountId = "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5"
        let asset = try IssuedAssetId(
            code: assetCode,
            issuer: assetIssuerAccountId)
        
        // create sponsored transaction (add trustline)
        var tx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                      buildingFunction: { (builder) in builder.addAssetSupport(asset: asset, limit: 100)},
                                      sponsoredAccount: newAccountPublicKeyPair).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        stellar.sign(tx: tx, keyPair: newAccountSigningKeyPair)
        
        // submit transaction
        var success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        var newAccountInfo = try await account.getInfo(accountAddress: newAccountAddress)
        var balances = newAccountInfo.balances
        
        XCTAssertEqual(2, balances.count)
        var trustlineFound = false
        for balance in balances {
            if (balance.assetCode == assetCode) {
                XCTAssertEqual(balance.assetIssuer, assetIssuerAccountId)
                XCTAssertEqual(100, Double(balance.limit))
                trustlineFound = true
                break
            }
        }
        XCTAssertTrue(trustlineFound)
        
        // create sponsored transaction (remove trustline)
        tx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                      buildingFunction: { (builder) in builder.removeAssetSupport(asset: asset)},
                                      sponsoredAccount: newAccountPublicKeyPair).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: accountKeyPair)
        stellar.sign(tx: tx, keyPair: newAccountSigningKeyPair)
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        newAccountInfo = try await account.getInfo(accountAddress: newAccountAddress)
        balances = newAccountInfo.balances
        XCTAssertEqual(1, balances.count)
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
    
    func testMakeFeeBump() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let replaceWith = account.createKeyPair()
        
        let sponsorKeyPair = account.createKeyPair()
        let sponsorAddress = sponsorKeyPair.address
        try await stellar.fundTestNetAccount(address: sponsorAddress)
        
        let sponsoredKeyPair = account.createKeyPair()
        let sponsoredAddress = sponsoredKeyPair.address
        try await stellar.fundTestNetAccount(address: sponsoredAddress)
        
        let txBuilder = try await stellar.transaction(sourceAddress: sponsoredKeyPair)
        
        let transaction = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                                   buildingFunction: { (builder) in builder.lockAccountMasterKey().addAccountSigner(
                                                    signerAddress: replaceWith, 
                                                    signerWeight: 1)}).build()
        
        stellar.sign(tx: transaction, keyPair: sponsorKeyPair)
        stellar.sign(tx: transaction, keyPair: sponsoredKeyPair)
                
        let feeBump = try stellar.makeFeeBump(feeAddress: sponsorKeyPair, transaction: transaction)
        stellar.sign(feeBumpTx: feeBump, keyPair: sponsorKeyPair)
        
        // submit transaction
        let success = try await stellar.submitTransaction(signedFeeBumpTransaction: feeBump)
        XCTAssertTrue(success)
        
        // validate
        let myAccount = try await account.getInfo(accountAddress: sponsoredAddress)
        XCTAssertEqual(1, myAccount.balances.count)
        XCTAssertEqual(10000, Double(myAccount.balances.first!.balance))
        let signers = myAccount.signers
        XCTAssertEqual(2, signers.count)
        var newSignerFound = false
        var masterKeySignerFound = false
        for signer in signers {
            if (signer.key == replaceWith.address) {
                XCTAssertEqual(1, signer.weight)
                newSignerFound = true
            } else if (signer.key == sponsoredAddress) {
                XCTAssertEqual(0, signer.weight)
                masterKeySignerFound = true
            } else {
                XCTFail("should not have additional signers")
            }
        }
        XCTAssertTrue(newSignerFound)
        XCTAssertTrue(masterKeySignerFound)
        
        // test base64 xdr encoding and decoding
        guard let envelopeXdr = feeBump.toEnvelopeXdrBase64() else {
            XCTFail("could not encode fee bump transaction")
            return
        }
        let decodedTxEnum = stellar.decodeTransaction(xdr: envelopeXdr)
        switch decodedTxEnum {
        case .transaction(_):
            XCTFail("should not be normal transaction")
        case .feeBumpTransaction(let feeBumpTx):
            XCTAssertEqual(feeBumpTx.toEnvelopeXdrBase64(), envelopeXdr)
        case .invalidXdrErr:
            XCTFail("sould not be invalid xdr")
        }
    }
    
    func testUseXdrToSendTxData() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let sponsorKeyPair = try PublicKeyPair(accountId: "GBUTDNISXHXBMZE5I4U5INJTY376S5EW2AF4SQA2SWBXUXJY3OIZQHMV")
        let newKeyPair = account.createKeyPair()
        
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        let sponsorAccountCreationTx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair, 
                                                                buildingFunction: { (builder) in builder.createAccount(newAccount: newKeyPair)},
                                                                sponsoredAccount: newKeyPair).build()
        
        stellar.sign(tx: sponsorAccountCreationTx, keyPair: newKeyPair)
        
        guard let xdrString = sponsorAccountCreationTx.toEnvelopeXdrBase64() else {
            XCTFail("could not encode transaction to base 64 xdr")
            return
        }
        
        // Send xdr encoded transaction to your backend server to sign
        let xdrStringFromBackend = try await sendTransactionToBackend(xdr:xdrString)
        
        // Decode xdr to get the signed transaction
        let signedTransactionEnum = stellar.decodeTransaction(xdr: xdrStringFromBackend)
        
        switch signedTransactionEnum {
        case .transaction(let tx):
            // submit transaction
            let success = try await stellar.submitTransaction(signedTransaction: tx)
            XCTAssertTrue(success)
        case .feeBumpTransaction(_):
            XCTFail("should not be fee bump")
        case .invalidXdrErr:
            XCTFail("invalid xdr received from server")
        }
        
        // validate
        let newAccount = try await account.getInfo(accountAddress: newKeyPair.address)
        XCTAssertGreaterThan(newAccount.sequenceNumber, 0)
        let balance = newAccount.balances.first!
        XCTAssertEqual("native", balance.assetType)
        XCTAssertEqual(0.0, Double(balance.balance))
        
    }
    
    private func sendTransactionToBackend(xdr:String) async throws -> String {
        let serverSigner = try DomainSigner(url: "https://server-signer.replit.app/sign",
                                        requestHeaders: ["Authorization": "Bearer 987654321"]);
        return try await serverSigner.signWithDomainAccount(transactionXDR: xdr,
                                                        networkPassPhrase: "Test SDF Network ; September 2015")
    }
}
