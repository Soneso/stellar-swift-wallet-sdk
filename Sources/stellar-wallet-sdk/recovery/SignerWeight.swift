//
//  SignerWeight.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation

public class SignerWeight {
    
    public var device:UInt32
    public var recoveryServer:UInt32
    
    public init(device: UInt32, recoveryServer: UInt32) {
        self.device = device
        self.recoveryServer = recoveryServer
    }
}
