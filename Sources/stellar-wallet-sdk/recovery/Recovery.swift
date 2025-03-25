//
//  File.swift
//  
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation
import stellarsdk

public class Recovery:AccountRecover {
    
    
    internal var cfg:Config
    
    internal init(cfg: Config, servers: [RecoveryServerKey : RecoveryServer]) {
        self.cfg = cfg
        super.init(stellar: cfg.stellar, servers: servers)
    }
    
    /// Create new Sep10 object to authenticate account with the recovery server using SEP-10.
    public func sep10Auth(key:RecoveryServerKey) async throws -> Sep10 {
        if let server = servers[key] {
          
            var stellarToml:StellarToml? = nil
            let responseEnum = await StellarToml.from(domain: server.homeDomain)
            switch responseEnum {
            case .success(let response):
                stellarToml = response
            case .failure(let error):
                throw error
            }
            
            guard let signingKey = stellarToml?.accountInformation.signingKey else {
                throw RecoveryError.sep10AuthNotSupported(message: "Server signing key not found.")
            }
            guard let webAuthEndpint = stellarToml?.accountInformation.webAuthEndpoint else {
                throw RecoveryError.sep10AuthNotSupported(message: "Server has no sep 10 web auth endpoint.")
            }
            if webAuthEndpint != server.authEndpoint {
                throw RecoveryError.sep10AuthNotSupported(message: "Invalid auth endpoint, not equal to sep 10 web auth endpoint.")
            }
            return Sep10(config: cfg, serverHomeDomain: server.homeDomain, serverAuthEndpoint: webAuthEndpint, serverSigningKey: signingKey)
        } else {
            throw ValidationError.invalidArgument(message: "key not found in servers map")
        }
    }
    
    /// Create new recoverable wallet using [SEP-30](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md).
    /// It registers the account with recovery servers, adds recovery servers and device account as new account signers, and sets threshold weights on the account.
    /// **Warning**: This transaction will lock master key of the account. Make sure you have access to specified [RecoverableWalletConfig.deviceAddress]
    /// This transaction can be sponsored.
    public func createRecoverableWallet(config: RecoverableWalletConfig) async throws -> RecoverableWallet {
        
        if (config.deviceAddress.address == config.accountAddress.address) {
            throw ValidationError.invalidArgument(message: "Device key must be different from master (account) key")
        }
        
        let recoverySigners:[String] = try await enrollWithRecoveryServer(account: config.accountAddress,
                                                                          identityDic: config.accountIdentity)
        var signers:[AccountSigner] = []
        for rs in recoverySigners {
            let kp = try KeyPair(accountId: rs)
            signers.append(AccountSigner(address: PublicKeyPair(keyPair: kp), weight: config.signerWeight.recoveryServer))
        }
        signers.append(AccountSigner(address: config.deviceAddress, weight: config.signerWeight.device))
        
        let tx = try await registerRecoveryServerSigners(account: config.accountAddress,
                                                         accountSigners:signers,
                                                         accountThreshold: config.accountThreshold,
                                                         sponsorAddress: config.sponsorAddress)
        
        return RecoverableWallet(transaction: tx, signers: recoverySigners)
    }
    
    /// Returns account info from the specified servers
    ///
    /// - Parameters:
    ///   - accountAddress: Stellar address of the account to get info for
    ///   - auth: dictionary containing the keys of the servers to fetch  and their corresponding jwt tokens received with sep-10 previously
    ///
    public func getAccountInfo(accountAddress:AccountKeyPair, auth:[RecoveryServerKey:String]) async throws -> [RecoveryServerKey:RecoverableAccountInfo] {
        
        var result:[RecoveryServerKey:RecoverableAccountInfo] = [:]
        for (key, value) in auth {
            if let server = servers[key] {
                let service = RecoveryService(serviceAddress: server.endpoint)
                let responseEnum = await service.accountDetails(address: accountAddress.address, jwt: value)
                switch responseEnum {
                case .success(let response):
                    result[key] = try RecoverableAccountInfo(response: response)
                case .failure(let error):
                    throw error
                }
            } else {
                throw ValidationError.invalidArgument(message: "key: \(key.name) not found in servers map")
            }
        }
        return result
    }
    
