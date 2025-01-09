//
//  Sep24.swift
//  
//
//  Created by Christian Rogobete on 08.01.25.
//

import Foundation
import stellarsdk

public class Sep24 {
    internal var anchor:Anchor
    
    internal init(anchor:Anchor) {
        self.anchor = anchor
    }
    
    public var serviceInfo: AnchorServiceInfo {
        get async throws {
            return try await anchor.infoHolder.serviceInfo
        }
    }
}
