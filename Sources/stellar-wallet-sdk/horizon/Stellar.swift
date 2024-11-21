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
    internal var config:Config
    
    /// AccountService instance for managing Stellar accounts.
    public var account:AccountService
    
    /// Creates a new instance of the Stellar class.
    /// 
    /// - Parameter config: Configuration object.
    ///
    internal init(config: Config) {
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
        let txTimeout = timeout ?? config.stellar.txTimeout
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
    
    /// Signs the fee bump transaction with the given signing key pair.
    ///
    /// - Parameters:
    ///   - feeBumpTx: The  fee bump transaction to sign
    ///   - keyPair: The keyPair to sign the transaction with.
    ///
    public func sign(feeBumpTx:stellarsdk.FeeBumpTransaction, keyPair:SigningKeyPair) {
        try! feeBumpTx.sign(keyPair: keyPair.keyPair, network: config.stellar.network)
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
    
    /// Submits a signed fee bump transaction to the server. If the submission fails with status 504 indicating a timeout error, it will automatically retry.
    /// Retruns `true` if the transaction was successfully submitted.
    ///
    /// This function throws a horizon request error (stellarsdk.HorizonRequestError) if any error occured while sending the transaction to the stellar network.
    /// It can also throw a validation error (ValidationError.invalidArgument) if the destination requires a memo but no memo was found in the transaction.
    ///
    /// - Parameter signedTransaction: The signed fee bump transaction to submit.
    ///
    public func submitTransaction(signedFeeBumpTransaction: stellarsdk.FeeBumpTransaction) async throws -> Bool {
        let responseEnum = await server.transactions.submitFeeBumpTransaction(transaction: signedFeeBumpTransaction)
        switch responseEnum {
        case .success(_):
            return true
        case .destinationRequiresMemo(let destinationAccountId):
            throw ValidationError.invalidArgument(message: ("account \(destinationAccountId) requires memo"))
        case .failure(let error):
            switch error {
            case .timeout(_, _):
                // resubmit
                return try await submitTransaction(signedFeeBumpTransaction: signedFeeBumpTransaction)
          default:
                throw error
            }
        }
    }
    
    /// Creates and returns a FeeBumpTransaction (see https://developers.stellar.org/docs/encyclopedia/fee-bump-transactions).
    /// for the given feeAddress that will pay the transaction's fee and the transaction for which fee should be paid (inner transaction).
    /// If the optional parameter baseFee If not specified,  config.stellar.baseFee will be used.
    ///
    /// - Parameters:
    ///   - feeAddress: Address that will pay the transaction's fee
    ///   - transaction: The transaction for which fee should be paid (inner transaction).
    ///   - baseFee: The base fee for the fee bump transaction. Must be more then the min. base fee (100) and more than the inner transaction base fee.
    ///
    /// Throws a validation error (ValidationError.invalidArgument) if the given base fee is lower then the min base fee (100) or lower then the inner transaction base fee.
    ///
    public func makeFeeBump(feeAddress: AccountKeyPair, transaction: stellarsdk.Transaction, baseFee:UInt32? = nil) throws -> stellarsdk.FeeBumpTransaction {
        let txBaseFee = baseFee ?? config.stellar.baseFee
        let account = try! MuxedAccount(accountId: feeAddress.address) // this only throws if address is invalid and it can not happen here.
        do {
            let fee = UInt64(txBaseFee * UInt32(transaction.operations.count + 1))
            return try stellarsdk.FeeBumpTransaction(sourceAccount:account, fee: fee, innerTransaction: transaction)
        } catch {
            // FeeBumpTransactionError.feeSmallerThanBaseFee or FeeBumpTransactionError.feeSmallerThanInnerTransactionFee
            throw ValidationError.invalidArgument(message: error.localizedDescription)
        }
    }
    
    /// Decode transaction or fee bump transaction from a xdr envelope base 64 string.
    ///
    /// - Parameter xdr: The xdr transaction envelope or fee bump transaction envelope base 64 string.
    ///
    public func decodeTransaction(xdr:String) -> DecodedTransactionEnum {
        do {
            let transactionEnvelopeXdr = try stellarsdk.TransactionEnvelopeXDR(xdr: xdr)
            switch transactionEnvelopeXdr {
            case .feeBump(let feeBumpTransactionEnvelopeXDR):
                return DecodedTransactionEnum.feeBumpTransaction(feeBumpTx: try buildFeeBumpTransaction(envelopeXDR: feeBumpTransactionEnvelopeXDR))
            default:
                return DecodedTransactionEnum.transaction(tx: try stellarsdk.Transaction(envelopeXdr: xdr))
            }
        } catch {
            return DecodedTransactionEnum.invalidXdrErr
        }
    }
    
    // TODO: move this logic to horizon sdk
    private func buildFeeBumpTransaction(envelopeXDR:stellarsdk.FeeBumpTransactionEnvelopeXDR) throws -> stellarsdk.FeeBumpTransaction {
        let feeBumpSourceAccount = try stellarsdk.MuxedAccount(accountId: envelopeXDR.tx.sourceAccount.ed25519AccountId,
                                                               id:envelopeXDR.tx.sourceAccount.id)
        let innerTxEnvelopeXdr = TransactionEnvelopeXDR.v1(envelopeXDR.tx.innerTx.tx)
        guard let innerTxEnvB64 = innerTxEnvelopeXdr.xdrEncoded else {
            throw ValidationError.invalidArgument(message: "invalid xdr")
        }
        let innerTx = try stellarsdk.Transaction(envelopeXdr: innerTxEnvB64)
        let feeBumpTx = try stellarsdk.FeeBumpTransaction(sourceAccount: feeBumpSourceAccount, 
                                                          fee: envelopeXDR.tx.fee,
                                                          innerTransaction: innerTx)
        for signature in envelopeXDR.signatures {
            feeBumpTx.addSignature(signature: signature)
        }
        return feeBumpTx
    }
    
    /// Submit transaction with a fee increase. Recommended way of creating transactions. This method repeatedly tries to submit transaction, until it's successful.
    /// When [timeout] is reached, base fee will be increased on the [baseFeeIncrease] value.
    ///
    /// - Parameters:
    ///   - sourceAddress: The source account keypair. It is used as the transactions source account and also used for signing the transaction
    ///   - timeout: transaction timeout in seconds
    ///   - baseFeeIncrease: amount on which fee will be increased after timeout is reached
    ///   - maxBaseFee: The max fee allowed (stroops) of the transaction. Increased fee is limited by this value.
    ///   - buildingFunction: Function for building the operations of the transactions.
    ///   - baseFee: The base fee (stroops) of the transaction. If not specified, the default configuration value [StellarConfiguration.baseFee] will be used
    ///   - memo: Optional transaction memo.
    ///
    public func submitWithFeeIncrease(sourceAddress: SigningKeyPair,
                                      timeout:UInt32,
                                      baseFeeIncrease: UInt32,
                                      maxBaseFee: UInt32,
                                      buildingFunction:(_:TxBuilder) -> TxBuilder,
                                      baseFee:UInt32? = nil,
                                      memo:stellarsdk.Memo? = nil) async throws -> Bool {
        return try await submitWithFeeIncreaseAndSignerFunction(sourceAddress: sourceAddress,
                                                                timeout: timeout,
                                                                baseFeeIncrease: baseFeeIncrease,
                                                                maxBaseFee: maxBaseFee,
                                                                buildingFunction: buildingFunction,
                                                                signerFunction: {(tx) in sign(tx: tx, keyPair: sourceAddress)})
        
    }
    
    /// Submit transaction with a fee increase. Recommended way of creating transactions. This method repeatedly tries to submit transaction, until it's successful.
    /// When [timeout] is reached, base fee will be increased on the [baseFeeIncrease] value.
    ///
    /// - Parameters:
    ///   - sourceAddress: The source account keypair. It is used as the transactions source account.
    ///   - timeout: transaction timeout in seconds
    ///   - baseFeeIncrease: amount on which fee will be increased after timeout is reached
    ///   - maxBaseFee: The max fee allowed (stroops) of the transaction. Increased fee is limited by this value.
    ///   - buildingFunction: Function for building the operations of the transactions.
    ///   - signerFunction: Function that will be used to sign the transaction
    ///   - baseFee: The base fee (stroops) of the transaction. If not specified, the default configuration value [StellarConfiguration.baseFee] will be used
    ///   - memo: Optional transaction memo.
    ///
    public func submitWithFeeIncreaseAndSignerFunction(sourceAddress: AccountKeyPair,
                                                       timeout:UInt32,
                                                       baseFeeIncrease: UInt32,
                                                       maxBaseFee: UInt32,
                                                       buildingFunction:(_:TxBuilder) -> TxBuilder,
                                                       signerFunction:(_:stellarsdk.Transaction) -> Void,
                                                       baseFee:UInt32? = nil,
                                                       memo:stellarsdk.Memo? = nil) async throws -> Bool {
        
        var txBuilder = try await transaction(sourceAddress: sourceAddress, timeout: timeout, baseFee: baseFee, memo: memo)
        
        txBuilder = buildingFunction(txBuilder)
        
        let tx = try txBuilder.build()
        signerFunction(tx)
        
        let responseEnum = await server.transactions.submitTransaction(transaction: tx)
        switch responseEnum {
        case .success(_):
            return true
        case .destinationRequiresMemo(let destinationAccountId):
            throw ValidationError.invalidArgument(message: ("account \(destinationAccountId) requires memo"))
        case .failure(let error):
            switch error {
            case .timeout(_, _):
                // Transaction has expired, Increasing fee.
                let newFee = min(maxBaseFee, tx.fee + baseFeeIncrease)
                print("Transaction has expired. Increasing fee to \(newFee) Stroops.")
                return try await submitWithFeeIncreaseAndSignerFunction(sourceAddress: sourceAddress, 
                                                                        timeout: timeout,
                                                                        baseFeeIncrease: baseFeeIncrease,
                                                                        maxBaseFee: maxBaseFee,
                                                                        buildingFunction: buildingFunction,
                                                                        signerFunction: signerFunction)
                
          default:
                throw error
            }
        }
    }
    
    /// Fetches available paths on the Stellar network between the destination account, and the source asset to be send by the source account
    /// considering the given source amount.
    ///
    /// - Parameters:
    ///   - destinationAddress: The account id of the destination account that should receive the funds
    ///   - sourceAssetId: The source asset to find the path for
    ///   - sourceAmount: The source asset amount to find the path for
    ///
    public func findStrictSendPathForDestinationAddress(destinationAddress: String,
                                                        sourceAssetId: StellarAssetId,
                                                        sourceAmount: String) async throws -> [PaymentPath] {
        
        let sourceAssetParams = getAssetParams(assetId: sourceAssetId)
        let responseEnum = await server.paymentPaths.strictSend(sourceAmount: sourceAmount,
                                                                sourceAssetType: sourceAssetParams.assetType,
                                                                sourceAssetCode: sourceAssetParams.assetCode,
                                                                sourceAssetIssuer: sourceAssetParams.assetIssuer,
                                                                destinationAccount: destinationAddress)
        switch responseEnum {
        case .success(let details):
            var paths:[PaymentPath] = []
            details.records.forEach { item in
                let path = PaymentPath.fromPathResponse(response: item)
                paths.append(path)
            }
            return paths
        case .failure(let error):
            throw error
        }
    }
    
    /// Fetches available paths on the Stellar network between the source asset sent by the source account
    /// and the given destinationAssets considering the source asset amount.
    ///
    /// - Parameters:
    ///   - destinationAssets: List of assets that the destination account can receive
    ///   - sourceAssetId: The source asset to find the path for
    ///   - sourceAmount: The source asset amount to find the path for
    ///
    public func findStrictSendPathForDestinationAssets(destinationAssets: [StellarAssetId],
                                                       sourceAssetId: StellarAssetId,
                                                       sourceAmount: String) async throws -> [PaymentPath] {
        
        let sourceAssetParams = getAssetParams(assetId: sourceAssetId)
        let responseEnum = await server.paymentPaths.strictSend(sourceAmount: sourceAmount,
                                                                sourceAssetType: sourceAssetParams.assetType,
                                                                sourceAssetCode: sourceAssetParams.assetCode,
                                                                sourceAssetIssuer: sourceAssetParams.assetIssuer,
                                                                destinationAssets: encodeAssets(assets: destinationAssets))
        switch responseEnum {
        case .success(let details):
            var paths:[PaymentPath] = []
            details.records.forEach { item in
                let path = PaymentPath.fromPathResponse(response: item)
                paths.append(path)
            }
            return paths
        case .failure(let error):
            throw error
        }
    }
    
    /// Fetches available payment paths on the Stellar network between the assets hold by the source account and the
    /// the destination asset considering the given destination amount to be received by the destination account.
    ///
    /// - Parameters:
    ///   - sourceAddress: The account id of the account that wants to send the funds
    ///   - destinationAssetId: The destination asset to find the path for
    ///   - destinationAmount: The destination asset amount to find the path for
    ///
    public func findStrictReceivePathForSourceAddress(sourceAddress: String,
                                                      destinationAssetId: StellarAssetId,
                                                      destinationAmount: String) async throws -> [PaymentPath] {
        
        let destinationAssetParams = getAssetParams(assetId: destinationAssetId)
        let responseEnum = await server.paymentPaths.strictReceive(sourceAccount: sourceAddress,
                                                                   destinationAssetType: destinationAssetParams.assetType,
                                                                   destinationAssetCode: destinationAssetParams.assetCode,
                                                                   destinationAssetIssuer: destinationAssetParams.assetIssuer,
                                                                   destinationAmount: destinationAmount)
        
        switch responseEnum {
        case .success(let details):
            var paths:[PaymentPath] = []
            details.records.forEach { item in
                let path = PaymentPath.fromPathResponse(response: item)
                paths.append(path)
            }
            return paths
        case .failure(let error):
            throw error
        }
    }
    
    /// Fetches available payment paths on the Stellar network between the given source assets and the
    /// the destination asset considering the given destination amount to be received by the destination account.
    ///
    /// - Parameters:
    ///   - sourceAssets: The assets to find the paths for
    ///   - destinationAssetId: The destination asset to find the path for
    ///   - destinationAmount: The destination asset amount to find the path for
    ///
    public func findStrictReceivePathForSourceAssets(sourceAssets: [StellarAssetId],
                                                     destinationAssetId: StellarAssetId,
                                                     destinationAmount: String) async throws -> [PaymentPath] {
        
        let destinationAssetParams = getAssetParams(assetId: destinationAssetId)
        let responseEnum = await server.paymentPaths.strictReceive(sourceAssets: encodeAssets(assets: sourceAssets),
                                                                   destinationAssetType: destinationAssetParams.assetType,
                                                                   destinationAssetCode: destinationAssetParams.assetCode,
                                                                   destinationAssetIssuer: destinationAssetParams.assetIssuer,
                                                                   destinationAmount: destinationAmount)
        
        switch responseEnum {
        case .success(let details):
            var paths:[PaymentPath] = []
            details.records.forEach { item in
                let path = PaymentPath.fromPathResponse(response: item)
                paths.append(path)
            }
            return paths
        case .failure(let error):
            throw error
        }
    }
    
    private func encodeAssets(assets:[StellarAssetId]) -> String {
        var result = ""
        assets.forEach { asset in
            if result != "" {
                result += ","
            }
            result += asset.toAsset().toCanonicalForm()
        }
        return result
    }
    
    private func getAssetParams(assetId: StellarAssetId) -> AssetParams {
        var assetType = "native"
        var assetCode:String? = nil
        var assetIssuer:String? = nil
        
        let asset = assetId.toAsset()
        switch asset.type {
        case AssetType.ASSET_TYPE_CREDIT_ALPHANUM4:
            assetType = "credit_alphanum4"
            assetCode = asset.code
            assetIssuer = asset.issuer!.accountId
        case AssetType.ASSET_TYPE_CREDIT_ALPHANUM4:
            assetType = "credit_alphanum12"
            assetCode = asset.code
            assetIssuer = asset.issuer!.accountId
        default:
            break
        }
        return AssetParams(assetType: assetType, assetCode: assetCode, assetIssuer: assetIssuer)
    }
}

public class PaymentPath {
    let sourceAmount:String
    let sourceAsset:StellarAssetId
    let destinationAmount: String
    let destinationAsset: StellarAssetId
    let path:[StellarAssetId]
    
    init(sourceAmount: String,
         sourceAsset:StellarAssetId,
         destinationAmount:String,
         destinationAsset: StellarAssetId,
         path:[StellarAssetId]) {
        
        self.sourceAmount = sourceAmount
        self.sourceAsset = sourceAsset
        self.destinationAmount = destinationAmount
        self.destinationAsset = destinationAsset
        self.path = path
    }
    
    static func fromPathResponse(response: stellarsdk.PaymentPathResponse) -> PaymentPath {
        let sourceAsset = response.sourceAssetType == "native" ? NativeAssetId() : try! IssuedAssetId(code: response.sourceAssetCode!, issuer: response.sourceAssetIssuer!)
        let sourceAmount = response.sourceAmount
        let destinationAsset = response.destinationAssetType == "native" ? NativeAssetId() : try! IssuedAssetId(code: response.destinationAssetCode!, issuer: response.destinationAssetIssuer!)
        let destinationAmount = response.destinationAmount
        var path:[StellarAssetId] = []
        response.path.forEach { item in
            let asset = item.assetType == "native" ? NativeAssetId() : try! IssuedAssetId(code: item.assetCode!, issuer: item.assetIssuer!)
            path.append(asset)
        }
        return PaymentPath(sourceAmount: sourceAmount, 
                           sourceAsset: sourceAsset,
                           destinationAmount: destinationAmount,
                           destinationAsset: destinationAsset,
                           path: path)
    }
}

private class AssetParams {
    let assetType:String
    let assetCode:String?
    let assetIssuer:String?
    
    init(assetType: String, assetCode:String? = nil, assetIssuer:String? = nil) {
        self.assetType = assetType
        self.assetCode = assetCode
        self.assetIssuer = assetIssuer
    }
}

public enum DecodedTransactionEnum {
    case transaction(tx: stellarsdk.Transaction)
    case feeBumpTransaction(feeBumpTx: stellarsdk.FeeBumpTransaction)
    case invalidXdrErr
}
