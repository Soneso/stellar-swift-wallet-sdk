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
    
    public static func fromString(statusString:String) -> TransactionStatus? {
        if (statusString == TransactionStatus.incomplete.rawValue) {
            return .incomplete
        }
        if (statusString == TransactionStatus.pendingUserTransferStart.rawValue) {
            return .pendingUserTransferStart
        }
        if (statusString == TransactionStatus.pendingUserTransferComplete.rawValue) {
            return .pendingUserTransferComplete
        }
        if (statusString == TransactionStatus.pendingUserTransferComplete.rawValue) {
            return .pendingUserTransferComplete
        }
        if (statusString == TransactionStatus.pendingExternal.rawValue) {
            return .pendingExternal
        }
        if (statusString == TransactionStatus.pendingAnchor.rawValue) {
            return .pendingAnchor
        }
        if (statusString == TransactionStatus.pendingStellar.rawValue) {
            return .pendingStellar
        }
        if (statusString == TransactionStatus.pendingTrust.rawValue) {
            return .pendingTrust
        }
        if (statusString == TransactionStatus.pendingUser.rawValue) {
            return .pendingUser
        }
        if (statusString == TransactionStatus.completed.rawValue) {
            return .completed
        }
        if (statusString == TransactionStatus.refunded.rawValue) {
            return .refunded
        }
        if (statusString == TransactionStatus.expired.rawValue) {
            return .expired
        }
        if (statusString == TransactionStatus.noMarket.rawValue) {
            return .noMarket
        }
        if (statusString == TransactionStatus.tooSmall.rawValue) {
            return .tooSmall
        }
        if (statusString == TransactionStatus.tooLarge.rawValue) {
            return .tooLarge
        }
        if (statusString == TransactionStatus.error.rawValue) {
            return .error
        }
        return nil
    }
}
