//
//  Stellar.swift
//  
//
//  Created by Christian Rogobete on 20.09.24.
//

import Foundation
import stellarsdk

/// Interaction with the Stellar Network.
///
/// - Important: Do not create this object directly, use the Wallet class.
///
public class Stellar {
    
    /// Configuration object.
    public var config:Config
    
    /// AccountService instance for managing Stellar accounts.
    public var account:AccountService
    
    /// Creates a new instance of the Stellar class.
    /// 
    /// - Parameter config: Configuration object.
    ///
    public init(config: Config) {
        self.config = config
        self.account = AccountService(config: config)
    }
    
    /// Funds an account on the stellar test network by using friendbot.
    /// See: https://developers.stellar.org/docs/learn/fundamentals/networks#friendbot
    ///
    /// - Important: Only funds on the testnet network.
    ///
    /// This function throws a horizon request error (stellarsdk.HorizonRequestError) if any error occured while requesting funding from friendbot. E.g. account already exists.
    ///
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
    
    /// Server (base StellarSDK) to be used for queying horizon.
    public var server:StellarSDK {
        return StellarSDK(withHorizonUrl: config.stellar.horizonUrl)
    }
    
    /// Construct a Stellar transaction. Returns a TxBuilder instance.
    ///
    /// This function throws a horizon request error (stellarsdk.HorizonRequestError) if any error occured while fetching the account details for the source account. E.g. .notFound
    ///
    /// - Parameters:
    ///   - sourceAddress: The source account keypair.
    ///   - timeout: Optional, if  given, then timebounds will constructed from now to now + timeout in seconds and added to the transaction.
    ///   - baseFee: Optional, the base fee for the transaction. Defaults to the config base fee.
    ///   - memo: Optional, the memo for the transaction.
    ///
    public func transaction(sourceAddress:AccountKeyPair, timeout:UInt32? = nil, baseFee: UInt32? = nil, memo:stellarsdk.Memo? = nil) async throws -> TxBuilder {
        let accountResponse = try await account.getInfo(accountAddress: sourceAddress.address)
        let txBaseFee = baseFee ?? config.stellar.baseFee
        let txTimeout = timeout ?? config.stellar.defaultTimeout
        let txTimeBounds = TimeBounds(minTime: 0, maxTime: UInt64(Date().timeIntervalSince1970 + Double(txTimeout)))
        
        var txBuilder = TxBuilder(sourceAccount: accountResponse)
            .setBaseFee(baseFeeInStoops: txBaseFee)
            .setTimebounds(timebounds: txTimeBounds)
        
        if let txMemo = memo {
            txBuilder = txBuilder.setMemo(memo: txMemo)
        }
    
        return txBuilder
    }
    
    /// Signs the transaction with the given signing key pair.
    ///
    /// - Parameters:
    ///   - tx: The  transaction to sign
    ///   - keyPair: The keyPair to sign the transaction with.
    ///
    public func sign(tx:stellarsdk.Transaction, keyPair:SigningKeyPair) {
        try! tx.sign(keyPair: keyPair.keyPair, network: config.stellar.network)
    }
    
    /// Submits a signed transaction to the server. If the submission fails with status 504 indicating a timeout error, it will automatically retry.
    /// Retruns `true` if the transaction was successfully submitted.
    ///
    /// This function throws a horizon request error (stellarsdk.HorizonRequestError) if any error occured while sending the transaction to the stellar network.
    /// It can also throw a validation error (ValidationError.invalidArgument) if the destination requires a memo but no memo was found in the transaction.
    ///
    /// - Parameter signedTransaction: The signed transaction to submit.
    ///
    public func submitTransaction(signedTransaction: stellarsdk.Transaction) async throws -> Bool {
        let responseEnum = await server.transactions.submitTransaction(transaction: signedTransaction)
        switch responseEnum {
        case .success(_):
            return true
        case .destinationRequiresMemo(let destinationAccountId):
            throw ValidationError.invalidArgument(message: ("account \(destinationAccountId) requires memo"))
        case .failure(let error):
            switch error {
            case .timeout(_, _):
                // resubmit
                return try await submitTransaction(signedTransaction: signedTransaction)
          default:
                throw error
            }
        }
    }    
}
