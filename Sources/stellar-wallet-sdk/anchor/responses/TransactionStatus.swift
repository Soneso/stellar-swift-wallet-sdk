//
//  TransactionStatus.swift
//
//
//  Created by Christian Rogobete on 09.01.25.
//

import Foundation

public enum TransactionStatus:String {
    case incomplete = "incomplete"
    case pendingUserTransferStart = "pending_user_transfer_start"
    case pendingUserTransferComplete = "pending_user_transfer_complete"
    case pendingExternal = "pending_external"
    case pendingAnchor = "pending_anchor"
    case pendingStellar = "pending_stellar"
    case pendingTrust = "pending_trust"
    case pendingUser = "pending_user"
    case completed = "completed"
    case refunded = "refunded"
    case expired = "expired"
    case noMarket = "no_market"
    case tooSmall = "too_small"
    case tooLarge = "too_large"
    case error = "error"
    
    public func isError() -> Bool {
        return self == .error || self == .noMarket || self == .tooLarge || self == .tooSmall
    }
    
    public func isTerminal() -> Bool {
        return self == .completed || self == .refunded || self == .expired || isError()
    }
}
