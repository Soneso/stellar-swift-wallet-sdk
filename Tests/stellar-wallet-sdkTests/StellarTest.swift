//
//  StellarTest.swift
//  
//
//  Created by Christian Rogobete on 20.09.24.
//

import XCTest
import stellarsdk
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
        return try await serverSigner.signWithDomainAccount(transactionXdr: xdr,
                                                            networkPassphrase: "Test SDF Network ; September 2015")
    }
    
    func testSubmitTxWithFeeIncrease() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let account1KeyPair = account.createKeyPair()
        try await stellar.fundTestNetAccount(address: account1KeyPair.address)
        let account2KeyPair = account.createKeyPair()
        try await stellar.fundTestNetAccount(address: account2KeyPair.address)
        
        // this test is more effective on public net
        // change wallet on top to: var wallet = Wallet.publicNet;
        // uncomment and fill:
        // let account1KeyPair = try SigningKeyPair(secretKey: "S...")
        // let account2KeyPair = try PublicKeyPair(accountId: "GBH5Y77GMEOCYQOXGAMJY4C65RAMBXKZBDHA5XBNLJQUC3Z2HGQP5OC5")
        
        let success =
        try await stellar.submitWithFeeIncrease(sourceAddress: account1KeyPair,
                                              timeout: 30,
                                              baseFeeIncrease: 100,
                                              maxBaseFee: 2000,
                                              buildingFunction: {
                                                    (builder) in try! builder.transfer(destinationAddress: account2KeyPair.address,
                                                                                       assetId: NativeAssetId(),
                                                                                       amount: 10.0)})
        
        XCTAssertTrue(success)
        
        // validate
        let newAccount = try await account.getInfo(accountAddress: account2KeyPair.address)
        let balance = newAccount.balances.first!
        XCTAssertEqual("native", balance.assetType)
        XCTAssertEqual(10010.0, Double(balance.balance))
        
    }
    
    func testPathPayments() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let keyPairA = account.createKeyPair()
        try await stellar.fundTestNetAccount(address: keyPairA.address)
        let accountAId = keyPairA.address
        
        let keyPairB = account.createKeyPair()
        let accountBId = keyPairB.address
        
        let keyPairC = account.createKeyPair()
        let accountCId = keyPairC.address
        
        let keyPairD = account.createKeyPair()
        let accountDId = keyPairD.address
        
        let keyPairE = account.createKeyPair()
        let accountEId = keyPairE.address
            
        // fund the other accounts.
        var txBuilder = try await stellar.transaction(sourceAddress: keyPairA)
        
        let createAccountsTransaction = try txBuilder
            .createAccount(newAccount: keyPairB, startingBalance: 10)
            .createAccount(newAccount: keyPairC, startingBalance: 10)
            .createAccount(newAccount: keyPairD, startingBalance: 10)
            .createAccount(newAccount: keyPairE, startingBalance: 10)
            .build();
        
        stellar.sign(tx: createAccountsTransaction, keyPair: keyPairA)
        
        // submit transaction
        var success = try await stellar.submitTransaction(signedTransaction: createAccountsTransaction)
        XCTAssertTrue(success)
        
        // create assets for testing
        let iomAsset = try! IssuedAssetId(code: "IOM", issuer: accountAId)
        let ecoAsset = try! IssuedAssetId(code: "ECO", issuer: accountAId)
        let moonAsset = try! IssuedAssetId(code: "MOON", issuer: accountAId)
        
        // let c trust iom
        txBuilder = try await stellar.transaction(sourceAddress: keyPairC)
        var trustTransaction = try txBuilder.addAssetSupport(asset: iomAsset, limit: 200999).build()
        stellar.sign(tx: trustTransaction, keyPair: keyPairC);

        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: trustTransaction)
        XCTAssertTrue(success)
        

        // let b trust iom and eco
        txBuilder = try await stellar.transaction(sourceAddress: keyPairB)
        trustTransaction = try txBuilder.addAssetSupport(asset: iomAsset, limit: 200999).addAssetSupport(asset: ecoAsset, limit: 200999).build()
        stellar.sign(tx: trustTransaction, keyPair: keyPairB);
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: trustTransaction)
        XCTAssertTrue(success)
        
        // let d trust eco and moon
        txBuilder = try await stellar.transaction(sourceAddress: keyPairD)
        trustTransaction = try txBuilder.addAssetSupport(asset: ecoAsset, limit: 200999).addAssetSupport(asset: moonAsset, limit: 200999).build()
        stellar.sign(tx: trustTransaction, keyPair: keyPairD);
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: trustTransaction)
        XCTAssertTrue(success)
        
        // let e trust moon
        txBuilder = try await stellar.transaction(sourceAddress: keyPairE)
        trustTransaction = try txBuilder.addAssetSupport(asset: moonAsset, limit: 200999).build()
        stellar.sign(tx: trustTransaction, keyPair: keyPairE);

        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: trustTransaction)
        XCTAssertTrue(success)
        
        // fund accounts with issued assets
        txBuilder = try await stellar.transaction(sourceAddress: keyPairA);
        let fundTransaction = try txBuilder
            .transfer(destinationAddress: accountCId, assetId: iomAsset, amount: 100)
            .transfer(destinationAddress: accountBId, assetId: iomAsset, amount: 100)
            .transfer(destinationAddress: accountBId, assetId: ecoAsset, amount: 100)
            .transfer(destinationAddress: accountDId, assetId: moonAsset, amount: 100)
            .build();
        stellar.sign(tx: fundTransaction, keyPair: keyPairA)
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: fundTransaction)
        XCTAssertTrue(success)
        
        // B makes offer: sell 100 ECO - buy IOM, price 0.5
        let sellOfferOpB = ManageSellOfferOperation(sourceAccountId: accountBId,
                                                    selling: ecoAsset.toAsset(),
                                                    buying: iomAsset.toAsset(),
                                                    amount: 100,
                                                    price: Price(numerator: 1, denominator: 2),
                                                    offerId: 0)
        
        // D makes offer: sell 100 MOON - buy ECO, price 0.5
        let sellOfferOpD = ManageSellOfferOperation(sourceAccountId: accountDId,
                                                    selling: moonAsset.toAsset(),
                                                    buying: ecoAsset.toAsset(),
                                                    amount: 100,
                                                    price: Price(numerator: 1, denominator: 2),
                                                    offerId: 0)
        
        txBuilder = try await stellar.transaction(sourceAddress: keyPairB)
        let sellOfferTransaction = try txBuilder.addOperation(operation: sellOfferOpB).addOperation(operation: sellOfferOpD).build()
        stellar.sign(tx: sellOfferTransaction, keyPair: keyPairB)
        stellar.sign(tx: sellOfferTransaction, keyPair: keyPairD)
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: sellOfferTransaction)
        XCTAssertTrue(success)
        
        // wait a bit for the ledger to close
        try! await Task.sleep(nanoseconds: UInt64(5 * Double(NSEC_PER_SEC)))
        
        // check if we can find the path to send 10 IOM to E, since E does not trust IOM
        // expected IOM->ECO->MOON
        var paymentPaths = try await stellar.findStrictSendPathForDestinationAddress(destinationAddress: accountEId,
                                                                                     sourceAssetId: iomAsset,
                                                                                     sourceAmount: "10")
        XCTAssertEqual(1, paymentPaths.count)
        var paymentPath = paymentPaths.first!
        XCTAssertEqual(moonAsset.sep38, paymentPath.destinationAsset.sep38)
        XCTAssertEqual(iomAsset.sep38, paymentPath.sourceAsset.sep38)
        XCTAssertEqual(10, Double(paymentPath.sourceAmount))
        XCTAssertEqual(40, Double(paymentPath.destinationAmount))
        
        var assetsPath = paymentPath.path
        XCTAssertEqual(1, assetsPath.count)
        XCTAssertEqual(ecoAsset.sep38, assetsPath.first!.sep38)
        
        paymentPaths = try await stellar.findStrictSendPathForDestinationAssets(destinationAssets: [moonAsset],
                                                                                sourceAssetId: iomAsset,
                                                                                sourceAmount: "10")
        
        XCTAssertEqual(1, paymentPaths.count)
        paymentPath = paymentPaths.first!
        XCTAssertEqual(moonAsset.sep38, paymentPath.destinationAsset.sep38)
        XCTAssertEqual(iomAsset.sep38, paymentPath.sourceAsset.sep38)
        XCTAssertEqual(10, Double(paymentPath.sourceAmount))
        XCTAssertEqual(40, Double(paymentPath.destinationAmount))
        
        assetsPath = paymentPath.path
        XCTAssertEqual(1, assetsPath.count)
        XCTAssertEqual(ecoAsset.sep38, assetsPath.first!.sep38)
        
        // C sends IOM to E (she receives MOON)
        txBuilder = try await stellar.transaction(sourceAddress: keyPairC)
        let strictSendTransaction = try txBuilder.strictSend(sendAssetId: iomAsset,
                                                             sendAmount: 5,
                                                             destinationAddress: accountEId,
                                                             destinationAssetId: moonAsset,
                                                             destinationMinAmount: 19,
                                                             path: assetsPath).build()
        
        stellar.sign(tx: strictSendTransaction, keyPair: keyPairC)
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: strictSendTransaction)
        XCTAssertTrue(success)
        
        // test also "pathPay"
        txBuilder = try await stellar.transaction(sourceAddress: keyPairC)
        let pathPayTransaction = try txBuilder.pathPay(destinationAddress: accountEId,
                                                       sendAsset: iomAsset,
                                                       destinationAsset: moonAsset,
                                                       sendAmount: 5,
                                                       destMin: 19,
                                                       path: assetsPath).build()
        stellar.sign(tx: pathPayTransaction, keyPair: keyPairC)
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: pathPayTransaction)
        XCTAssertTrue(success)
        
        // check if E received MOON
        var info = try await account.getInfo(accountAddress: accountEId)
        var moonFound = false
        info.balances.forEach{  item in
            if item.assetCode == "MOON" {
                moonFound = true
                XCTAssertEqual(40, Double(item.balance))
            }
        }
        XCTAssertTrue(moonFound)
        
        // next lets check strict receive
        paymentPaths = try await stellar.findStrictReceivePathForSourceAddress(sourceAddress: accountCId,
                                                                               destinationAssetId: moonAsset,
                                                                               destinationAmount: "8")
        
        XCTAssertEqual(1, paymentPaths.count)
        paymentPath = paymentPaths.first!
        XCTAssertEqual(moonAsset.sep38, paymentPath.destinationAsset.sep38)
        XCTAssertEqual(iomAsset.sep38, paymentPath.sourceAsset.sep38)
        XCTAssertEqual(2, Double(paymentPath.sourceAmount))
        XCTAssertEqual(8, Double(paymentPath.destinationAmount))
        
        assetsPath = paymentPath.path
        XCTAssertEqual(1, assetsPath.count)
        XCTAssertEqual(ecoAsset.sep38, assetsPath.first!.sep38)
        
        // for source assets
        paymentPaths = try await stellar.findStrictReceivePathForSourceAssets(sourceAssets: [iomAsset],
                                                                              destinationAssetId: moonAsset,
                                                                              destinationAmount: "8")
        
        XCTAssertEqual(1, paymentPaths.count)
        paymentPath = paymentPaths.first!
        XCTAssertEqual(moonAsset.sep38, paymentPath.destinationAsset.sep38)
        XCTAssertEqual(iomAsset.sep38, paymentPath.sourceAsset.sep38)
        XCTAssertEqual(2, Double(paymentPath.sourceAmount))
        XCTAssertEqual(8, Double(paymentPath.destinationAmount))
        
        assetsPath = paymentPath.path
        XCTAssertEqual(1, assetsPath.count)
        XCTAssertEqual(ecoAsset.sep38, assetsPath.first!.sep38)
        
        // send to E
        txBuilder = try await stellar.transaction(sourceAddress: keyPairC)
        let strictReceiveTransaction = try txBuilder.strictReceive(sendAssetId: iomAsset,
                                                                   destinationAddress: accountEId,
                                                                   destinationAssetId: moonAsset,
                                                                   destinationAmount: 8,
                                                                   sendMaxAmount: 2, 
                                                                   path: assetsPath).build()
        
        stellar.sign(tx: strictReceiveTransaction, keyPair: keyPairC)
        
        // submit transaction
        success = try await stellar.submitTransaction(signedTransaction: strictReceiveTransaction)
        XCTAssertTrue(success)
        
        // check if E received MOON
        info = try await account.getInfo(accountAddress: accountEId)
        moonFound = false
        info.balances.forEach{  item in
            if item.assetCode == "MOON" {
                moonFound = true
                XCTAssertEqual(48, Double(item.balance))
            }
        }
        XCTAssertTrue(moonFound)
        
    }
        
}
