//
//  Sep12.swift
//
//
//  Created by Christian Rogobete on 18.02.25.
//

import Foundation
import stellarsdk

/// Implements SEP-0012 - KYCAPI.
/// See <https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md" target="_blank">KYC API.</a>
public class Sep12 {
    var authToken:AuthToken
    var kycService: KycService
    
    /// Constructor
    ///
    /// - Parameters:
    ///   - serviceAddress: the serviceAddress from the server (KYC_SERVER or  TRANSFER_SERVER in stellar.toml).
    ///   - authToken: SEP-10 Authentication token for the request.
    ///
    init(serviceAddress:String, authToken:AuthToken) {
        self.authToken = authToken
        self.kycService = KycService(kycServiceAddress: serviceAddress)
    }
    
    /// Get customer information by different parameters. See Sep-12.
    /// If all parameters are null, it loads by auth token only.
    ///
    /// - Parameters:
    ///   - id: id of the customer received when added the customer
    ///   - account: stellar account id of the customer. deprecated
    ///   - memo: memo that uniquely identifies the customer. If a memo is present in the decoded SEP-10 JWT it must match this parameter value.
    ///   - type: the type of action the customer is being KYCd for
    ///   - transactionId: the transaction id with which the customer's info is associated.
    ///   - lang: Language code specified using ISO 639-1.
    ///
    public func get(id:String? = nil,
                    account:String? = nil,
                    memo:String? = nil,
                    type:String? = nil,
                    transactionId:String? = nil,
                    lang:String? = nil) async throws -> GetCustomerResponse {
        
        var request = GetCustomerInfoRequest(jwt: authToken.jwt)
        request.id = id
        request.account = account
        request.memo = memo
        request.type = type
        request.transactionId = transactionId
        request.lang = lang
        
        let responseEnum = await kycService.getCustomerInfo(request: request)
        switch responseEnum {
        case .success(let response):
            return GetCustomerResponse(info: response)
        case .failure(let error):
            throw error
        }
    }
    
    /// Get customer information only by using the auth token.
    public func getByAuthTokenOnly() async throws -> GetCustomerResponse {
        return try await get()
    }
    
    /// Get customer information by customer [id] and [type].
    ///
    /// - Parameters:
    ///   - id: id of the customer received when added the customer
    ///   - type: the type of action the customer is being KYCd for
    public func getByIdAndType(id:String,
                               type:String) async throws -> GetCustomerResponse {
        return try await get(id:id, type: type)
    }
    
    /// Create a new customer. Pass a map containing customer [sep9Info]. To create a new customer fields
    /// first_name, last_name, and email_address are required. You can also pass [sep9Files].
    /// The [type] of action the customer is being KYC for can optionally be passed.
    /// [memo] and [transactionId] are also optional parameters. See the
    /// Specification on SEP-12 definition.
    ///
    /// - Parameters:
    ///   - sep9Info: SEP-09 customer fields
    ///   - sep9Files: SEP-09 customer files
    ///   - memo: memo that uniquely identifies the customer. If a memo is present in the decoded SEP-10 JWT it must match this parameter value.
    ///   - type: the type of action the customer is being KYCd for
    ///   - transactionId: the transaction id with which the customer's info is associated.
    ///
    public func add(sep9Info:[String:String],
                    sep9Files:[String:Data]? = nil,
                    memo:String? = nil,
                    type: String? = nil,
                    transactionId:String? = nil) async throws -> AddCustomerResponse {
        var request = PutCustomerInfoRequest(jwt: authToken.jwt)
        request.memo = memo
        request.type = type
        request.transactionId = transactionId
        request.extraFields = sep9Info
        request.extraFiles = sep9Files
        
        let responseEnum = await kycService.putCustomerInfo(request: request)
        switch responseEnum {
        case .success(let response):
            return AddCustomerResponse(info: response)
        case .failure(let error):
            throw error
        }
    }
    
    /// Update a customer by [id] of the customer as returned in the response of an add request. If the
    /// customer has not been registered, they do not yet have an id. You can pass a map containing
    /// customer [sep9Info] and [sep9Files]. The [type] of action the customer is being KYC for can
    /// optionally be passed. [memo] and [transactionId] are also optional parameters. See the
    /// Specification on SEP-12 definition.
    ///
    /// - Parameters:
    ///   - id: id of the customer received when added the customer
    ///   - sep9Info: SEP-09 customer fields
    ///   - sep9Files: SEP-09 customer files
    ///   - memo: memo that uniquely identifies the customer. If a memo is present in the decoded SEP-10 JWT it must match this parameter value.
    ///   - type: the type of action the customer is being KYCd for
    ///   - transactionId: the transaction id with which the customer's info is associated.
    ///
    public func update(id:String,
                       sep9Info:[String:String],
                       sep9Files:[String:Data]? = nil,
                       memo:String? = nil,
                       type: String? = nil,
                       transactionId:String? = nil) async throws -> AddCustomerResponse {
        
        var request = PutCustomerInfoRequest(jwt: authToken.jwt)
        request.id = id
        request.memo = memo
        request.type = type
        request.transactionId = transactionId
        request.extraFields = sep9Info
        request.extraFiles = sep9Files
        
        let responseEnum = await kycService.putCustomerInfo(request: request)
        switch responseEnum {
        case .success(let response):
            return AddCustomerResponse(info: response)
        case .failure(let error):
            throw error
        }
    }
    
    /// This endpoint allows servers to accept data values, usually confirmation codes, that verify a previously provided field via add.
    /// Pass a map containing the sep 9 [verificationFields] for the customer identified by [id].
    ///
    /// - Parameters:
    ///   - id: id of the customer received when added the customer
    ///   - verificationFields: verification fiels, e.g. confirmation code
    ///
    public func verify(id:String, verificationFields:[String:String]) async throws -> GetCustomerResponse {
        
        let request = PutCustomerVerificationRequest(id: id, fields: verificationFields, jwt: authToken.jwt)
        let responseEnum = await kycService.putCustomerVerification(request: request)
        switch responseEnum {
        case .success(let response):
            return GetCustomerResponse(info: response)
        case .failure(let error):
            throw error
        }
    }
    
    /// Delete a customer using Stellar [account] address.
    ///
    /// - Parameters:
    ///   - account: Stellar account id of the customer
    ///
    public func delete(account:String) async throws -> Void {
        
        let responseEnum = await kycService.deleteCustomerInfo(account: account, jwt: authToken.jwt)
        switch responseEnum {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}
