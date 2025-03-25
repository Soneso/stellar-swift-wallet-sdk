//
//  AccountThreshold.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation

/// Account weights threshold
public class AccountThreshold {

    public var low:UInt32
    public var medium:UInt32
    public var high:UInt32
    
    /// Constructor
    ///
    /// - Parameters:
    ///   - low: low threshold weight
    ///   - medium: medium threshold weight
    ///   - high: high threshold weight
    ///
    public init(low: UInt32, medium: UInt32, high: UInt32) {
        self.low = low
        self.medium = medium
        self.high = high
    }
}
