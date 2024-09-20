//
//  Stellar.swift
//  
//
//  Created by Christian Rogobete on 20.09.24.
//

import stellarsdk

public class Stellar {
    public var config:Config
    public var account:AccountService
    
    public init(config: Config) {
        self.config = config
        self.account = AccountService(config: config)
    }
    
    public func fundTestNetAccount(address:String) async throws
    {
        let sdk = StellarSDK.testNet()
        let responseEnum = await sdk.accounts.createTestAccount(accountId: address)
        switch responseEnum {
        case .success(_):
            break
        case .failure(let error):
            throw error
        }
    }
}