    private func enrollWithRecoveryServer(account:AccountKeyPair,
                                          identityDic:[RecoveryServerKey:[RecoveryAccountIdentity]]) async throws -> [String] {
        var result:[String] = []
        
        for (key, server) in servers {
            guard let accountIdentities = identityDic[key] else {
                throw ValidationError.invalidArgument(message: "Account identity for server \(key.name) was not specified")
            }
            let sep10 = try await sep10Auth(key: key)
            let authToken = try await sep10.authenticate(userKeyPair: account,
                                                         clientDomain: server.clientDomain,
                                                         clientDomainSigner: server.walletSigner)
            var identities: [Sep30RequestIdentity] = []
            
            for accountIdentity in accountIdentities {
                identities.append(accountIdentity.toSEP30RequestIdentity())
            }
            
            let request = Sep30Request(identities: identities)
            let service = RecoveryService(serviceAddress: server.endpoint)
            let responseEnum = await service.registerAccount(address: account.address,
                                                             request: request,
                                                             jwt: authToken.jwt)
            switch responseEnum {
            case .success(let response):
                if response.signers.isEmpty {
                    throw RecoveryError.noAccountSigners
                }
                result.append(response.signers.first!.key)
            case .failure(let error):
                throw error
            }
        }
        return result
    }
    
    private func registerRecoveryServerSigners(account:AccountKeyPair,
                                               accountSigners:[AccountSigner],
                                               accountThreshold:AccountThreshold,
                                               sponsorAddress:AccountKeyPair? = nil) async throws -> Transaction {
        
        let sdk = StellarSDK(withHorizonUrl: cfg.stellar.horizonUrl)
        
        var acc:AccountResponse? = nil
        
        var responseEnum = await sdk.accounts.getAccountDetails(accountId: account.address)

        switch responseEnum {
        case .success(let details):
            acc = details
        case .failure(let error):
            switch error {
            case .notFound(_, _):
                break
            default:
                throw error
            
            }
        }
        if (acc == nil && sponsorAddress == nil) {
            throw ValidationError.invalidArgument(message: "Account does not exist and is not sponsored.")
        }
        
        var sponsorAcc:AccountResponse? = nil
        if let sponsorAddress = sponsorAddress {
            responseEnum = await sdk.accounts.getAccountDetails(accountId: sponsorAddress.address)
            switch responseEnum {
            case .success(let details):
                sponsorAcc = details
            case .failure(let error):
                switch error {
                case .notFound(_, _):
                    break
                default:
                    throw error
                
                }
            }
            guard sponsorAcc != nil else {
                throw ValidationError.invalidArgument(message: "Sponsor account dose not exist")
            }
        }
        
        var operations:[stellarsdk.Operation] = []
        if let sponsorAcc = sponsorAcc {
            let begingSponsorshipOp = BeginSponsoringFutureReservesOperation(sponsoredAccountId: account.address,
                                                                             sponsoringAccountId: sponsorAcc.accountId)
            operations.append(begingSponsorshipOp)
            if acc == nil {
                let createAccountOp = try CreateAccountOperation(sourceAccountId: nil, destinationAccountId: account.address, startBalance: 0)
                operations.append(createAccountOp)
            }
            
            operations.append(contentsOf: try register(account: account, accountSigners: accountSigners, accountThreshold: accountThreshold))
            
            let endSponsoringOp = EndSponsoringFutureReservesOperation(sponsoredAccountId: account.address)
            operations.append(endSponsoringOp)
        } else {
            operations.append(contentsOf: try register(account: account, accountSigners: accountSigners, accountThreshold: accountThreshold))
        }
        
        
        return try stellarsdk.Transaction(sourceAccount: acc ?? sponsorAcc! , operations: operations, memo: Memo.none)
    }
    
    private func register(account:AccountKeyPair, accountSigners:[AccountSigner], accountThreshold:AccountThreshold) throws  -> [stellarsdk.Operation] {
        var operations:[stellarsdk.Operation] = []
        operations.append(try SetOptionsOperation(sourceAccountId: account.address, masterKeyWeight: 0))
        for signer in accountSigners {
            let sKey = SignerKeyXDR.ed25519(signer.address.keyPair.publicKey.wrappedData32())
            operations.append(try SetOptionsOperation(sourceAccountId: account.address, signer: sKey, signerWeight: signer.weight))
        }
        operations.append(try SetOptionsOperation(sourceAccountId: account.address,
                                                  lowThreshold: accountThreshold.low,
                                                  mediumThreshold: accountThreshold.medium,
                                                  highThreshold: accountThreshold.high))
        return operations
        
    }
}
