//
//  AnchorTransaction.swift
//
//
//  Created by Christian Rogobete on 09.01.25.
//

import Foundation

public class AnchorTransaction {
    
    public let id:String
    public let transactionStatus: TransactionStatus
    public let message:String?
    
    internal init(id: String, transactionStatus: TransactionStatus, message: String? = nil) {
        self.id = id
        self.transactionStatus = transactionStatus
        self.message = message
    }
}
