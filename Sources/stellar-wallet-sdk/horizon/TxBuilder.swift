//
//  TxBuilder.swift
//
//
//  Created by Christian Rogobete on 23.09.24.
//

import Foundation
import stellarsdk

public class CommonTxBuilder {
    var sourceAccount:TransactionAccount
    var operations:[stellarsdk.Operation]
    var memo:stellarsdk.Memo?
    var timebounds:stellarsdk.TimeBounds?
    var baseFee:UInt32?
    
    fileprivate init(sourceAccount:TransactionAccount, operations:[stellarsdk.Operation]) {
        self.sourceAccount = sourceAccount
        self.operations = operations
    }
    
    func addAccountSigner(signerAddress:AccountKeyPair, signerWeight:UInt32) {
        let accSignerKey =  try! Signer.ed25519PublicKey(accountId: signerAddress.address)
        
        let op = try! SetOptionsOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            signer: accSignerKey,
            signerWeight: signerWeight)
        
        operations.append(op)
    }
    
    func removeAccountSigner(signerAddress:AccountKeyPair) throws {
        if (signerAddress.address == sourceAccount.keyPair.accountId) {
            throw ValidationError.invalidArgument(
                message: "This method can't be used to remove master signer key, call the lockAccountMasterKey method instead")
        }
        
        addAccountSigner(signerAddress: signerAddress, signerWeight: 0)
    }
    
    /// Lock the master key of the account (set its weight to 0). Use caution when locking account's
    /// master key. Make sure you have set the correct signers and weights. Otherwise, you might lock
    /// the account irreversibly.
    func lockAccountMasterKey() {
        
        let op = try! SetOptionsOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            masterKeyWeight: 0)
        
        operations.append(op)
    }
    
    func addAssetSupport(asset:IssuedAssetId, limit:Decimal?) {
        let asset = ChangeTrustAsset(canonicalForm: asset.id)!
        let op = ChangeTrustOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            asset: asset,
            limit: limit ?? Decimal(922337203685.4775807))
        
        operations.append(op)
    }
    
    func removeAssetSupport(asset:IssuedAssetId) {
        let asset = ChangeTrustAsset(canonicalForm: asset.id)!
        let op = ChangeTrustOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            asset: asset,
            limit: Decimal(0))
        
        operations.append(op)
    }
    
    func setThreshold(low:UInt32, medium:UInt32, high:UInt32) {
        let op = try! SetOptionsOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            lowThreshold: low,
            mediumThreshold: medium,
            highThreshold: high)
        
        operations.append(op)
    }

    func build() throws ->stellarsdk.Transaction
    {
        if(operations.count == 0) {
            throw ValidationError.invalidArgument(message: "minimum one operation is required to build the transaction")
        }
        var preconditions:TransactionPreconditions? = nil
        if let tb = timebounds {
            preconditions = TransactionPreconditions(timeBounds: tb)
        }
        
        return try! Transaction(
            sourceAccount: sourceAccount,
            operations: operations,
            memo: memo,
            preconditions: preconditions,
            maxOperationFee: baseFee ?? 100)
    }
}

/// Used for building transactions.
///  
/// - Important: Do not create this object directly, use the Stellar class to create a transaction.
///
public class TxBuilder:CommonTxBuilder {

    /// Creates a new instance of the TransactionBuilder class for constructing Stellar transactions.
    ///
    /// - Parameter sourceAccount: The source account for the transaction.
    ///
    public init(sourceAccount:TransactionAccount) {
        super.init(sourceAccount: sourceAccount, operations: [])
    }
    
    /// Add a memo for the transaction.
    /// Returns the TxBuilder instance for chaining.
    ///
    /// - Parameter memo: The memo to add to the transaction.
    ///
    func setMemo(memo:stellarsdk.Memo) -> TxBuilder  {
        self.memo = memo
        return self
    }
    
    /// Adds timebounds to the transaction
    /// Returns the TxBuilder instance for chaining.
    ///
    /// - Parameter timebounds: The timebounds to add to the transaction.
    ///
    func setTimebounds(timebounds:stellarsdk.TimeBounds) -> TxBuilder  {
        self.timebounds = timebounds
        return self
    }
    
    /// Sets the maximum fee to be payed per operation contained in the transaction.
    /// Returns the TxBuilder instance for chaining.
    ///
    /// - Parameter baseFeeInStoops: The base fee in stoops (smallest stellar lumen units). Default is 100
    ///
    func setBaseFee(baseFeeInStoops:UInt32) -> TxBuilder  {
        self.baseFee = baseFeeInStoops
        return self
    }
    
    /// Creates a Stellar account.
    /// Returns the TxBuilder instance for chaining.
    ///
    /// This function throws a validation error (ValidationError.invalidArgument) if the given starting balance is smaller than 1 XLM.
    ///
    /// - Parameters:
    ///   - newAccount: The new account's keypair.
    ///   - startingBalance: The starting balance for the new account (default is 1 XLM).
    ///   
    public func createAccount(newAccount:AccountKeyPair, startingBalance:Decimal = Decimal(1)) throws -> TxBuilder {
        if (startingBalance < Decimal(1)) {
            throw ValidationError.invalidArgument(message: "Starting balance must be at least 1 XLM for non-sponsored accounts")
        }
        let op = CreateAccountOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            destination: newAccount.keyPair,
            startBalance: startingBalance)
        
