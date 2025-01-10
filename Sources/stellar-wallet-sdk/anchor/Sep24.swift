//
//  Sep24.swift
//  
//
//  Created by Christian Rogobete on 08.01.25.
//

import Foundation
import stellarsdk

public class Sep24 {
    internal var anchor:Anchor
    
    internal init(anchor:Anchor) {
        self.anchor = anchor
    }
    
    public var serviceInfo: AnchorServiceInfo {
        get async throws {
            return try await anchor.infoHolder.serviceInfo
        }
    }
    
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
        
        guard let asset = try await serviceInfo.depositServiceAsset(assetId: assetId) else {
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
    
    public func withdraw(assetId:StellarAssetId,
                                 authToken:AuthToken,
                                 extraFields:[String:String]? = nil,
                                 extraFiles:[String:Data]? = nil) async throws -> InteractiveFlowResponse {
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
        
        guard let asset = try await serviceInfo.withdrawServiceAsset(assetId: assetId) else {
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
    
    public func getTransaction(transactionId:String, authToken:AuthToken) async throws -> InteractiveFlowTransaction {
        
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
        request.id = transactionId
        request.lang = anchor.lang
        let response = await interactiveService.getTransaction(request: request)
        switch response {
        case .success(let response):
            return try InteractiveFlowTransaction.fromTx(tx: response.transaction)
        case .failure(let error):
            throw error
        }
        
    }
    
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
    
    public func getTransactionsForAsset(asset:AssetId,
                                        authToken:AuthToken,
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
}
