//
//  Sep24.swift
//  
//
//  Created by Christian Rogobete on 08.01.25.
//

import Foundation
import stellarsdk

/// Interactive flow for deposit and withdrawal using [SEP-24](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md).
public class Sep24 {
    
    internal var anchor:Anchor
    
    internal init(anchor:Anchor) {
        self.anchor = anchor
    }
    
    
    /// Get SEP-24 anchor information.
    public var info: Sep24Info {
        get async throws {
            return try await anchor.infoHolder.serviceInfo
        }
    }
    
    /// Initiates a deposit request.
    ///
    /// - Parameters:
    ///   - assetId: Asset to deposit
    ///   - authToken: Authentication token for the request.
    ///   - extraFields: Additional fields for the request. E.g. SEP-9 fields
    ///   - extraFiles: Additional files for the request. E.g. SEP-9 files
    ///   - destinationAccount: The destination account (id) for the deposit.
    ///   - destinationMemo: Memo information for the destination account.
    ///   - destinationMemoType: Type of the memo if memo value provied.
    ///   
    public func deposit(assetId:StellarAssetId,
                        authToken:AuthToken,
                        extraFields:[String:String]? = nil,
                        extraFiles:[String:Data]? = nil,
                        destinationAccount:String? = nil,
                        destinationMemo:String? = nil,
                        destinationMemoType:MemoType? = nil) async throws -> InteractiveFlowResponse {
        
        let tomlInfo = try await anchor.info
        
        guard let transferServerSep24 = tomlInfo.services.sep24?.transferServerSep24,
                let sep24Service = tomlInfo.services.sep24 else {
            throw AnchorError.interactiveFlowNotSupported
        }
        
        if !sep24Service.hasAuth {
            throw AnchorAuthError.notSupported
        }
        
        var assetCode:String = assetId.id
        var assetIssuer:String? = nil
        if let issuedAsset = assetId as? IssuedAssetId {
            assetCode = issuedAsset.code
            assetIssuer = issuedAsset.issuer
        }
        
        var request = Sep24DepositRequest(jwt: authToken.jwt, assetCode: assetCode)
        request.assetIssuer = assetIssuer
        request.customFields = extraFields
        request.customFiles = extraFiles
        request.account = destinationAccount
        request.memo = destinationMemo
        if let destinationMemoType = destinationMemoType {
            request.memoType = destinationMemoType.rawValue
        }
        
        guard let asset = try await info.depositServiceAsset(assetId: assetId) else {
            throw InteractiveFlowError.assetNotAcceptedForDeposit(assetId: assetId)
        }
        if !asset.enabled {
            throw InteractiveFlowError.assetNotEnabledForDeposit(assetId: assetId)
        }
        
        let interactiveService = InteractiveService(serviceAddress: transferServerSep24)
        let response = await interactiveService.deposit(request: request)
        switch response {
        case .success(let response):
            return InteractiveFlowResponse(response: response)
        case .failure(let error):
            throw error
        }
    }
    
    /// Initiates a withdrawal request.
    ///
    /// - Parameters:
    ///   - assetId: Asset to withdraw.
    ///   - authToken: Authentication token for the request.
    ///   - extraFields: Additional fields for the request. E.g. SEP-9 fields
    ///   - extraFiles: Additional files for the request. E.g. SEP-9 files
    ///
    public func withdraw(assetId:StellarAssetId,
                         authToken:AuthToken,
                         extraFields:[String:String]? = nil,
                         extraFiles:[String:Data]? = nil,
                         withdrawalAccount: String? = nil) async throws -> InteractiveFlowResponse {
        let tomlInfo = try await anchor.info
        
        guard let transferServerSep24 = tomlInfo.services.sep24?.transferServerSep24,
                let sep24Service = tomlInfo.services.sep24 else {
            throw AnchorError.interactiveFlowNotSupported
        }
        
        if !sep24Service.hasAuth {
            throw AnchorAuthError.notSupported
        }
        
        var assetCode:String = assetId.id
        var assetIssuer:String? = nil
        if let issuedAsset = assetId as? IssuedAssetId {
            assetCode = issuedAsset.code
            assetIssuer = issuedAsset.issuer
        }
        
        var request = Sep24WithdrawRequest(jwt: authToken.jwt, assetCode: assetCode)
        request.assetIssuer = assetIssuer
        request.customFields = extraFields
        request.customFiles = extraFiles
        request.account = withdrawalAccount
        
        guard let asset = try await info.withdrawServiceAsset(assetId: assetId) else {
            throw InteractiveFlowError.assetNotAcceptedForWithdrawal(assetId: assetId)
        }
        if !asset.enabled {
            throw InteractiveFlowError.assetNotEnabledForWithdrawal(assetId: assetId)
        }
        
        let interactiveService = InteractiveService(serviceAddress: transferServerSep24)
        let response = await interactiveService.withdraw(request: request)
        switch response {
        case .success(let response):
            return InteractiveFlowResponse(response: response)
        case .failure(let error):
            throw error
        }
    }
    
