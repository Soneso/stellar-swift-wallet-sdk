//
//  StatusUpdateEvent.swift
//
//
//  Created by Christian Rogobete on 13.01.25.
//

import Foundation

public protocol StatusUpdateEvent {}

public class StatusChange:StatusUpdateEvent {
    
    public let transaction:AnchorTransaction
    public let status:TransactionStatus
    public let oldStatus:TransactionStatus?
    
    internal init(transaction: AnchorTransaction, status: TransactionStatus, oldStatus: TransactionStatus? = nil) {
        self.transaction = transaction
        self.status = status
        self.oldStatus = oldStatus
    }
    
    public func isTerminal() -> Bool {
        return status.isTerminal()
    }
    
    public func isError() -> Bool {
        return status.isError()
    }
}

public class ExceptionHandlerExit:StatusUpdateEvent {}
public class NotificationsClosed:StatusUpdateEvent {}