        operations.append(op)
        
        return self
    }
    
    /// Lock the master key of the account (set its weight to 0). Use caution when locking account's
    /// master key. Make sure you have set the correct signers and weights. Otherwise, you might lock
    /// the account irreversibly.
    func lockAccountMasterKey() -> TxBuilder {
        super.lockAccountMasterKey()
        return self
    }
    
    /// Adds a payment operation to transfer an amount of an asset to a destination address.
    /// Returns the TxBuilder instance for chaining.
    ///
    /// This function throws a validation error (ValidationError.invalidArgument) if the given amount is smaller or equal 0 XLM
    /// or if the given destination address is not a valid account public key (account id).
    ///
    /// - Parameters:
    ///   - destinationAddress: The destination account's public key.
    ///   - assetId: The asset to transfer.
    ///   - amount: The amount to transfer.
    ///
    public func transfer(destinationAddress:String, assetId:StellarAssetId, amount:Decimal) throws -> TxBuilder {
        if (amount <= Decimal(0)) {
            throw ValidationError.invalidArgument(message: "Can not transfer amount 0 or less")
        }
        do {
            let _ = try destinationAddress.decodeMuxedAccount()
        } catch {
            throw ValidationError.invalidArgument(message: "invalid destination address (account id): \(destinationAddress)")
        }
        
        let op = try! PaymentOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            destinationAccountId: destinationAddress,
            asset: assetId.toAsset(),
            amount: amount)
        operations.append(op)
        
        return self
    }
    
    /// Adds an operation to the transaction.
    /// Returns the TxBuilder instance for chaining.
    ///
    /// - Parameter operation: The operation to add to the transaction.
    ///
    public func addOperation(operation:stellarsdk.Operation) -> TxBuilder {
        operations.append(operation)
        return self
    }

    /// Sponsoring a transaction.
    /// Returns the TxBuilder instance for chaining.
    ///
    /// - Parameters:
    ///   - sponsorAccount: The account doing the sponsoring.
    ///   - buildingFunction: Function for creating the operations that will be sponsored.
    ///   - sponsoredAccount: The account that will be sponsored.
    ///
    public func sponsoring(sponsorAccount:AccountKeyPair, buildingFunction:(_:SponsoringBuilder) -> SponsoringBuilder, sponsoredAccount:AccountKeyPair?) -> TxBuilder {
        let sponsoredAccountKp = sponsoredAccount?.keyPair ?? sourceAccount.keyPair
        let beginSponsorshipOp = BeginSponsoringFutureReservesOperation(sponsoredAccountId: sponsoredAccountKp.accountId, sponsoringAccountId: sponsorAccount.address)
        operations.append(beginSponsorshipOp)
        
        let builderAccount = Account(keyPair: sponsoredAccountKp, sequenceNumber: 0)
        var opBuilder = SponsoringBuilder(sourceAccount: builderAccount, sponsorAccount: sponsorAccount)
        opBuilder = buildingFunction(opBuilder)
        operations.append(contentsOf: opBuilder.operations)
        
        let endSponsoringOp = EndSponsoringFutureReservesOperation(sponsoredAccountId: sponsoredAccountKp.accountId)
        operations.append(endSponsoringOp)
        return self
    }

}

public class SponsoringBuilder:CommonTxBuilder {

    var sponsorAccount:AccountKeyPair
    
    public init(sourceAccount:TransactionAccount, sponsorAccount:AccountKeyPair) {
        self.sponsorAccount = sponsorAccount
        super.init(sourceAccount: sourceAccount, operations: [])
    }
    
    public func createAccount(newAccount:AccountKeyPair, startingBalance:Decimal = Decimal(0)) -> SponsoringBuilder {
        var txStartingBalance = startingBalance
        if (txStartingBalance < Decimal(0)) {
            txStartingBalance = Decimal(0)
        }
        let op = CreateAccountOperation(
            sourceAccountId: sponsorAccount.address,
            destination: newAccount.keyPair,
            startBalance: txStartingBalance)
        
        operations.append(op)
        
        return self
    }
    
    /// Lock the master key of the account (set its weight to 0). Use caution when locking account's
    /// master key. Make sure you have set the correct signers and weights. Otherwise, you might lock
    /// the account irreversibly.
    func lockAccountMasterKey() -> SponsoringBuilder {
        super.lockAccountMasterKey()
        return self
    }
    
    public func addManageDataOperation(operation:stellarsdk.ManageDataOperation) -> SponsoringBuilder {
        operations.append(operation)
        return self
    }
    
    public func addManageBuyOfferOperation(operation:stellarsdk.ManageBuyOfferOperation) -> SponsoringBuilder {
        operations.append(operation)
        return self
    }
    
    public func addManageSellOfferOperation(operation:stellarsdk.ManageSellOfferOperation) -> SponsoringBuilder {
        operations.append(operation)
        return self
    }
    
    public func addSetOptionsOperation(operation:stellarsdk.SetOptionsOperation) -> SponsoringBuilder {
        operations.append(operation)
        return self
    }
}


