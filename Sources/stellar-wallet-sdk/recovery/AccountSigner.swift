//
//  AccountSigner.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation

public class AccountSigner {

    public var address:AccountKeyPair
    public var weight:UInt32
    
    public init(address: any AccountKeyPair, weight: UInt32) {
        self.address = address
        self.weight = weight
    }
}
