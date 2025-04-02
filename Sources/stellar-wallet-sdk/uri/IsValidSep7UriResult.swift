//
//  IsValidSep7UriResult.swift
//
//
//  Created by Christian Rogobete on 26.03.25.
//

import Foundation

/// Holds the result of a sep7 uri validation
public class IsValidSep7UriResult {

    public var result:Bool
    public var reason:String?
    public var operationType:Sep7OperationType?
    public var queryItems:[URLQueryItem]?
    
    internal init(result: Bool, reason: String? = nil, operationType: Sep7OperationType? = nil, queryItems: [URLQueryItem]? = nil) {
        self.result = result
        self.reason = reason
        self.operationType = operationType
        self.queryItems = queryItems
    }
}
