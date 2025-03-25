//
//  RecoveryAccountAuthMethod.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation
import stellarsdk

public class RecoveryAccountAuthMethod {
    public var type:RecoveryType
    public var value:String
    
    public init(type: RecoveryType, value: String) {
        self.type = type
        self.value = value
    }
    
    internal func toSEP30AuthMethod() -> Sep30AuthMethod {
        return Sep30AuthMethod(type: type.rawValue, value: value)
    }
}
