//
//  RecoveryRole.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation

/// The role of the identity. This value is not used by the server and is stored and echoed back in
/// responses as a way for a client to know conceptually who each identity represents
public enum RecoveryRole: String {
    case owner = "owner"
    case sender = "sender"
    case receiver = "receiver"
}
