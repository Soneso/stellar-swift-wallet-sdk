//
//  TransactionStatus.swift
//
//
//  Created by Christian Rogobete on 09.01.25.
//

import Foundation

public enum TransactionStatus:String {
    /// There is not yet enough information for this transaction to be initiated. Perhaps the user has
    /// not yet entered necessary info in an interactive flow
    case incomplete = "incomplete"
    /// The user has not yet initiated their transfer to the anchor. This is the next necessary step in
    /// any deposit or withdrawal flow after transitioning from `incomplete`
    case pendingUserTransferStart = "pending_user_transfer_start"
    /// The Stellar payment has been successfully received by the anchor and the off-chain funds are
    /// available for the customer to pick up. Only used for withdrawal transactions.
    case pendingUserTransferComplete = "pending_user_transfer_complete"
    /// Pending External deposit/withdrawal has been submitted to external network, but is not yet
    /// confirmed. This is the status when waiting on Bitcoin or other external crypto network to
    /// complete a transaction, or when waiting on a bank transfer.
    case pendingExternal = "pending_external"
    /// Deposit/withdrawal is being processed internally by anchor. This can also be used when the
    /// anchor must verify KYC information prior to deposit/withdrawal.
    case pendingAnchor = "pending_anchor"
    /// Deposit/withdrawal operation has been submitted to Stellar network, but is not yet confirmed.
    case pendingStellar = "pending_stellar"
    /// The user must add a trustline for the asset for the deposit to complete.
    case pendingTrust = "pending_trust"
    /// The user must take additional action before the deposit / withdrawal can complete, for example
    /// an email or 2fa confirmation of a withdrawal.
    case pendingUser = "pending_user"
    /// Deposit/withdrawal fully completed
    case completed = "completed"
    /// The deposit/withdrawal is fully refunded
    case refunded = "refunded"
    /// Funds were never received by the anchor and the transaction is considered abandoned by the
    /// user. Anchors are responsible for determining when transactions are considered expired.
    case expired = "expired"
    /// Could not complete deposit because no satisfactory asset/XLM market was available
    /// to create the account
    case noMarket = "no_market"
    /// Deposit/withdrawal size less than min_amount.
    case tooSmall = "too_small"
    /// Deposit/withdrawal size exceeded max_amount.
    case tooLarge = "too_large"
    /// Catch-all for any error not enumerated above.
    case error = "error"
    /// Sep6 only: Certain pieces of information need to be updated by the user.
    case pendingCustomerInfoUpdate = "pending_customer_info_update"
    /// Sep6 only: Certain pieces of information need to be updated by the user.
    case pendingTransactionInfoUpdate = "pending_transaction_info_update"
    
    public func isError() -> Bool {
        return self == .error || self == .noMarket || self == .tooLarge || self == .tooSmall
    }
    
    public func isTerminal() -> Bool {
        return self == .completed || self == .refunded || self == .expired || isError()
    }
}
