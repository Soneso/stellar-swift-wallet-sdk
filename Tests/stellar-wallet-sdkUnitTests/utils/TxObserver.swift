//
//  TxObserver.swift
//  
//
//  Created by Christian Rogobete on 19.03.25.
//

import Foundation
@testable import stellar_wallet_sdk

class TxObserver {
    public var successCount = 0
    @objc public func handleEvent(_ notification: Notification) {
        if let statusChange = notification.object as? StatusChange {
            let oldStatus:TransactionStatus? = statusChange.oldStatus
            print("status change event received, tx.id:\(statusChange.transaction.id), new_status:\(statusChange.status.rawValue), old_status:\(oldStatus == nil ? "nil" : oldStatus!.rawValue)")
            if statusChange.status.isTerminal() {
                successCount += 1
            }
        } else if let _ = notification.object as? ExceptionHandlerExit {
            print("exception exit event received")
            successCount = 0
        } else if let _ = notification.object as? NotificationsClosed {
            print("notifications closed event received")
        }
    }
}
