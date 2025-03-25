//
//  RecoveryError.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation

public enum RecoveryError: Error {
    case noAccountSigners
    case sep10AuthNotSupported(message:String)
}
