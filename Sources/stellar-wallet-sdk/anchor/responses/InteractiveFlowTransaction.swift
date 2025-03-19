//
//  InteractiveFlowTransaction.swift
//
//
//  Created by Christian Rogobete on 09.01.25.
//

import Foundation
import stellarsdk

public class InteractiveFlowTransaction: AnchorTransaction {
    public let startedAt:Date
    public let moreInfoUrl:String?
    
    internal init(id:String,
                  status:TransactionStatus,
                  startedAt:Date,
                  moreInfoUrl:String?,
                  message:String? = nil) {
        self.startedAt = startedAt
        self.moreInfoUrl = moreInfoUrl
        super.init(id: id, transactionStatus: status, message: message)
    }
    
    internal static func fromTx(tx:Sep24Transaction) throws -> InteractiveFlowTransaction {
        guard let txStatus = TransactionStatus(rawValue: tx.status) else {
            throw AnchorError.invalidAnchorResponse(message: "Invalid tx status: \(tx.status) received from anchor.")
        }
        guard let txKind = TransactionKind(rawValue: tx.kind) else {
            throw AnchorError.invalidAnchorResponse(message: "Invalid tx kind: \(tx.kind) received from anchor.")
        }
        
        switch txKind {
        case .deposit:
            if (txStatus == .incomplete) {
                return IncompleteDepositTransaction(tx: tx, status: txStatus)
            } else if (txStatus == .error) {
                return ErrorTransaction(tx: tx, status: txStatus, kind: txKind)
            } else {
                return DepositTransaction(tx: tx, status: txStatus)
            }
        case .withdrawal:
            if (txStatus == .incomplete) {
                return IncompleteWithdrawalTransaction(tx: tx, status: txStatus)
            } else if (txStatus == .error) {
                return ErrorTransaction(tx: tx, status: txStatus, kind: txKind)
            } else {
                return WithdrawalTransaction(tx: tx, status: txStatus)
            }
        default:
            throw AnchorError.invalidAnchorResponse(message: "Invalid tx kind: \(tx.kind) received from anchor.")
        }
    }
}

public class ProcessingAnchorTransaction:InteractiveFlowTransaction {
    
    public let statusEta:Int?
    public let kycVerified:Bool?
    public let amountInAsset:String?
    public let amountIn:String?
    public let amountOutAsset:String?
    public let amountOut:String?
    public let amountFeeAsset:String?
    public let amountFee:String?
    public let quoteId:String?
    public let completedAt:Date?
    public let updatedAt:Date?
    public let userActionRequiredBy:Date?
    public let stellarTransactionId:String?
    public let externalTransactionId:String?
    public let refunds:Refunds?
    
    internal init(tx:Sep24Transaction, status:TransactionStatus) {
        self.statusEta = tx.statusEta
        self.kycVerified = tx.kycVerified
        self.amountInAsset = tx.amountInAsset
        self.amountIn = tx.amountIn
        self.amountOutAsset = tx.amountOutAsset
        self.amountOut = tx.amountOut
        self.amountFeeAsset = tx.amountFeeAsset
        self.amountFee = tx.amountFee
        self.quoteId = tx.quoteId
        self.completedAt = tx.completedAt
        self.updatedAt = tx.updatedAt
        self.userActionRequiredBy = tx.userActionRequiredBy
        self.stellarTransactionId = tx.stellarTransactionId
        self.externalTransactionId = tx.externalTransactionId
        self.refunds = Refunds.fromSep24Refund(refund: tx.refunds)
        
        super.init(id: tx.id, status: status, startedAt: tx.startedAt, moreInfoUrl: tx.moreInfoUrl, message: tx.message)
    }
}

public class DepositTransaction:ProcessingAnchorTransaction {
    public let from:String?
    public let to:String?
    public let depositMemo:String?
    public let depositMemoType:String?
    public let claimableBalanceId:String?
    
    internal override init(tx:Sep24Transaction, status:TransactionStatus) {
        self.from = tx.from
        self.to = tx.to
        self.depositMemo = tx.depositMemo
        self.depositMemoType = tx.depositMemoType
        self.claimableBalanceId = tx.claimableBalanceId
        super.init(tx:tx, status:status)
    }
}

public class WithdrawalTransaction:ProcessingAnchorTransaction {
    public let from:String?
    public let to:String?
    public let withdrawalMemo:String?
    public let withdrawalMemoType:String?
    public let withdrawAnchorAccount:String?
    
    internal override init(tx:Sep24Transaction, status:TransactionStatus) {
        self.from = tx.from
        self.to = tx.to
        self.withdrawalMemo = tx.withdrawMemo
        self.withdrawalMemoType = tx.withdrawMemoType
        self.withdrawAnchorAccount = tx.withdrawAnchorAccount
        super.init(tx:tx, status:status)
    }
}

