//
//  Sep6Transaction.swift
//
//
//  Created by Christian Rogobete on 19.03.25.
//

import Foundation
import stellarsdk

public class Sep6Transaction:AnchorTransaction {

    /// deposit, deposit-exchange, withdrawal or withdrawal-exchange.
    public var kind:String;
    
    /// (optional) Amount received by anchor at start of transaction as a
     /// string with up to 7 decimals. Excludes any fees charged before the
     /// anchor received the funds. Should be equals to quote.sell_asset if
     /// a quote_id was used.
    public var statusEta:Int?
    
    /// (optional) Amount received by anchor at start of transaction as a
    /// string with up to 7 decimals. Excludes any fees charged before the
    /// anchor received the funds. Should be equals to quote.sell_asset if
    /// a quote_id was used.
    public var amountIn:String?
    
    /// optional) The asset received or to be received by the Anchor.
    /// Must be present if the deposit/withdraw was made using quotes.
    /// The value must be in SEP-38 Asset Identification Format.
    public var amountInAsset:String?
    
    /// (optional) Amount sent by anchor to user at end of transaction as
    /// a string with up to 7 decimals. Excludes amount converted to XLM to
    /// fund account and any external fees. Should be equals to quote.buy_asset
    /// if a quote_id was used.
    public var amountOut:String?
    
    /// (optional) The asset delivered or to be delivered to the user.
    /// Must be present if the deposit/withdraw was made using quotes.
    /// The value must be in SEP-38 Asset Identification Format.
    public var amountOutAsset:String?
    
    /// (deprecated, optional) Amount of fee charged by anchor.
    /// Should be equals to quote.fee.total if a quote_id was used.
    public var amountFee:String?
    
    /// (deprecated, optional) The asset in which fees are calculated in.
    /// Must be present if the deposit/withdraw was made using quotes.
    /// The value must be in SEP-38 Asset Identification Format.
    /// Should be equals to quote.fee.asset if a quote_id was used.
    public var amountFeeAsset:String?
    
    /// Description of fee charged by the anchor.
    /// If quote_id is present, it should match the referenced quote's fee object.
    public var chargedFeeInfo:Sep6ChargedFee?
    
    /// (optional) The ID of the quote used to create this transaction.
    /// Should be present if a quote_id was included in the POST /transactions
    /// request. Clients should be aware though that the quote_id may not be
    /// present in older implementations.
    public var quoteId:String?
    
    /// (optional) Sent from address (perhaps BTC, IBAN, or bank account in
    /// the case of a deposit, Stellar address in the case of a withdrawal).
    public var from:String?
    
    /// (optional) Sent to address (perhaps BTC, IBAN, or bank account in
    /// the case of a withdrawal, Stellar address in the case of a deposit).
    public var to:String?
    
    /// (optional) Extra information for the external account involved.
    /// It could be a bank routing number, BIC, or store number for example.
    public var externalExtra: String?
    
    /// (optional) Text version of external_extra.
    /// This is the name of the bank or store
    public var externalExtraText:String?
    
    /// (optional) If this is a deposit, this is the memo (if any)
    /// used to transfer the asset to the to Stellar address
    public var depositMemo:String?
    
    /// (optional) Type for the depositMemo.
    public var depositMemoType:String?
    
    /// (optional) If this is a withdrawal, this is the anchor's Stellar account
    /// that the user transferred (or will transfer) their issued asset to.
    public var withdrawAnchorAccount:String?
    
    /// (optional) Memo used when the user transferred to withdrawAnchorAccount.
    public var withdrawMemo:String?
    
    /// (optional) Memo type for withdrawMemo.
    public var withdrawMemoType:String?
    
    /// (optional) start date and time of the transaction
    public var startedAt:Date?
    
    /// (optional) The date and time of transaction reaching the current status.
    public var updatedAt:Date?
    
    /// (optional) Completion date and time of transaction
    public var completedAt:Date?
    
    /// (optional) The date and time by when the user action is required.
    /// In certain statuses, such as pending_user_transfer_start or incomplete,
    /// anchor waits for the user action and user_action_required_by field should
    /// be used to show the time anchors gives for the user to make an action
    /// before transaction will automatically be moved into a different status
    /// (such as expired or to be refunded). user_action_required_by should
    /// only be specified for statuses where user action is required,
    /// and omitted for all other. Anchor should specify the action waited on
    /// using message or more_info_url.
    public var userActionRequiredBy:Date?
    
    /// (optional) transaction_id on Stellar network of the transfer that either
    /// completed the deposit or started the withdrawal.
    public var stellarTransactionId:String?
    
    /// (optional) ID of transaction on external network that either started
    /// the deposit or completed the withdrawal.
    public var externalTransactionId:String?
    