    /// Get single transaction's current status and details from the anchor.
    ///
    /// - Important: One of the Id parameters must be provided.
    ///
    /// - Parameters:
    ///   - authToken: Authentication token for the request.
    ///   - transactionId: The anchor's transaction Id.
    ///   - stellarTransactionId: The Stellar transaction Id.
    ///   - externalTransactionId: The external transaction Id.
    ///
    public func getTransactionBy(authToken:AuthToken,
                                 transactionId:String? = nil,
                                 stellarTransactionId:String? = nil,
                                 externalTransactionId:String? = nil) async throws -> InteractiveFlowTransaction {
        
        if (transactionId == nil &&
            stellarTransactionId == nil &&
            externalTransactionId == nil) {
            throw ValidationError.invalidArgument(message: "One of transactionId, stellarTransactionId or externalTransactionId is required.")
        }
        
        let tomlInfo = try await anchor.info
        
        guard let transferServerSep24 = tomlInfo.services.sep24?.transferServerSep24,
                let sep24Service = tomlInfo.services.sep24 else {
            throw AnchorError.interactiveFlowNotSupported
        }
        
        if !sep24Service.hasAuth {
            throw AnchorAuthError.notSupported
        }
        
        let interactiveService = InteractiveService(serviceAddress: transferServerSep24)
        var request = Sep24TransactionRequest(jwt: authToken.jwt)
        if let transactionId = transactionId {
            request.id = transactionId
        } else if let stellarTransactionId = stellarTransactionId {
            request.stellarTransactionId = stellarTransactionId
        } else if let externalTransactionId = externalTransactionId {
            request.externalTransactionId = externalTransactionId
        }
        request.lang = anchor.lang
        
        let response = await interactiveService.getTransaction(request: request)
        switch response {
        case .success(let response):
            return try InteractiveFlowTransaction.fromTx(tx: response.transaction)
        case .failure(let error):
            throw error
        }
        
    }
    
    /// Get account's transactions specified by asset and other params.
    ///
    ///
    /// - Parameters:
    ///   - authToken: Authentication token for the request.
    ///   - asset: The target asset to query for
    ///   - noOlderThen: The response should contain transactions starting on or after this date & time.
    ///   - limit: The response should contain at most 'limit' transactions.
    ///   - kind: The kind of transaction that is desired. ( 'deposit' or  'withdrawal').
    ///   - pagingId: The response should contain transactions starting prior to this ID (exclusive).
    ///
    public func getTransactionsForAsset(authToken:AuthToken,
                                        asset:AssetId,
                                        noOlderThen:Date? = nil,
                                        limit:Int? = nil,
                                        kind:TransactionKind? = nil,
                                        pagingId:String? = nil) async throws -> [InteractiveFlowTransaction] {
        
        let tomlInfo = try await anchor.info
        
        guard let transferServerSep24 = tomlInfo.services.sep24?.transferServerSep24 else {
            throw AnchorError.interactiveFlowNotSupported
        }
        
        let interactiveService = InteractiveService(serviceAddress: transferServerSep24)
        var assetCode = asset.id
        if let asset  = asset as? IssuedAssetId {
            assetCode = asset.code
        }
        
        var request = Sep24TransactionsRequest(jwt: authToken.jwt, assetCode: assetCode)
        request.noOlderThan = noOlderThen
        request.lang = anchor.lang
        request.limit = limit
        if let kind = kind {
            request.kind = kind.rawValue
        }
        request.pagingId = pagingId
        
        let response = await interactiveService.getTransactions(request: request)
        switch response {
        case .success(let response):
            var result:[InteractiveFlowTransaction] = []
            for tx in response.transactions {
                result.append(try InteractiveFlowTransaction.fromTx(tx: tx))
            }
            return result
        case .failure(let error):
            throw error
        }
    }
    
    /// Creates new transaction watcher.
    /// You can pass the pollInterval in which requests to the Anchor are being made.
    /// If not specified, it defaults to 5 seconds. You can also pass your own exceptionHandler.
    /// By default, RetryExceptionHandler is being used.
    ///
    /// - Parameters:
    ///   - pollDelay: Interval in which requests to the Anchor are being made. E.g 5 (seconds)
    ///   - exceptionHandler: WalletExceptionHandler that handles any exceptions that may occur during the polling. E.g. RetryExceptionHandler
    ///   
    public func watcher(pollDelay:Double = 5.0,
                        exceptionHandler:WalletExceptionHandler = RetryExceptionHandler()) -> Watcher {
        
        return Watcher(anchor: anchor, pollDelay: pollDelay, exceptionHandler: exceptionHandler, watcherKind: WatcherKind.sep24)
    }
}
