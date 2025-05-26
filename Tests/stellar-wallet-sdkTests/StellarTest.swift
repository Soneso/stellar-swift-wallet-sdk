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
    let testMode = "testnet" // "mainnet"
    var wallet:Wallet!
    var accountKeyPair:SigningKeyPair!

    
    override func setUp() async throws {
        try await super.setUp()
        if "testnet" == testMode {
            wallet = Wallet.testNet
            accountKeyPair = SigningKeyPair.random
            try await wallet.stellar.fundTestNetAccount(address: accountKeyPair.address)
        } else if "mainnet" == testMode {
            wallet = Wallet.publicNet
            accountKeyPair = try SigningKeyPair(secretKey: "S...")
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
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
        let tx = try txBuilder.createAccount(newAccount: newAccountKeyPair, startingBalance: 1.1).build()
        
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
        XCTAssertEqual(Double(balances.first!.balance), 1.1)
        
        if "mainnet" == testMode {
            // merge back to save XLM
            try await merge(signer: newAccountKeyPair, destination: accountKeyPair.address)
        }
        
    }
    
    func testCreateSponsoredAccount() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let sponsorKeyPair = accountKeyPair!
        
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
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: newAccountAddress)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: newAccountPublicKeyPair)
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
        
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
        
        let sponsorKeyPair = accountKeyPair!
                
        // keypairs identifying the new account to be locked
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        let newAccountAddress = newAccountPublicKeyPair.address
        
        // fund the new test account
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: newAccountAddress)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: newAccountPublicKeyPair)
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        
        // create transaction
        let tx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                      buildingFunction: { (builder) in builder.lockAccountMasterKey()},
                                      sponsoredAccount: newAccountPublicKeyPair).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: sponsorKeyPair)
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
        
        let sponsorKeyPair = accountKeyPair!
                
        // keypairs identifying the new account
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        let newAccountAddress = newAccountPublicKeyPair.address
        
        // fund the new test account
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: newAccountAddress)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: newAccountPublicKeyPair)
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
        // public keypair of new signer
        let newSignerPublicKeyPair = account.createKeyPair().toPublicKeyPair()
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        
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
        
        if "mainnet" == testMode {
            // merge back to save XLM
            try await merge(signer: newAccountSigningKeyPair, destination: accountKeyPair.address)
        }
    }
    
    func testAddAndRemoveAssetSupport() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        // define asset
        let assetCode = "USDC"
        var assetIssuerAccountId = "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5"
        if "mainnet" == testMode {
            assetIssuerAccountId = "GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
        }
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
        
        let sponsorKeyPair = accountKeyPair!
                
        // keypairs identifying the new account to be sponsored
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        let newAccountAddress = newAccountPublicKeyPair.address
        
        // fund the new test account
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: newAccountAddress)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: newAccountPublicKeyPair)
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
        // define asset
        let assetCode = "USDC"
        var assetIssuerAccountId = "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5"
        if "mainnet" == testMode {
            assetIssuerAccountId = "GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
        }
        let asset = try IssuedAssetId(
            code: assetCode,
            issuer: assetIssuerAccountId)
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        
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
        
        if "mainnet" == testMode {
            // merge back to save XLM
            try await merge(signer: newAccountSigningKeyPair, destination: accountKeyPair.address)
        }
    }
    
    
    func testAccountMerge() async throws {
        let stellar = wallet.stellar
        
        // create 2 new accounts for testing and fund them
        let sourceAccountKeyPair = stellar.account.createKeyPair()
        let sourceAccountAddress = sourceAccountKeyPair.address
        
        let destinationAccountKeyPair = stellar.account.createKeyPair()
        let destinationAccountAddress = destinationAccountKeyPair.address
        
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: sourceAccountAddress)
            try await stellar.fundTestNetAccount(address: destinationAccountAddress)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: sourceAccountKeyPair)
            try await fundMainnetAccount(source: accountKeyPair, newAccount: destinationAccountKeyPair)
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
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
        if "testnet" == testMode {
            XCTAssertTrue(Double(balances.first!.balance)! > 10.000)
        }
        
        if "mainnet" == testMode {
            // merge back to save XLM
            try await merge(signer: destinationAccountKeyPair, destination: accountKeyPair.address)
        }
    }
    
    
    func testSetTreshold() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        // create a new account for testing and fund it
        let sourceAccountKeyPair = account.createKeyPair()
        let sourceAccountAddress = sourceAccountKeyPair.address
        
        // fund the new test account
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: sourceAccountAddress)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: sourceAccountKeyPair.toPublicKeyPair())
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(
            sourceAddress: sourceAccountKeyPair)
        
        // create transaction
        let tx = try txBuilder.setThreshold(low: 1, medium: 10, high: 1).build()
        
        // sign transaction
        stellar.sign(tx: tx, keyPair: sourceAccountKeyPair)
        
        // submit transaction
        let success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
        
        // validate
        let accountInfo = try await account.getInfo(accountAddress: sourceAccountAddress)
        
        XCTAssertEqual(1, accountInfo.thresholds.lowThreshold)
        XCTAssertEqual(10, accountInfo.thresholds.medThreshold)
        XCTAssertEqual(1, accountInfo.thresholds.highThreshold)
        
        if "mainnet" == testMode {
            // merge back to save XLM
            try await merge(signer: sourceAccountKeyPair, destination: accountKeyPair.address)
        }
    }
    
    func testSponsoredSetTreshold() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let sponsorKeyPair = accountKeyPair!
        
        // keypairs identifying the new account to be used
        let newAccountSigningKeyPair = account.createKeyPair()
        let newAccountPublicKeyPair = newAccountSigningKeyPair.toPublicKeyPair()
        let newAccountAddress = newAccountPublicKeyPair.address
        
        // fund the new test account
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: newAccountAddress)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: newAccountPublicKeyPair)
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
        // create transaction builder
        let txBuilder = try await stellar.transaction(sourceAddress: sponsorKeyPair)
        
        // create transaction
        let tx = try txBuilder.sponsoring(sponsorAccount: sponsorKeyPair,
                                      buildingFunction: { (builder) in builder.setThreshold(low: 1, medium: 10, high: 1)},
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
        XCTAssertEqual(1, accountInfo.thresholds.highThreshold)
        
        if "mainnet" == testMode {
            // merge back to save XLM
            try await merge(signer: newAccountSigningKeyPair, destination: accountKeyPair.address)
        }
    }
    
    func testMakeFeeBump() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let replaceWith = account.createKeyPair()
        
        let sponsorKeyPair = account.createKeyPair()
        let sponsorAddress = sponsorKeyPair.address
        
        let sponsoredKeyPair = account.createKeyPair()
        let sponsoredAddress = sponsoredKeyPair.address
        
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: sponsorAddress)
            try await stellar.fundTestNetAccount(address: sponsoredAddress)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: sponsorKeyPair, startingBalance: 2.0)
            try await fundMainnetAccount(source: accountKeyPair, newAccount: sponsoredKeyPair)
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
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
        if "testnet" == testMode {
            XCTAssertEqual(10000, Double(myAccount.balances.first!.balance))
        }
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
        
        if "mainnet" == testMode {
            // merge back to save XLM
            try await merge(signer: replaceWith, destination: accountKeyPair.address, sourceAddress: sponsoredKeyPair)
            try await merge(signer: sponsorKeyPair, destination: accountKeyPair.address)
        }
    }
    
    func testUseXdrToSendTxData() async throws {
        
        if "mainnet" == testMode {
            return // no serverside signer available for mainnet
        }
        
        let stellar = wallet.stellar
        let account = stellar.account
        
        let sponsorKeyPair = try PublicKeyPair(accountId: "GBUTDNISXHXBMZE5I4U5INJTY376S5EW2AF4SQA2SWBXUXJY3OIZQHMV")
        
        // prevent error in case of testnet reset
        if !(try await account.accountExists(accountAddress: sponsorKeyPair.address)) {
            try await stellar.fundTestNetAccount(address: sponsorKeyPair.address)
        }

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
        let account2KeyPair = account.createKeyPair()
        
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: account1KeyPair.address)
            try await stellar.fundTestNetAccount(address: account2KeyPair.address)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: account1KeyPair, startingBalance: 2.0)
            try await fundMainnetAccount(source: accountKeyPair, newAccount: account2KeyPair, startingBalance: 1.0)
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
        let success =
        try await stellar.submitWithFeeIncrease(sourceAddress: account1KeyPair,
                                              timeout: 30,
                                              baseFeeIncrease: 100,
                                              maxBaseFee: 2000,
                                              buildingFunction: {
                                                    (builder) in try! builder.transfer(destinationAddress: account2KeyPair.address,
                                                                                       assetId: NativeAssetId(),
                                                                                       amount: 0.2)})
        
        XCTAssertTrue(success)
        
        // validate
        let newAccount = try await account.getInfo(accountAddress: account2KeyPair.address)
        let balance = newAccount.balances.first!
        XCTAssertEqual("native", balance.assetType)
        if "testnet" == testMode {
            XCTAssertEqual(10000.2, Double(balance.balance))
        } else if "mainnet" == testMode {
            XCTAssertEqual(1.2, Double(balance.balance))
            // merge back to save XLM
            try await merge(signer: account1KeyPair, destination: accountKeyPair.address)
            try await merge(signer: account2KeyPair, destination: accountKeyPair.address)
        }
    }
    
    func testPathPayments() async throws {
        let stellar = wallet.stellar
        let account = stellar.account
        
        let keyPairA = account.createKeyPair()
        if "testnet" == testMode {
            try await stellar.fundTestNetAccount(address: keyPairA.address)
        } else if "mainnet" == testMode {
            try await fundMainnetAccount(source: accountKeyPair, newAccount: keyPairA, startingBalance: 10.0)
        } else {
            XCTFail("testMode must be testnet or mainnet")
        }
        
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
            .createAccount(newAccount: keyPairB, startingBalance: 2.6)
            .createAccount(newAccount: keyPairC, startingBalance: 1.6)
            .createAccount(newAccount: keyPairD, startingBalance: 2.6)
            .createAccount(newAccount: keyPairE, startingBalance: 1.6)
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
        txBuilder = try await stellar.transaction(sourceAddress: keyPairA)
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
        
        // if "mainnet" == testMode {
            // cleanup to save lumens
            var iomBalance = try await getBalance(accountId: keyPairB.address, asset: iomAsset)
            var ecoBalance = try await getBalance(accountId: keyPairB.address, asset: ecoAsset)
            var offerId:Int64? = nil
            var offersEnum = await stellar.server.offers.getOffers(forAccount: keyPairB.address)
            switch offersEnum {
            case .success(let page):
                offerId = Int64(page.records.first!.id)
            case .failure(_):
                break
            }
            
            let delSellOfferOpB = ManageSellOfferOperation(sourceAccountId: accountBId,
                                                    selling: ecoAsset.toAsset(),
                                                    buying: iomAsset.toAsset(),
                                                    amount: 0,
                                                    price: Price(numerator: 1, denominator: 2),
                                                    offerId: offerId!)
        
            var cTx = try await stellar.transaction(sourceAddress: keyPairB)
                .transfer(destinationAddress: keyPairA.address, assetId: iomAsset, amount: Decimal(string:iomBalance!)!)
                .addOperation(operation: delSellOfferOpB)
                .removeAssetSupport(asset: iomAsset)
                .transfer(destinationAddress: keyPairA.address, assetId: ecoAsset, amount: Decimal(string:ecoBalance!)!)
                .removeAssetSupport(asset: ecoAsset)
                .accountMerge(destinationAddress: accountKeyPair.address).build()
            stellar.sign(tx: cTx, keyPair: keyPairB)
            let _ = try await stellar.submitTransaction(signedTransaction: cTx)
            
            iomBalance = try await getBalance(accountId: keyPairC.address, asset: iomAsset)
            cTx = try await stellar.transaction(sourceAddress: keyPairC)
                .transfer(destinationAddress: keyPairA.address, assetId: iomAsset, amount: Decimal(string:iomBalance!)!)
                .removeAssetSupport(asset: iomAsset)
                .accountMerge(destinationAddress: accountKeyPair.address).build()
            stellar.sign(tx: cTx, keyPair: keyPairC)
            let _ = try await stellar.submitTransaction(signedTransaction: cTx)
            
            ecoBalance = try await getBalance(accountId: keyPairD.address, asset: ecoAsset)
            var moonBalance = try await getBalance(accountId: keyPairD.address, asset: moonAsset)
        
            offersEnum = await stellar.server.offers.getOffers(forAccount: keyPairD.address)
            switch offersEnum {
            case .success(let page):
                offerId = Int64(page.records.first!.id)
            case .failure(_):
                break
            }
        
            let delSellOfferOpD = ManageSellOfferOperation(sourceAccountId: accountDId,
                                                        selling: moonAsset.toAsset(),
                                                        buying: ecoAsset.toAsset(),
                                                        amount: 0,
                                                        price: Price(numerator: 1, denominator: 2),
                                                        offerId: offerId!)
            cTx = try await stellar.transaction(sourceAddress: keyPairD)
                .addOperation(operation: delSellOfferOpD)
                .transfer(destinationAddress: keyPairA.address, assetId: ecoAsset, amount: Decimal(string:ecoBalance!)!)
                .transfer(destinationAddress: keyPairA.address, assetId: moonAsset, amount: Decimal(string:moonBalance!)!)
                .removeAssetSupport(asset: ecoAsset)
                .removeAssetSupport(asset: moonAsset)
                .accountMerge(destinationAddress: accountKeyPair.address).build()
            stellar.sign(tx: cTx, keyPair: keyPairD)
            let _ = try await stellar.submitTransaction(signedTransaction: cTx)
            
            moonBalance = try await getBalance(accountId: keyPairE.address, asset: moonAsset)
            cTx = try await stellar.transaction(sourceAddress: keyPairE)
                .transfer(destinationAddress: keyPairA.address, assetId: moonAsset, amount: Decimal(string:moonBalance!)!)
                .removeAssetSupport(asset: moonAsset)
                .accountMerge(destinationAddress: accountKeyPair.address).build()
            stellar.sign(tx: cTx, keyPair: keyPairE)
            let _ = try await stellar.submitTransaction(signedTransaction: cTx)
        
            try await merge(signer: keyPairA, destination: accountKeyPair.address)
        //}
    }
        
    func fundMainnetAccount(source:SigningKeyPair, newAccount:AccountKeyPair, startingBalance:Decimal? = nil) async throws {
        let stellar = wallet.stellar
        let txBuilder = try await stellar.transaction(sourceAddress: source)
        let tx = try txBuilder.createAccount(newAccount: newAccount, startingBalance: startingBalance ?? 1.01).build()
        stellar.sign(tx: tx, keyPair: source)
        let success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
    }
    
    func merge(signer:SigningKeyPair, destination:String, sourceAddress:AccountKeyPair? = nil ) async throws {
        let stellar = wallet.stellar
        let txBuilder = try await stellar.transaction(sourceAddress: sourceAddress ?? signer)
        let tx = try txBuilder.accountMerge(destinationAddress: destination).build()
        stellar.sign(tx: tx, keyPair: signer)
        let success = try await stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(success)
    }
    
    func getBalance(accountId:String, asset:IssuedAssetId) async throws -> String? {
        let account = wallet.stellar.account
        let info = try await account.getInfo(accountAddress: accountId)
        var balance:String? = nil
        info.balances.forEach{  item in
            if let issuer = item.assetIssuer, let assetCode = item.assetCode,
               "\(assetCode):\(issuer)" == asset.id {
                balance = item.balance
            }
        }
        return balance
    }
        
}