    /// (deprecated, optional) This field is deprecated in favor of the refunds
    /// object. True if the transaction was refunded in full. False if the
    /// transaction was partially refunded or not refunded. For more details
    /// about any refunds, see the refunds object.
    public var refunded:Bool?
    
    /// (optional) An object describing any on or off-chain refund associated
    /// with this transaction.
    public var refunds:Sep6Refunds?
    
    /// (optional) A human-readable message indicating any errors that require
    /// updated information from the user.
    public var requiredInfoMessage:String?
    
    /// (optional) A set of fields that require update from the user described in
    /// the same format as /info. This field is only relevant when status is
    /// pending_transaction_info_update.
    public var requiredInfoUpdates:[String:Sep6FieldInfo]?
    
    /// (optional) JSON object containing the SEP-9 financial account fields that
    /// describe how to complete the off-chain deposit in the same format as
    /// the /deposit response. This field should be present if the instructions
    /// were provided in the /deposit response or if it could not have been
    /// previously provided synchronously. This field should only be present
    /// once the status becomes pending_user_transfer_start, not while the
    /// transaction has any statuses that precede it such as incomplete,
    /// pending_anchor, or pending_customer_info_update.
    public var instructions:[String:Sep6DepositInstruction]?
    
    /// (optional) ID of the Claimable Balance used to send the asset initially
    /// requested. Only relevant for deposit transactions.
    public var claimableBalanceId:String?
    
    /// (optional) A URL the user can visit if they want more information
    /// about their account / status.
    public var moreInfoUrl:String?
    
    internal init(id: String, status:TransactionStatus, kind: String, statusEta: Int? = nil, amountIn: String? = nil, amountInAsset: String? = nil, amountOut: String? = nil, amountOutAsset: String? = nil, amountFee: String? = nil, amountFeeAsset: String? = nil, chargedFeeInfo: Sep6ChargedFee? = nil, quoteId: String? = nil, from: String? = nil, to: String? = nil, externalExtra: String? = nil, externalExtraText: String? = nil, depositMemo: String? = nil, depositMemoType: String? = nil, withdrawAnchorAccount: String? = nil, withdrawMemo: String? = nil, withdrawMemoType: String? = nil, startedAt: Date? = nil, updatedAt: Date? = nil, completedAt: Date? = nil, userActionRequiredBy: Date? = nil, stellarTransactionId: String? = nil, externalTransactionId: String? = nil, refunded: Bool? = nil, refunds: Sep6Refunds? = nil, requiredInfoMessage: String? = nil, requiredInfoUpdates: [String : Sep6FieldInfo]? = nil, instructions: [String : Sep6DepositInstruction]? = nil, claimableBalanceId: String? = nil, moreInfoUrl: String? = nil) {
        self.kind = kind
        self.statusEta = statusEta
        self.amountIn = amountIn
        self.amountInAsset = amountInAsset
        self.amountOut = amountOut
        self.amountOutAsset = amountOutAsset
        self.amountFee = amountFee
        self.amountFeeAsset = amountFeeAsset
        self.chargedFeeInfo = chargedFeeInfo
        self.quoteId = quoteId
        self.from = from
        self.to = to
        self.externalExtra = externalExtra
        self.externalExtraText = externalExtraText
        self.depositMemo = depositMemo
        self.depositMemoType = depositMemoType
        self.withdrawAnchorAccount = withdrawAnchorAccount
        self.withdrawMemo = withdrawMemo
        self.withdrawMemoType = withdrawMemoType
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.userActionRequiredBy = userActionRequiredBy
        self.stellarTransactionId = stellarTransactionId
        self.externalTransactionId = externalTransactionId
        self.refunded = refunded
        self.refunds = refunds
        self.requiredInfoMessage = requiredInfoMessage
        self.requiredInfoUpdates = requiredInfoUpdates
        self.instructions = instructions
        self.claimableBalanceId = claimableBalanceId
        self.moreInfoUrl = moreInfoUrl
        super.init(id: id, transactionStatus: status)
    }
    
