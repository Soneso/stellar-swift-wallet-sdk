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
    
    public var server:StellarSDK {
        return StellarSDK(withHorizonUrl: config.stellar.horizonUrl)
    }
    
    public func sign(tx:stellarsdk.Transaction, keyPair:SigningKeyPair) {
        try! tx.sign(keyPair: keyPair.keyPair, network: config.stellar.network)
    }
    
    public func submitTransaction(signedTransaction: stellarsdk.Transaction) async throws -> Bool {
        let responseEnum = await server.transactions.submitTransaction(transaction: signedTransaction)
        switch responseEnum {
        case .success(_):
            return true
        case .destinationRequiresMemo(let destinationAccountId):
            throw ValidationError.invalidArgument(message: ("account \(destinationAccountId) requires memo"))
        case .failure(let error):
            switch error {
            case .timeout(let message, let horizonErrorResponse):
                // resubmit
                return try await submitTransaction(signedTransaction: signedTransaction)
          default:
                throw error
            }
        }
    }    
}
