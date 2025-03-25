//
//  RecoverableSigner.swift
//  
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation
import stellarsdk

public class RecoverableSigner {

    
    public var key:PublicKeyPair
    public var added:Date?
    
    internal init(key: PublicKeyPair, added: Date? = nil) {
        self.key = key
        self.added = added
    }
    
    internal convenience init(response: SEP30ResponseSigner) throws {
        do {
            self.init(key: try PublicKeyPair(accountId: response.key))
        } catch {
            throw RecoveryServiceError.parsingResponseFailed(message: "Invalid account (key) id in signer from response: \(response.key)")
        }
    }
}