public class IncompleteAnchorTransaction:InteractiveFlowTransaction {
    internal init(tx:Sep24Transaction, status:TransactionStatus) {
        super.init(id:tx.id, status:status, startedAt:tx.startedAt, moreInfoUrl:tx.moreInfoUrl, message:tx.message)
    }
}

public class IncompleteWithdrawalTransaction:IncompleteAnchorTransaction {
    public let from:String?
    internal override init(tx:Sep24Transaction, status:TransactionStatus) {
        self.from = tx.from
        super.init(tx:tx, status:status)
    }
}

public class IncompleteDepositTransaction:IncompleteAnchorTransaction {
    public let to:String?
    internal override init(tx:Sep24Transaction, status:TransactionStatus) {
        self.to = tx.to
        super.init(tx:tx, status:status)
    }
}

public class ErrorTransaction:InteractiveFlowTransaction {
    
    public let kind:TransactionKind
    
    // Fields from withdrawal/deposit transactions that may present in error transaction
    public let statusEta:Int?
    public let kycVerified:Bool?
    public let amountInAsset:String?
    public let amountIn:String?
    public let amountOutAsset:String?
    public let amountOut:String?
    public let amountFeeAsset:String?
    public let amountFee:String?
    public let quoteId:String?
    public let completedAt:Date?
    public let updatedAt:Date?
    public let userActionRequiredBy:Date?
    public let stellarTransactionId:String?
    public let externalTransactionId:String?
    public let refunded:Bool?
    public let refunds:Refunds?
    public let from:String?
    public let to:String?
    public let depositMemo:String?
    public let depositMemoType:String?
    public let claimableBalanceId:String?
    public let withdrawalMemo:String?
    public let withdrawalMemoType:String?
    public let withdrawAnchorAccount:String?

    internal init(tx:Sep24Transaction, status:TransactionStatus, kind: TransactionKind) {
        self.kind = kind
        self.statusEta = tx.statusEta
        self.kycVerified = tx.kycVerified
        self.amountInAsset = tx.amountInAsset
        self.amountIn = tx.amountIn
        self.amountOutAsset = tx.amountOutAsset
        self.amountOut = tx.amountOut
        self.amountFeeAsset = tx.amountFeeAsset
        self.amountFee = tx.amountFee
        self.quoteId = tx.quoteId
        self.completedAt = tx.completedAt
        self.updatedAt = tx.updatedAt
        self.userActionRequiredBy = tx.userActionRequiredBy
        self.stellarTransactionId = tx.stellarTransactionId
        self.externalTransactionId = tx.externalTransactionId
        self.refunded = tx.refunded
        self.refunds = Refunds.fromSep24Refund(refund: tx.refunds)
        self.from = tx.from
        self.to = tx.to
        self.depositMemo = tx.depositMemo
        self.depositMemoType = tx.depositMemoType
        self.claimableBalanceId = tx.claimableBalanceId
        self.withdrawalMemo = tx.withdrawMemo
        self.withdrawalMemoType = tx.withdrawMemoType
        self.withdrawAnchorAccount = tx.withdrawAnchorAccount
        
        super.init(id: tx.id, status: status, startedAt: tx.startedAt, moreInfoUrl: tx.moreInfoUrl, message: tx.message)
    }
}

public class Refunds {
    
    public let amountFee:String
    public let amountRefunded:String
    public let payments:[Payment]
    
    internal init(amountFee: String, amountRefunded: String, payments: [Payment]) {
        self.amountFee = amountFee
        self.amountRefunded = amountRefunded
        self.payments = payments
    }
    
    internal convenience init(refund:Sep24Refund) {
        var payments:[Payment] = []
        if let sep24RefundPayments = refund.payments {
            for payment in sep24RefundPayments {
                payments.append(Payment(payment: payment))
            }
        }
        self.init(amountFee: refund.amountFee,
                  amountRefunded: refund.amountRefunded,
                  payments: payments)
        
    }
    
    internal static func fromSep24Refund(refund:Sep24Refund?) -> Refunds? {
        var refunds:Refunds? = nil
        if let sep24TxRefund = refund {
            refunds = Refunds(refund: sep24TxRefund)
        }
        return refunds
    }
}

public class Payment{
    
    public let id:String
    public let idType:String
    public let amount:String
    public let fee:String
    
    internal init(id: String, idType: String, amount: String, fee: String) {
        self.id = id
        self.idType = idType
        self.amount = amount
        self.fee = fee
    }
    
    internal convenience init(payment:Sep24RefundPayment) {
        self.init(id: payment.id, 
                  idType: payment.idType,
                  amount: payment.amount,
                  fee: payment.fee)
    }
    
}
