//
//  TxBuilder.swift
//
//
//  Created by Christian Rogobete on 23.09.24.
//

import Foundation
import stellarsdk

public class CommonTxBuilder<T> {
    var sourceAccount:TransactionAccount
    var operations:[stellarsdk.Operation]
    var memo:stellarsdk.Memo?
    var timebounds:stellarsdk.TimeBounds?
    var baseFee:UInt32?
    
    fileprivate init(sourceAccount:TransactionAccount, operations:[stellarsdk.Operation]) {
        self.sourceAccount = sourceAccount
        self.operations = operations
    }
    
    func addAccountSigner(signerAddress:AccountKeyPair, signerWeight:UInt32) -> CommonTxBuilder<T> {
        let accSignerKey =  try! Signer.ed25519PublicKey(accountId: signerAddress.address)
        
        let op = try! SetOptionsOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            signer: accSignerKey,
            signerWeight: signerWeight)
        
        operations.append(op)
        
        return self
    }
    
    func removeAccountSigner(signerAddress:AccountKeyPair) throws -> CommonTxBuilder<T> {
        if (signerAddress.address == sourceAccount.keyPair.accountId) {
            throw ValidationError.invalidArgument(
                message: "This method can't be used to remove master signer key, call the lockAccountMasterKey method instead")
        }
        
        return addAccountSigner(signerAddress: signerAddress, signerWeight: 0)
    }
    
    func lockAccountMasterKey() -> CommonTxBuilder {
        
        let op = try! SetOptionsOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            masterKeyWeight: 0)
        
        operations.append(op)
        
        return self
    }
    
    func addAssetSupport(asset:IssuedAssetId, limit:Decimal?) -> CommonTxBuilder<T> {
        let asset = ChangeTrustAsset(canonicalForm: asset.id)!
        let op = ChangeTrustOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            asset: asset,
            limit: limit ?? Decimal(922337203685.4775807))
        
        operations.append(op)
        
        return self
    }
    
    func removeAssetSupport(asset:IssuedAssetId) -> CommonTxBuilder<T> {
        let asset = ChangeTrustAsset(canonicalForm: asset.id)!
        let op = ChangeTrustOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            asset: asset,
            limit: Decimal(0))
        
        operations.append(op)
        
        return self
    }
    
    func setThreshold(low:UInt32, medium:UInt32, high:UInt32) -> CommonTxBuilder<T> {
        let op = try! SetOptionsOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            lowThreshold: low,
            mediumThreshold: medium,
            highThreshold: high)
        
        operations.append(op)
        
        return self
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


public class TxBuilder:CommonTxBuilder<TxBuilder> {

    public init(sourceAccount:TransactionAccount) {
        super.init(sourceAccount: sourceAccount, operations: [])
    }
    
    func setMemo(memo:stellarsdk.Memo) -> TxBuilder  {
        self.memo = memo
        return self
    }
    
    func setTimebounds(timebounds:stellarsdk.TimeBounds) -> TxBuilder  {
        self.timebounds = timebounds
        return self
    }
    
    func setBaseFee(baseFeeInStoops:UInt32) -> TxBuilder  {
        self.baseFee = baseFeeInStoops
        return self
    }
    
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
    
    public func addOperation(operation:stellarsdk.Operation) -> TxBuilder {
        operations.append(operation)
        return self
    }
    
    public func sponsoring(sponsorAccount:AccountKeyPair, using buildingFunction:(_:SponsoringBuilder) -> Void, sponsoredAccount:AccountKeyPair?) -> TxBuilder {
        let sponsoredAccountKp = sponsoredAccount?.keyPair ?? sourceAccount.keyPair
        let beginSponsorshipOp = BeginSponsoringFutureReservesOperation(sponsoredAccountId: sponsoredAccountKp.accountId, sponsoringAccountId: sponsorAccount.address)
        operations.append(beginSponsorshipOp)
        
        let builderAccount = Account(keyPair: sponsoredAccountKp, sequenceNumber: 0)
        let opBuilder = SponsoringBuilder(sourceAccount: builderAccount, sponsorAccount: sponsorAccount)
        buildingFunction(opBuilder)
        operations.append(contentsOf: opBuilder.operations)
        
        let endSponsoringOp = EndSponsoringFutureReservesOperation(sponsoredAccountId: sponsoredAccountKp.accountId)
        operations.append(endSponsoringOp)
        return self
    }

}

public class SponsoringBuilder:CommonTxBuilder<SponsoringBuilder> {

    var sponsorAccount:AccountKeyPair
    
    public init(sourceAccount:TransactionAccount, sponsorAccount:AccountKeyPair) {
        self.sponsorAccount = sponsorAccount
        super.init(sourceAccount: sourceAccount, operations: [])
    }
    
    public func createAccount(newAccount:AccountKeyPair, startingBalance:Decimal = Decimal(0)) throws -> SponsoringBuilder {
        if (startingBalance < Decimal(0)) {
            throw ValidationError.invalidArgument(message: "Starting balance must be at least 0 XLM for sponsored accounts")
        }
        let op = CreateAccountOperation(
            sourceAccountId: sourceAccount.keyPair.accountId,
            destination: newAccount.keyPair,
            startBalance: startingBalance)
        
        operations.append(op)
        
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


