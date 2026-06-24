//
//  MVPDemoTest.swift
//  
//
//  Created by Christian Rogobete on 14.01.25.
//

import XCTest
import os
@testable import stellar_wallet_sdk

@available(iOS 14.0, *)
final class MVPDemoTest: XCTestCase {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "stellar-wallet-sdk-tests", category: "MVP Test")
    var depositSuccess = false
    
    func testMVPDemo() async throws {

        // new testnet wallet
        let wallet = Wallet.testNet
        
        // get the account service
        let accountService = wallet.stellar.account
        
        // create a new stellar account key pair
        let userAccountKeyPair = accountService.createKeyPair()
      
        // get the account address
        let userAccountAddress = userAccountKeyPair.address
        logger.debug("user account address: \(userAccountAddress)")
              
        // the account should not yet exist on the test net
        var accountExists = try await accountService.accountExists(accountAddress: userAccountAddress)
        XCTAssertFalse(accountExists)
        
        // fund the account on the stellar network using freindbot
        // first get the stellar network service
        let stellarService = wallet.stellar
    
        try await stellarService.fundTestNetAccount(address: userAccountAddress)
        
        // the account should exist now on the stellar network
        accountExists = try await accountService.accountExists(accountAddress: userAccountAddress)
        XCTAssertTrue(accountExists)
        
        // interact with the stellar test anchor
        let anchorService = wallet.anchor(homeDomain: "testanchor.stellar.org")
        
        // get the anchors info (SEP-1)
        let anchorInfo = try await anchorService.info
        
        // check the currencies provided
        guard let currencies = anchorInfo.currencies else {
            XCTFail("testanchor provied no currencies")
            return
        }
        
        for currency in currencies {
            let id = try currency.assetId.id
            logger.debug("Currency: \(id)")
        }
        
        // authenticate the user with the anchor
        let authService = try await anchorService.sep10
        
        let authToken = try await authService.authenticate(userKeyPair: userAccountKeyPair)
        logger.debug("SEP-10 JWT token: \(authToken.jwt)")
        
        // get deposit and withdrwal info
        // first get the interactive flow service (SEP-24)
        let interactiveService = anchorService.sep24
        
        let info = try await interactiveService.info
        
        // check deposit info:
        let depositInfo = info.deposit
        for (asset, info) in depositInfo {
            logger.debug("SEP-24 Asset: \(asset) enabled: \(info.enabled)")
        }
        
        // get SRT (Stellar Reference Token) info
        guard let srtCurrencyInfo = currencies.first(where: {$0.code == "SRT"}) else {
            XCTFail("SRT not found")
            return
        }
        
        // create SRT (issued) asset object
        guard let srtAsset = try srtCurrencyInfo.assetId as? IssuedAssetId else {
            XCTFail("SRT is not an issued asset")
            return
        }
        
        // trust asset
        let trustTx = try await stellarService.transaction(sourceAddress:userAccountKeyPair)
           .addAssetSupport(asset: srtAsset, limit: 10000)
           .build()
        
        // sign transaction
        stellarService.sign(tx: trustTx, keyPair: userAccountKeyPair)
        
        // submit transaction
        let success = try await stellarService.submitTransaction(signedTransaction: trustTx)
        XCTAssertTrue(success)
        
        // check if trustline exists
        var accountInfo = try await accountService.getInfo(accountAddress: userAccountAddress)
        guard let srtBalanceInfo = accountInfo.balances.first(where: {$0.assetCode == "SRT"}) else {
            XCTFail("SRT Trustline not found")
            return
        }
        logger.debug("SRT balance:\(srtBalanceInfo.balance)")
        
        // initiate a deposit
        let depositResponse = try await interactiveService.deposit(assetId: srtAsset, authToken: authToken)
        logger.debug("Transaction ID: \(depositResponse.id)")
        
        // To finish the transaction we need to complete the process in the browser for following url:
        logger.debug("Interactive URL (please open in the browser): \(depositResponse.url)")
        
        // watch transaction
        let watcher = interactiveService.watcher()
        
        let result = watcher.watchOneTransaction(authToken: authToken,
                                                 id: depositResponse.id)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleEvent(_:)),
                                               name: result.notificationName,
                                               object: nil)
        
        // wait max. 5 minutes in this test until the deposit completes via interactive url + anchor
        var counter = 0
        repeat {
            try! await Task.sleep(nanoseconds: UInt64(5 * Double(NSEC_PER_SEC)))
            counter += 1
        } while !depositSuccess && counter < 60
        
        XCTAssertTrue(depositSuccess)
        
        // check balance
        accountInfo = try await accountService.getInfo(accountAddress: userAccountAddress)
        guard let srtBalanceInfo = accountInfo.balances.first(where: {$0.assetCode == "SRT"}) else {
            XCTFail("SRT Balance not found")
            return
        }
        logger.debug("SRT balance:\(srtBalanceInfo.balance)")
    }
    
    @objc public func handleEvent(_ notification: Notification) {
        if let statusChange = notification.object as? StatusChange {
            let oldStatus:TransactionStatus? = statusChange.oldStatus
            logger.debug("status change event received, tx.id:\(statusChange.transaction.id), new_status:\(statusChange.status.rawValue), old_status:\(oldStatus == nil ? "nil" : oldStatus!.rawValue)")
            if statusChange.status.isTerminal() {
                depositSuccess = true
            }
        } else if let _ = notification.object as? ExceptionHandlerExit {
            logger.debug("exception exit event received")
            depositSuccess = false
        } else if let _ = notification.object as? NotificationsClosed {
            logger.debug("notifications closed event received")
        }
    }
}
