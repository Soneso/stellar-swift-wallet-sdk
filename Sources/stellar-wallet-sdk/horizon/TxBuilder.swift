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
            
    /// Lock the master key of the account (set its weight to 0). Use caution when locking account's
    /// master key. Make sure you have set the correct signers and weights. Otherwise, you might lock
    /// the account irreversibly.
    fileprivate func lockAccountMasterKey() {
        
        // This only throws if only one of signer and signerWeight is passed.
        // Here we provide non of both, so it will not throw.
        let op = try! SetOptionsOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            masterKeyWeight: 0)
        
        operations.append(op)
    }
    
    /// Add new signer to the account. Use caution when adding new signers, make sure you set the
    /// correct signer weight. Otherwise, you might lock the account irreversibly.
    ///
    /// - Parameters:
    ///   - signerAddress: Stellar address of the signer that is added
    ///   - signerWeight: Signer weight
    ///
    fileprivate func addAccountSigner(signerAddress:AccountKeyPair, signerWeight:UInt32) {
        
        // This will only throw on invalid address. But since the address is from
        // the key pair it can not be invalid.
        let accSignerKey =  try! Signer.ed25519PublicKey(accountId: signerAddress.address)
        
        // This only throws if only one of signer and signerWeight is passed.
        // But here we provide both, so it will not throw.
        let op = try! SetOptionsOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            signer: accSignerKey,
            signerWeight: signerWeight)
        
        operations.append(op)
    }
    
    /// Remove signer from the account.
    ///
    ///  Throws `ValidationError.invalidArgument` if you try to remove the account master key.
    ///  Use `lockAccountMasterKey` instead.
    ///
    ///  - Parameter signerAddress: Stellar address of the signer to be  removed
    ///
    fileprivate func removeAccountSigner(signerAddress:AccountKeyPair) throws {
        if (signerAddress.address == sourceAccount.keyPair.accountId) {
            throw ValidationError.invalidArgument(
                message: "This method can't be used to remove master signer key, call the lockAccountMasterKey method instead")
        }
        
        addAccountSigner(signerAddress: signerAddress, signerWeight: 0)
    }
    
    /// Add a trustline for an asset so can receive or send it.
    ///
    /// - Parameters:
    ///   - asset: The asset for which support is added.
    ///   - limit: Optional. The trust limit for the asset. If not set it defaults to max.
    ///
    fileprivate func addAssetSupport(asset:IssuedAssetId, limit:Decimal?) {
        let asset = ChangeTrustAsset(canonicalForm: asset.id)!
        let op = ChangeTrustOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            asset: asset,
            limit: limit ?? Decimal(922337203685.4775807))
        
        operations.append(op)
    }
    
    /// Remove a trustline for an asset so can not receive it any more.
    /// Hint: the balance of the asset in the account must be 0 for the tx to succeed.
    ///
    /// - Parameter asset: The asset for which support is removed.
    ///
    fileprivate func removeAssetSupport(asset:IssuedAssetId) {
        addAssetSupport(asset: asset, limit: 0)
    }
    
    /// Set thesholds for an account.
    /// See: https://developers.stellar.org/docs/encyclopedia/signatures-multisig#thresholds
    ///
    /// - Parameters:
    ///   - low: The low theshold level
    ///   - medium: The medium theshold level.
    ///   - high: The high theshold level.
    ///
    fileprivate func setThreshold(low:UInt32, medium:UInt32, high:UInt32) {
        
        // This only throws if only one of signer and signerWeight is passed.
        // Here we provide non of both, so it will not throw.
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
    
    /// Add new signer to the account. Use caution when adding new signers, make sure you set the
    /// correct signer weight. Otherwise, you might lock the account irreversibly.
    ///
    /// - Parameters:
    ///   - signerAddress: Stellar address of the signer that is added
    ///   - signerWeight: Signer weight
    ///
    func addAccountSigner(signerAddress:AccountKeyPair, signerWeight:UInt32) -> TxBuilder {
        super.addAccountSigner(signerAddress: signerAddress, signerWeight: signerWeight)
        return self
    }
    
    /// Remove signer from the account.
    ///
    ///  Throws `ValidationError.invalidArgument` if you try to remove the account master key.
    ///  Use `lockAccountMasterKey` instead.
    ///
    ///  - Parameter signerAddress: Stellar address of the signer to be  removed
    ///
    func removeAccountSigner(signerAddress:AccountKeyPair) throws  -> TxBuilder {
        try super.removeAccountSigner(signerAddress: signerAddress)
        return self
    }
    
    /// Add a trustline for an asset so can receive or send it.
    ///
    /// - Parameters:
    ///   - asset: The asset for which support is added.
    ///   - limit: Optional. The trust limit for the asset. If not set it defaults to max.
    ///
    func addAssetSupport(asset:IssuedAssetId, limit:Decimal?) -> TxBuilder {
        super.addAssetSupport(asset: asset, limit: limit)
        return self
    }
    
    /// Remove a trustline for an asset so can not receive it any more.
    /// Hint: the balance of the asset in the account must be 0 for the tx to succeed.
    ///
    /// - Parameter asset: The asset for which support is removed.
    ///
    func removeAssetSupport(asset:IssuedAssetId)  -> TxBuilder {
        super.removeAssetSupport(asset: asset)
        return self
    }

    /// Merges an account into a destination account.
    ///
    /// Throws `ValidationError.invalidArgument` if any of the given addresses is invalid
    ///
    /// - Important: This operation will give full control of the account to the destination account,
    /// effectively removing the merged account from the network.
    ///
    /// - Parameters:
    ///   - destinationAddress: The stellar account to merge into.
    ///   - sourceAddress: Account id of the account that is being merged. If not given then will default to the TxBuilder source account
    ///
    func accountMerge(destinationAddress:String, sourceAddress:String? = nil) throws -> TxBuilder {

        do {
            let _ = try destinationAddress.decodeMuxedAccount()
        } catch {
            throw ValidationError.invalidArgument(message: "invalid destination address (account id): \(destinationAddress)")
        }
        
        if let sourceAddress = sourceAddress {
            do {
                let _ = try sourceAddress.decodeMuxedAccount()
            } catch {
                throw ValidationError.invalidArgument(message: "invalid source address (account id): \(sourceAddress)")
            }
        }
        
        // this only throws if the accounts are invalid.
        let op = try! AccountMergeOperation(
            destinationAccountId: destinationAddress,
            sourceAccountId: sourceAddress ?? sourceAccount.keyPair.accountId)
        
        operations.append(op)
        return self
    }
    
    /// Set thesholds for an account.
    /// See: https://developers.stellar.org/docs/encyclopedia/signatures-multisig#thresholds
    ///
    /// - Parameters:
    ///   - low: The low theshold level
    ///   - medium: The medium theshold level.
    ///   - high: The high theshold level.
    ///
    func setThreshold(low:UInt32, medium:UInt32, high:UInt32) -> TxBuilder {
        super.setThreshold(low: low, medium: medium, high: high)
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
    
    /// Add new signer to the account. Use caution when adding new signers, make sure you set the
    /// correct signer weight. Otherwise, you might lock the account irreversibly.
    ///
    /// - Parameters:
    ///   - signerAddress: Stellar address of the signer that is added
    ///   - signerWeight: Signer weight
    ///
    func addAccountSigner(signerAddress:AccountKeyPair, signerWeight:UInt32) -> SponsoringBuilder {
        super.addAccountSigner(signerAddress: signerAddress, signerWeight: signerWeight)
        return self
    }
    
    /// Remove signer from the account.
    ///
    ///  Throws `ValidationError.invalidArgument` if you try to remove the account master key.
    ///  Use `lockAccountMasterKey` instead.
    ///
    ///  - Parameter signerAddress: Stellar address of the signer to be  removed
    ///
    func removeAccountSigner(signerAddress:AccountKeyPair) throws  -> SponsoringBuilder {
        try super.removeAccountSigner(signerAddress: signerAddress)
        return self
    }
    
    /// Add a trustline for an asset so can receive or send it.
    ///
    /// - Parameters:
    ///   - asset: The asset for which support is added.
    ///   - limit: Optional. The trust limit for the asset. If not set it defaults to max.
    ///
    func addAssetSupport(asset:IssuedAssetId, limit:Decimal?) -> SponsoringBuilder {
        super.addAssetSupport(asset: asset, limit: limit)
        return self
    }
    
    /// Remove a trustline for an asset so can not receive it any more.
    /// Hint: the balance of the asset in the account must be 0 for the tx to succeed.
    ///
    /// - Parameter asset: The asset for which support is removed.
    ///
    func removeAssetSupport(asset:IssuedAssetId)  -> SponsoringBuilder {
        super.removeAssetSupport(asset: asset)
        return self
    }
    
    /// Set thesholds for an account.
    /// See: https://developers.stellar.org/docs/encyclopedia/signatures-multisig#thresholds
    ///
    /// - Parameters:
    ///   - low: The low theshold level
    ///   - medium: The medium theshold level.
    ///   - high: The high theshold level.
    ///
    func setThreshold(low:UInt32, medium:UInt32, high:UInt32) -> SponsoringBuilder {
        super.setThreshold(low: low, medium: medium, high: high)
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


