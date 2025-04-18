//
//  AnchorError.swift
//
//
//  Created by Christian Rogobete on 08.01.25.
//

import Foundation

public enum AnchorError: Error {
    case interactiveFlowNotSupported
    case invalidAnchorResponse(message:String)
    case quoteServerNotFound
    case kycServerNotFound
    case depositAndWithdrawalAPINotSupported
}
