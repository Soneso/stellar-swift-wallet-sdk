//
//  RecoveryServerSigning.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation

public class RecoveryServerSigning {

    public var signerAddress:String
    public var authToken:String
 
    public init(signerAddress: String, authToken: String) {
        self.signerAddress = signerAddress
        self.authToken = authToken
    }
    
}
