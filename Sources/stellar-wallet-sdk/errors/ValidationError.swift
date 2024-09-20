//
//  ValidationError.swift
//  
//
//  Created by Christian Rogobete on 19.09.24.
//

import Foundation

public enum ValidationError: Error {
    case invalidArgument(message: String)
}
