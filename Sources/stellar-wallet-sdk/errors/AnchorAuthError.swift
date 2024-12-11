//
//  AnchorAuthError.swift
//
//
//  Created by Christian Rogobete on 02.12.24.
//

import Foundation

public enum AnchorAuthError: Error {
    case notSupported
    case invalidJwtToken
    case invalidJwtPayload
    case clientDomainSigningKeyNotFound(clientDomain:String)
    case invaildClientDomainSigningKey(clientDomain:String, key:String)
}
