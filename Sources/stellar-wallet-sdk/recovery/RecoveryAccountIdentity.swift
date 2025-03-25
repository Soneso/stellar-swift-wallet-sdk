//
//  RecoveryAccountIdentity.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation
import stellarsdk

public class RecoveryAccountIdentity {

    public var role:RecoveryRole
    public var authMethods:[RecoveryAccountAuthMethod]

    public init(role: RecoveryRole, authMethods: [RecoveryAccountAuthMethod]) {
        self.role = role
        self.authMethods = authMethods
    }
    
    internal func toSEP30RequestIdentity() -> Sep30RequestIdentity {
        var auth:[Sep30AuthMethod] = []
        for authMethod in authMethods {
            auth.append(authMethod.toSEP30AuthMethod())
        }
        return Sep30RequestIdentity(role: role.rawValue, authMethods: auth)
    }
}
