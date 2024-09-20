//
//  AccountService.swift
//
//
//  Created by Christian Rogobete on 20.09.24.
//

import stellarsdk

public enum AccountInfoResponseEnum {
    case success(info: stellarsdk.AccountResponse)
    case failure(error: stellarsdk.HorizonRequestError)
}

public class AccountService {
    public static var pageLimit:Int = 100
    public var config:Config
    
    public init(config: Config) {
        self.config = config
    }
    
    public func createKeyPair() -> SigningKeyPair {
        return SigningKeyPair.random
    }
    
    public func accountExists(accountAddress:String) async throws -> Bool {
        let horizonUrl = config.stellar.horizonUrl
        let sdk = StellarSDK(withHorizonUrl: horizonUrl)
        let resultEnum = await sdk.accounts.getAccountDetails(accountId: accountAddress)
        switch resultEnum {
        case .success(let details):
            return true
        case .failure(let error):
            switch error {
            case .notFound(let message, let horizonErrorResponse):
                return false
            default:
                throw error
            }
        }
    }
    
    public func getInfo(accountAddress:String) async throws -> stellarsdk.AccountResponse {
        let horizonUrl = config.stellar.horizonUrl
        let sdk = StellarSDK(withHorizonUrl: horizonUrl)
        let resultEnum = await sdk.accounts.getAccountDetails(accountId: accountAddress)
        switch resultEnum {
        case .success(let details):
            return details
        case .failure(let error):
            throw error
        }
    }
    
    
}
