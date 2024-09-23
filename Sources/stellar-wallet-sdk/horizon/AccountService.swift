//
//  AccountService.swift
//
//
//  Created by Christian Rogobete on 20.09.24.
//

import stellarsdk

/// Account service for working with accounts and fetching their data from the stellar network.
/// - Important: Do not create this object directly, use the `Wallet` class. Access via `wallet.stellar.account`
///
public class AccountService {
    public static var pageLimit:Int = 100
    internal var config:Config
    
    /// Creates a new instance of the AccountService class.
    /// - Parameter config: Configuration for the service.
    internal init(config: Config) {
        self.config = config
    }
    
    /// Generate new account keypair (public and secret key). This key pair can be used to create a Stellar account.
    public func createKeyPair() -> SigningKeyPair {
        return SigningKeyPair.random
    }
    
    /// Checks if an account exists on the stellar network.
    ///
    ///  This function throws a `stellarsdk.HorizonRequestError` if any error occured during the coimmunication with horizon.
    ///
    /// - Parameter accountAddress: The stellar address (account id) of the account to check.
    ///
    public func accountExists(accountAddress:String) async throws -> Bool {
        let horizonUrl = config.stellar.horizonUrl
        let sdk = StellarSDK(withHorizonUrl: horizonUrl)
        let resultEnum = await sdk.accounts.getAccountDetails(accountId: accountAddress)
        switch resultEnum {
        case .success(_):
            return true
        case .failure(let error):
            switch error {
            case .notFound(_,_):
                return false
            default:
                throw error
            }
        }
    }
    
    ///  Get account information from the Stellar network.
    ///
    ///  This function throws a `stellarsdk.HorizonRequestError` if any error occured during the coimmunication with horizon.
    ///
    /// - Parameter accountAddress: The stellar address (account id) of the stellar account.
    ///
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
