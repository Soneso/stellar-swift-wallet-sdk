//
//  RecoverableWallet.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation
import stellarsdk

public class RecoverableWallet {

    public var transaction:Transaction
    public var signers:[String]
    
    internal init(transaction: Transaction, signers: [String]) {
        self.transaction = transaction
        self.signers = signers
    }
}
