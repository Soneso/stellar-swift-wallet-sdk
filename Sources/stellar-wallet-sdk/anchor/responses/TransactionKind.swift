//
//  TransactionKind.swift
//
//
//  Created by Christian Rogobete on 09.01.25.
//

import Foundation

public enum TransactionKind:String {
    case deposit = "deposit"
    case withdrawal = "withdrawal"
    case depositExchange = "deposit-exchange"
    case withdrawalExchange = "withdrawal-exchange"
}