    internal convenience init(tx:stellarsdk.AnchorTransaction) throws {
        
        var requiredInfoUpdates:[String : Sep6FieldInfo]? = nil
        if let fields = tx.requiredInfoUpdates?.fields {
            requiredInfoUpdates = [:]
            for (key, val) in fields {
                requiredInfoUpdates![key] = Sep6FieldInfo(anchorField: val)
            }
        }
        
        var instructions:[String : Sep6DepositInstruction]? = nil
        if let txInstructions = tx.instructions {
            instructions = [:]
            for (key, val) in txInstructions {
                instructions![key] = Sep6DepositInstruction(instruction: val)
            }
        }
        
        guard let txStatus = TransactionStatus(rawValue: tx.status.rawValue) else {
            throw AnchorError.invalidAnchorResponse(message: "Invalid tx status: \(tx.status) received from anchor.")
        }
        
        self.init(id: tx.id,
                  status: txStatus,
                  kind: tx.kind.rawValue,
                  statusEta: tx.statusEta,
                  amountIn: tx.amountIn,
                  amountInAsset: tx.amountInAsset,
                  amountOut: tx.amountOut,
                  amountOutAsset: tx.amountOutAsset,
                  amountFee: tx.amountFee,
                  amountFeeAsset: tx.amountFeeAsset,
                  chargedFeeInfo: tx.feeDetails != nil ? Sep6ChargedFee(feeDetails: tx.feeDetails!) : nil,
                  quoteId: tx.quoteId,
                  from: tx.from,
                  to:tx.to,
                  externalExtra: tx.externalExtra,
                  externalExtraText: tx.externalExtraText,
                  depositMemo: tx.depositMemo,
                  depositMemoType: tx.depositMemoType,
                  withdrawAnchorAccount: tx.withdrawAnchorAccount,
                  withdrawMemo: tx.withdrawMemo,
                  withdrawMemoType: tx.withdrawMemoType,
                  startedAt: tx.startedAt,
                  updatedAt: tx.updatedAt,
                  completedAt: tx.completedAt,
                  userActionRequiredBy: tx.userActionRequiredBy,
                  stellarTransactionId: tx.stellarTransactionId,
                  externalTransactionId: tx.externalTransactionId,
                  refunded: tx.refunded,
                  refunds: tx.refunds != nil ? Sep6Refunds(refunds: tx.refunds!) : nil,
                  requiredInfoMessage: tx.requiredInfoMessage,
                  requiredInfoUpdates: requiredInfoUpdates,
                  instructions: instructions,
                  claimableBalanceId: tx.claimableBalanceId,
                  moreInfoUrl: tx.moreInfoUrl
            )
    }
    
}

public class Sep6ChargedFee {

    /// The total amount of fee applied.
    public var total:String
    
    /// The asset in which the fee is applied, represented through the
    /// Asset Identification Format.
    public var asset:String
    
    /// (optional) An array of objects detailing the fees that were used to
    /// calculate the conversion price. This can be used to datail the price
    /// components for the end-user.
    public var details:[Sep6ChargedFeeDetail]?
    
    internal init(total: String, asset: String, details: [Sep6ChargedFeeDetail]? = nil) {
        self.total = total
        self.asset = asset
        self.details = details
    }
    
    internal convenience init(feeDetails:FeeDetails) {
        var details:[Sep6ChargedFeeDetail]? = nil
        if let dDetails = feeDetails.details {
            details = []
            for detail in dDetails {
                details!.append(Sep6ChargedFeeDetail(feeDetailsDetails: detail))
            }
        }
        self.init(total: feeDetails.total, asset: feeDetails.asset, details: details)
    }
}

public class Sep6ChargedFeeDetail {
    
    /// The name of the fee, for example ACH fee, Brazilian conciliation fee,
    /// Service fee, etc.
    public var name:String
    
    /// The amount of asset applied. If fee_details.details is provided,
    /// sum(fee_details.details.amount) should be equals fee_details.total.
    public var amount:String
    
    /// (optional) A text describing the fee.
    public var description:String?
    
    internal init(name: String, amount: String, description: String? = nil) {
        self.name = name
        self.amount = amount
        self.description = description
    }
    
    convenience internal init(feeDetailsDetails: FeeDetailsDetails) {
        self.init(name: feeDetailsDetails.name, amount: feeDetailsDetails.amount, description: feeDetailsDetails.description)
    }
}

public class Sep6Refunds {

    public var amountFee:String
    public var amountRefunded:String
    public var payments:[Sep6Payment]?
    
    internal init(amountFee: String, amountRefunded: String, payments: [Sep6Payment]? = nil) {
        self.amountFee = amountFee
        self.amountRefunded = amountRefunded
        self.payments = payments
    }
    
    
    internal convenience init(refunds:stellarsdk.Refunds) {        
        var payments:[Sep6Payment]? = nil
        if let dPayments = refunds.payments {
            payments = []
            for payment in dPayments {
                payments!.append(Sep6Payment(refundPayment: payment))
            }
        }
        
        self.init(amountFee: refunds.amountFee, amountRefunded: refunds.amountRefunded, payments: payments)
    }
}

public class Sep6Payment {

    public var amount:String
    public var fee:String
    public var id:String
    public var idType:String

    internal init(amount: String, fee: String, id: String, idType: String) {
        self.amount = amount
        self.fee = fee
        self.id = id
        self.idType = idType
    }
    
    convenience internal init(refundPayment: RefundPayment) {
        self.init(amount: refundPayment.amount, fee: refundPayment.fee, id: refundPayment.id, idType: refundPayment.idType)
    }
}
