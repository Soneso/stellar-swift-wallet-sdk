//
//  DomainSignerError.swift
//  
//
//  Created by Christian Rogobete on 31.10.24.
//

import Foundation

public enum DomainSignerError: Error {
    case requestError(error: Error)
    case unexpectedResponse(response: URLResponse)
}
