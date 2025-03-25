//
//  RecoverableAccountInfo.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation
import stellarsdk

public class RecoverableAccountInfo {

    
    public var address: PublicKeyPair
    public var identities:[RecoverableIdentity]
    public var signers:[RecoverableSigner]
    
    internal init(address: PublicKeyPair, identities: [RecoverableIdentity], signers: [RecoverableSigner]) {
        self.address = address
        self.identities = identities
        self.signers = signers
    }
    
    internal convenience init(response: Sep30AccountResponse) throws {
        let address = try PublicKeyPair(accountId: response.address)
        var identities:[RecoverableIdentity] = []
        for identity in response.identities {
            identities.append(try RecoverableIdentity(response: identity))
        }
        var signers:[RecoverableSigner] = []
        for signer in response.signers {
            signers.append(try RecoverableSigner(response: signer))
        }
        self.init(address: address, identities: identities, signers: signers)
    }
}
