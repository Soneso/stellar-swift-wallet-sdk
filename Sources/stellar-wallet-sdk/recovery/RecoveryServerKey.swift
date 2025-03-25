//
//  RecoveryServerKey.swift
//  
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation

public class RecoveryServerKey : Hashable {

    public var name:String
 
    public init(name: String) {
        self.name = name
    }
    
    public static func == (lhs: RecoveryServerKey, rhs: RecoveryServerKey) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
