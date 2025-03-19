//
//  Watcher.swift
//
//
//  Created by Christian Rogobete on 13.01.25.
//

import Foundation

public enum WatcherKind {
    case sep24
    case sep6
}

/// Used for watching transaction from an Anchor as part of sep-24 or sep-6.
public class Watcher {

    public let anchor:Anchor
    public let pollDelay:Double
    public let exceptionHandler:WalletExceptionHandler
    private var oneTxProps:[String:OneTxWatchProps] = [:]
    private var multiTxProps:[String:MultipleTxWatchProps] = [:]
    private let watcherKind:WatcherKind
    
    internal init(anchor: Anchor, pollDelay: Double, exceptionHandler: any WalletExceptionHandler, watcherKind:WatcherKind) {
        self.anchor = anchor
        self.pollDelay = pollDelay
        self.exceptionHandler = exceptionHandler
        self.watcherKind = watcherKind
    }
    
    /// Watch a transaction until it stops pending.
    ///
    /// - Parameters:
    ///   - authToken: Authentication token for the requests.
    ///   - id: The id of the transaction to watch.
    ///
    /// - Returns and object holding the notification name to be able to register observers
    ///
    public func watchOneTransaction(authToken:AuthToken, id:String) -> WatcherResult {

        let notificationName = Notification.Name("tx_\(id)")
        let timer = Timer(timeInterval: pollDelay, repeats: true) { timer in
            guard let txProps = self.oneTxProps[id] else {
                timer.invalidate()
                return
            }
            Task {
                var shouldExit = false
                
                do {
                    let transaction:AnchorTransaction = self.watcherKind == WatcherKind.sep24 ?
                    try await self.anchor.sep24.getTransactionBy(authToken: authToken, transactionId: id) :
                    try await self.anchor.sep6.getTransactionBy(authToken: authToken, transactionId: id)
                    
                    let statusChange = StatusChange(transaction: transaction, status: transaction.transactionStatus, oldStatus: txProps.oldStatus)
                    if (statusChange.status != statusChange.oldStatus) {
                        NotificationCenter.default.post(name: notificationName, object: statusChange)
                    }
                    
                    txProps.oldStatus = transaction.transactionStatus
                    if statusChange.isTerminal() {
                        shouldExit = true
                    }
                    
                    txProps.retryContext.refresh()
                    
                } catch let error {
                    txProps.retryContext.onError(e: error)
                    shouldExit = await self.exceptionHandler.invoke(ctx: txProps.retryContext)
                    if shouldExit {
                        NotificationCenter.default.post(name: notificationName, object: ExceptionHandlerExit())
                    }
                }
                if shouldExit {
                    txProps.timer.invalidate()
                    self.oneTxProps.removeValue(forKey: id)
                    NotificationCenter.default.post(name: notificationName, object: NotificationsClosed())
                }
            }
        }

        self.oneTxProps[id] = OneTxWatchProps(timer: timer, retryContext: RetryContext())
        RunLoop.main.add(timer, forMode: .common)
        return WatcherResult(notificationName: notificationName, timer: timer)
    }
    
    
    /// Watch all transactions returned from a transfer server for a given asset
    ///
    /// - Parameters:
    ///   - authToken: Authentication token for the requests.
    ///   - asset: The asset to filter transactions by.
    ///   - since: A date and time specifying that transactions older than this value should not be included.
    ///   - kind: The kind of transaction to filter by.
    ///
    /// - Returns and object holding the notification name to be able to register observers
    /// 
    public func watchAsset(authToken:AuthToken, asset:StellarAssetId, since:Date? = nil, kind:TransactionKind? = nil) -> WatcherResult {
        let notificationName = Notification.Name("txs_\(asset.id)")
        
        let timer = Timer(timeInterval: pollDelay, repeats: true) { timer in
            guard let txProps = self.multiTxProps[asset.id] else {
                timer.invalidate()
                return
            }
            Task {
                var shouldExit = false
                do {
                    let txList:[AnchorTransaction] = self.watcherKind == WatcherKind.sep24 ?
                    try await self.anchor.sep24.getTransactionsForAsset(authToken: authToken, asset: asset, noOlderThen: since, kind: kind):
                    try await self.anchor.sep6.getTransactionsForAsset(authToken: authToken,assetCode: ((asset is IssuedAssetId) ? (asset as! IssuedAssetId).code : asset.id),noOlderThan: since,kind: kind)
                    
                    var hasUnfinishedTransactions = false
                    for transaction in txList {
                        let statusChange = StatusChange(transaction: transaction, status: transaction.transactionStatus, oldStatus: txProps.oldStatus[transaction.id])
                        if (statusChange.status != statusChange.oldStatus) {
                            NotificationCenter.default.post(name: notificationName, object: statusChange)
                        }
                        txProps.oldStatus[transaction.id] = transaction.transactionStatus
                        if !statusChange.isTerminal() {
                            hasUnfinishedTransactions = true
                        }
                    }
                    shouldExit = !hasUnfinishedTransactions
                    txProps.retryContext.refresh()
                } catch let error {
                    txProps.retryContext.onError(e: error)
                    shouldExit = await self.exceptionHandler.invoke(ctx: txProps.retryContext)
                    if shouldExit {
                        NotificationCenter.default.post(name: notificationName, object: ExceptionHandlerExit())
                    }
                }
                if shouldExit {
                    txProps.timer.invalidate()
                    self.multiTxProps.removeValue(forKey: asset.id)
                    NotificationCenter.default.post(name: notificationName, object: NotificationsClosed())
                }
            }
        }
        self.multiTxProps[asset.id] = MultipleTxWatchProps(timer: timer, retryContext: RetryContext())
        RunLoop.main.add(timer, forMode: .common)
        return WatcherResult(notificationName: notificationName, timer: timer)
    }
}

public class WatcherResult {
    public let notificationName:Notification.Name
    public let timer:Timer
    
    internal init(notificationName:Notification.Name, timer: Timer) {
        self.notificationName = notificationName
        self.timer = timer
    }
    
    public func stop() {
        if (timer.isValid) {
            timer.invalidate()
        }
    }
}

private class OneTxWatchProps {
    
    var timer:Timer
    var oldStatus:TransactionStatus?
    var retryContext:RetryContext

    internal init(timer: Timer, retryContext: RetryContext, oldStatus: TransactionStatus? = nil) {
        self.timer = timer
        self.oldStatus = oldStatus
        self.retryContext = retryContext
    }
}

private class MultipleTxWatchProps {
    
    var timer:Timer
    var oldStatus:[String:TransactionStatus]
    var retryContext:RetryContext

    internal init(timer: Timer, retryContext: RetryContext, oldStatus: [String:TransactionStatus] = [:]) {
        self.timer = timer
        self.oldStatus = oldStatus
        self.retryContext = retryContext
    }
}
