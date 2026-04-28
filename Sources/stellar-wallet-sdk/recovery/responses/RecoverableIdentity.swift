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
        guard let roleRaw = response.role else {
            throw RecoveryServiceError.parsingResponseFailed(message: "missing role in response")
        }
        guard let role = RecoveryRole(rawValue: roleRaw) else {
            throw RecoveryServiceError.parsingResponseFailed(message: "unknown role received in response: \(roleRaw)")
        }

        self.init(role: role, authenticated: response.authenticated)
    }
}
