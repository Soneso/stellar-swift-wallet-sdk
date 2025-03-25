//
//  RecoverableIdentity.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation
import stellarsdk

public class RecoverableIdentity {

    
    public var role:RecoveryRole
    public var authenticated:Bool?
    
    internal init(role: RecoveryRole, authenticated: Bool? = nil) {
        self.role = role
        self.authenticated = authenticated
    }
    
    internal convenience init(response: SEP30ResponseIdentity) throws {
        guard let role = RecoveryRole(rawValue: response.role) else {
            throw RecoveryServiceError.parsingResponseFailed(message: "unknown role received in response: \(response.role)")
        }
        
        self.init(role: role, authenticated: response.authenticated)
    }
}
