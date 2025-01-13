//
//  WalletExceptionHandler.swift
//
//
//  Created by Christian Rogobete on 13.01.25.
//

import Foundation

public protocol WalletExceptionHandler {
    func invoke(ctx:RetryContext) async -> Bool
}

public class RetryExceptionHandler:WalletExceptionHandler {

    public var maxRetryCount:Int
    public var backoffPeriod:Double
    
    public init(maxRetryCount: Int = 3, backoffPeriod: Double = 5.0) {
        self.maxRetryCount = maxRetryCount
        self.backoffPeriod = backoffPeriod
    }

    public func invoke(ctx: RetryContext) async -> Bool {
        if ctx.retries < maxRetryCount {
            try? await Task.sleep(nanoseconds: UInt64(backoffPeriod * Double(NSEC_PER_SEC)))
            return false
        }
        return true
    }
}

public class RetryContext {
    
    public var retries:Int
    public var error:Error? = nil
    
    internal init(retries: Int = 0) {
        self.retries = retries
    }
    
    public func refresh() {
        retries = 0
        error = nil
    }
    
    
    public func onError(e:Error) {
        error = e
        retries += 1
    }
}
