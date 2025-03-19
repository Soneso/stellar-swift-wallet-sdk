//
//  Sep6.swift
//
//
//  Created by Christian Rogobete on 01.03.25.
//

import Foundation
import stellarsdk

public class Sep6 {
    
    internal var anchor:Anchor
    
    internal init(anchor:Anchor) {
        self.anchor = anchor
    }
    
    /// Get basic info from the anchor about what their SEP-6 TRANSFER_SERVER supports.
    ///
    /// - Parameters:
    ///   - language: Optional, defaults to en if not specified or if the specified language is not supported. Language code specified using RFC 4646.
    ///   - authToken: Optional, token previously received from the anchor via the SEP-10 authentication flow.
    ///
    public func info(language:String? = nil,
                     authToken:AuthToken? = nil) async throws -> Sep6Info {
        let service = try await transferService()
        let responseEnum = await service.info(language: language, jwtToken: authToken?.jwt)
        switch responseEnum {
        case .success(let response):
            return Sep6Info(response: response)
        case .failure(let error):
            throw error
        }

    }
    
    /// A deposit is when a user sends an external token (BTC via Bitcoin,
    /// USD via bank transfer, etc...) to an address held by an anchor. In turn,
    /// the anchor sends an equal amount of tokens on the Stellar network
    /// (minus fees) to the user's Stellar account.
    ///
    /// If the anchor supports SEP-38 quotes, it can also provide a bridge
    /// between non-equivalent tokens. For example, the anchor can receive ARS
    /// via bank transfer and in return send the equivalent value (minus fees)
    /// as USDC on the Stellar network to the user's Stellar account.
    /// That kind of deposit is covered in GET /deposit-exchange.
    ///
    /// The deposit endpoint allows a wallet to get deposit information from
    /// an anchor, so a user has all the information needed to initiate a deposit.
    /// It also lets the anchor specify additional information (if desired) that
    /// the user must submit via SEP-12 to be able to deposit.
    ///
    /// - Parameters:
    ///   - params: Parameters for the deposit
    ///   - authToken: token previously received from the anchor via the SEP-10 authentication flow.
    ///
    public func deposit(params:Sep6DepositParams, authToken:AuthToken) async throws -> Sep6TransferResponse {
        let service = try await transferService()
        let responseEnum = await service.deposit(request: params.toDepositRequest(jwt: authToken.jwt))
        switch responseEnum {
        case .success(let response):
            return Sep6TransferResponse.fromDepositSuccessResponse(response: response)
        case .failure(let error):
            switch error {
            case .informationNeeded(let inforNeededResponse):
                switch inforNeededResponse {
                case .nonInteractive(let info):
                    return Sep6TransferResponse.fromCustomerInformationNeededResponse(response: info)
                case .status(let status):
                    return Sep6TransferResponse.fromCustomerInformationStatusResponse(response: status)
                }
            default:
                throw error
            }
        }
    }
    
    /// If the anchor supports SEP-38 quotes, it can provide a deposit that makes
    /// a bridge between non-equivalent tokens by receiving, for instance BRL
    /// via bank transfer and in return sending the equivalent value (minus fees)
    /// as USDC to the user's Stellar account.
    ///
    /// The /deposit-exchange endpoint allows a wallet to get deposit information
    /// from an anchor when the user intends to make a conversion between
    /// non-equivalent tokens. With this endpoint, a user has all the information
    /// needed to initiate a deposit and it also lets the anchor specify
    /// additional information (if desired) that the user must submit via SEP-12.
    ///
    /// - Parameters:
    ///   - params: Parameters for the deposit
    ///   - authToken: token previously received from the anchor via the SEP-10 authentication flow.
    ///
    public func depositExchange(params:Sep6DepositExchangeParams, authToken:AuthToken) async throws -> Sep6TransferResponse {
        let service = try await transferService()
        let responseEnum = await service.depositExchange(request: params.toDepositExchangeRequest(jwt: authToken.jwt))
        switch responseEnum {
        case .success(let response):
            return Sep6TransferResponse.fromDepositSuccessResponse(response: response)
        case .failure(let error):
            switch error {
            case .informationNeeded(let inforNeededResponse):
                switch inforNeededResponse {
                case .nonInteractive(let info):
                    return Sep6TransferResponse.fromCustomerInformationNeededResponse(response: info)
                case .status(let status):
                    return Sep6TransferResponse.fromCustomerInformationStatusResponse(response: status)
                }
            default:
                throw error
            }
        }
    }
    
    /// A withdraw is when a user redeems an asset currently on the
    /// Stellar network for its equivalent off-chain asset via the Anchor.
    /// For instance, a user redeeming their NGNT in exchange for fiat NGN.
    ///
    /// If the anchor supports SEP-38 quotes, it can also provide a bridge
    /// between non-equivalent tokens. For example, the anchor can receive USDC
    /// from the Stellar network and in return send the equivalent value
    /// (minus fees) as NGN to the user's bank account.
    /// That kind of withdrawal is covered in GET /withdraw-exchange.
    ///
    /// The /withdraw endpoint allows a wallet to get withdrawal information
    /// from an anchor, so a user has all the information needed to initiate
    /// a withdrawal. It also lets the anchor specify additional information
    /// (if desired) that the user must submit via SEP-12 to be able to withdraw.
    ///
    /// - Parameters:
    ///   - params: Parameters for the withdraw
    ///   - authToken: token previously received from the anchor via the SEP-10 authentication flow.
    ///
    public func withdraw(params:Sep6WithdrawParams, authToken:AuthToken) async throws -> Sep6TransferResponse {
        let service = try await transferService()
        let responseEnum = await service.withdraw(request: params.toWithdrawRequest(jwt: authToken.jwt))
        switch responseEnum {
        case .success(let response):
            return Sep6TransferResponse.fromWithdrawSuccessResponse(response: response)
        case .failure(let error):
            switch error {
            case .informationNeeded(let inforNeededResponse):
                switch inforNeededResponse {
                case .nonInteractive(let info):
                    return Sep6TransferResponse.fromCustomerInformationNeededResponse(response: info)
                case .status(let status):
                    return Sep6TransferResponse.fromCustomerInformationStatusResponse(response: status)
                }
            default:
                throw error
            }
        }
    }
    
    /// If the anchor supports SEP-38 quotes, it can provide a withdraw that makes
    /// a bridge between non-equivalent tokens by receiving, for instance USDC
    /// from the Stellar network and in return sending the equivalent value
    /// (minus fees) as NGN to the user's bank account.
    ///
    /// The /withdraw-exchange endpoint allows a wallet to get withdraw
    /// information from an anchor when the user intends to make a conversion
    /// between non-equivalent tokens. With this endpoint, a user has all the
    /// information needed to initiate a withdraw and it also lets the anchor
    /// specify additional information (if desired) that the user must submit
    /// via SEP-12.
    ///
    /// - Parameters:
    ///   - params: Parameters for the withdraw
    ///   - authToken: token previously received from the anchor via the SEP-10 authentication flow.
    ///
    public func withdrawExchange(params:Sep6WithdrawExchangeParams, authToken:AuthToken) async throws -> Sep6TransferResponse {
        let service = try await transferService()
        let responseEnum = await service.withdrawExchange(request: params.toWithdrawExchangeRequest(jwt: authToken.jwt))
        switch responseEnum {
        case .success(let response):
            return Sep6TransferResponse.fromWithdrawSuccessResponse(response: response)
        case .failure(let error):
            switch error {
            case .informationNeeded(let inforNeededResponse):
                switch inforNeededResponse {
                case .nonInteractive(let info):
                    return Sep6TransferResponse.fromCustomerInformationNeededResponse(response: info)
                case .status(let status):
                    return Sep6TransferResponse.fromCustomerInformationStatusResponse(response: status)
                }
            default:
                throw error
            }
        }
    }
    
    /// The transaction history endpoint helps anchors enable a better
    /// experience for users using an external wallet.
    /// With it, wallets can display the status of deposits and withdrawals
    /// while they process and a history of past transactions with the anchor.
    /// It's only for transactions that are deposits to or withdrawals from
    /// the anchor.
    ///
    /// - Parameters:
    ///   - authToken: token previously received from the anchor via the SEP-10 authentication flow.
    ///   - assetCode: the code of the asset to get the transactions for
    ///   - noOlderThan: Transactions should not be older than this date
    ///   - assetCode: the code of the asset to get the transactions for
    ///   - limit: Max number of transactions to fetch
    ///   - kind: Kind of transaction. E.g. deposit
    ///   - pagingId: Starting point for the search. E.g. paging id of the last transaction from your previous request.
    ///
    public func getTransactionsForAsset(authToken:AuthToken,
                                        assetCode:String,
                                        noOlderThan:Date? = nil,
                                        limit:Int? = nil,
                                        kind:TransactionKind? = nil,
                                        pagingId:String? = nil) async throws -> [Sep6Transaction] {
        
        var result:[Sep6Transaction] = []
        
        let service = try await transferService()
        
        var request = AnchorTransactionsRequest(assetCode: assetCode, account: authToken.account, jwt: authToken.jwt)
        request.noOlderThan = noOlderThan
        request.limit = limit
        request.kind = kind?.rawValue
        request.pagingId = pagingId
        request.lang = anchor.lang
        
        let responseEnum = await service.getTransactions(request: request)
        switch responseEnum {
        case .success(let response):
            for tx in response.transactions {
                result.append(try Sep6Transaction(tx: tx))
            }
            break
        case .failure(let error):
            throw error
        }
        
        return result
    }
    
    /// The transaction endpoint enables clients to query/validate a
    /// specific transaction at an anchor.
    ///
    /// - Important: One of the Id parameters must be provided.
    ///
    /// - Parameters:
    ///   - authToken: token previously received from the anchor via the SEP-10 authentication flow.
    ///   - transactionId: id of the transaction received from the anchor
    ///   - stellarTransactionId: Stellar network transaction id (hash)
    ///   - externalTransactionId: External transaction id
    ///
    public func getTransactionBy(authToken:AuthToken,
                                transactionId:String? = nil,
                                stellarTransactionId:String? = nil,
                                externalTransactionId:String? = nil) async throws -> Sep6Transaction {
        
        if (transactionId == nil &&
            stellarTransactionId == nil &&
            externalTransactionId == nil) {
            throw ValidationError.invalidArgument(message: "One of transactionId, stellarTransactionId or externalTransactionId is required.")
        }
        
        let service = try await transferService()
        var request = AnchorTransactionRequest(id:transactionId,
                                               stellarTransactionId: stellarTransactionId,
                                               externalTransactionId: externalTransactionId,
                                               jwt: authToken.jwt)
        request.lang = anchor.lang
        
        let responseEnum = await service.getTransaction(request: request)
        switch responseEnum {
        case .success(let response):
            return try Sep6Transaction(tx: response.transaction)
        case .failure(let error):
            throw error
        }
    }
    
    /// This endpoint is deprecated in SEP-06. Nevertheless, some anchors still provide
    /// fee information only through this endpoint.
    /// As parameters, provide the kind of [operation] (deposit or withdraw),
    /// optionally the [type] of deposit or withdrawal (SEPA, bank_account, cash, etc...),
    /// the stellar [assetCode] of the asset to be deposited or withdrawn, the
    /// [amount] of the asset that will be deposited/withdrawn and the previously
    /// received SEP-10 [authToken] if authentication is required.
    ///
    /// - Parameters:
    ///   - assetCode: the code of the asset to be deposited or withdrawn
    ///   - amount: amount of the asset that will be deposited/withdrawn
    ///   - operation: kind of operation ("deposit" or "withdraw")
    ///   - type: of deposit or withdrawal (SEPA, bank_account, cash, etc...)
    ///   - authToken: if required, the token previously received from the anchor via the SEP-10 authentication flow.
    ///
    public func fee(assetCode: String, 
                    amount: Double,
                    operation:String,
                    type:String? = nil,
                    authToken:AuthToken? = nil) async throws -> Double {
        
        let service = try await transferService()
        var request = FeeRequest(operation: operation, assetCode: assetCode, amount: amount, jwt: authToken?.jwt)
        request.type = type
        let responseEnum = await service.fee(request: request)
        switch responseEnum {
        case .success(let response):
            return response.fee
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
        
        return Watcher(anchor: anchor, pollDelay: pollDelay, exceptionHandler: exceptionHandler, watcherKind: WatcherKind.sep6)
    }
    
    private func transferService() async throws -> TransferServerService {
        let tomlInfo = try await anchor.sep1
        if let sep6 = tomlInfo.services.sep6 {
            return TransferServerService(serviceAddress: sep6.transferServer)
        }
        throw AnchorError.depositAndWithdrawalAPINotSupported
    }
}


public class Sep6DepositParams {
    
    /// The on-chain asset the user wants to get from the Anchor
    /// after doing an off-chain deposit. The value passed must match one of the
    /// codes listed in the /info response's deposit object.
    public var assetCode:String
    
    /// The stellar or muxed account ID of the user that wants to deposit.
    /// This is where the asset token will be sent. Note that the account
    /// specified in this request could differ from the account authenticated
    /// via SEP-10.
    public var account:String
    
    /// (optional) Type of memo that the anchor should attach to the Stellar
    /// payment transaction, one of text, id or hash.
    public var memoType:MemoType?
    
    /// (optional) Value of memo to attach to transaction, for hash this should
    /// be base64-encoded. Because a memo can be specified in the SEP-10 JWT for
    /// Shared Accounts, this field as well as memoType can be different than the
    /// values included in the SEP-10 JWT. For example, a client application
    /// could use the value passed for this parameter as a reference number used
    /// to match payments made to account.
    public var memo:String?
    
    /// (optional) Email address of depositor. If desired, an anchor can use
    /// this to send email updates to the user about the deposit.
    public var emailAddress:String?
    
    /// (optional) Type of deposit. If the anchor supports multiple deposit
    /// methods (e.g. SEPA or SWIFT), the wallet should specify type. This field
    /// may be necessary for the anchor to determine which KYC fields to collect.
    public var type:String?
    
    /// (deprecated, optional) In communications / pages about the deposit,
    /// anchor should display the wallet name to the user to explain where funds
    /// are going. However, anchors should use client_domain (for non-custodial)
    /// and sub value of JWT (for custodial) to determine wallet information.
    public var walletName:String?
    
    /// (deprecated,optional) Anchor should link to this when notifying the user
    /// that the transaction has completed. However, anchors should use
    /// client_domain (for non-custodial) and sub value of JWT (for custodial)
    /// to determine wallet information.
    public var walletUrl:String?
    
    /// (optional) Defaults to en. Language code specified using ISO 639-1.
    /// error fields in the response should be in this language.
    public var lang:String?
    
    /// (optional) A URL that the anchor should POST a JSON message to when the
    /// status property of the transaction created as a result of this request
    /// changes. The JSON message should be identical to the response format
    /// for the /transaction endpoint.
    public var onChangeCallback:String?
    
    /// (optional) The amount of the asset the user would like to deposit with
    /// the anchor. This field may be necessary for the anchor to determine
    /// what KYC information is necessary to collect.
    public var amount:String?
    
    ///  (optional) The ISO 3166-1 alpha-3 code of the user's current address.
    ///  This field may be necessary for the anchor to determine what KYC
    ///  information is necessary to collect.
    public var countryCode:String?
    
    /// (optional) "true" if the client supports receiving deposit transactions as
    /// a claimable balance, "false" otherwise.
    public var claimableBalanceSupported:String?
    
    /// (optional) id of an off-chain account (managed by the anchor) associated
    /// with this user's Stellar account (identified by the JWT's sub field).
    /// If the anchor supports SEP-12, the customerId field should match the
    /// SEP-12 customer's id. customerId should be passed only when the off-chain
    /// id is know to the client, but the relationship between this id and the
    /// user's Stellar account is not known to the Anchor.
    public var customerId:String?
    
    /// (optional) id of the chosen location to drop off cash
    public var locationId:String?
    
    /// (optional) can be used to provide extra fields for the request.
    /// E.g. required fields from the /info endpoint that are not covered by
    /// the standard parameters.
    public var extraFields:[String:String]?
 
    public init(assetCode: String, account: String, memoType: MemoType? = nil, memo: String? = nil, emailAddress: String? = nil, type: String? = nil, walletName: String? = nil, walletUrl: String? = nil, lang: String? = nil, onChangeCallback: String? = nil, amount: String? = nil, countryCode: String? = nil, claimableBalanceSupported: String? = nil, customerId: String? = nil, locationId: String? = nil, extraFields: [String : String]? = nil) {
        self.assetCode = assetCode
        self.account = account
        self.memoType = memoType
        self.memo = memo
        self.emailAddress = emailAddress
        self.type = type
        self.walletName = walletName
        self.walletUrl = walletUrl
        self.lang = lang
        self.onChangeCallback = onChangeCallback
        self.amount = amount
        self.countryCode = countryCode
        self.claimableBalanceSupported = claimableBalanceSupported
        self.customerId = customerId
        self.locationId = locationId
        self.extraFields = extraFields
    }
    
    internal func toDepositRequest(jwt:String) -> DepositRequest {
        
        var request = DepositRequest(assetCode: assetCode,
                                     account: account,
                                     jwt: jwt)
        
        request.memoType = memoType?.rawValue
        request.memo = memo
        request.emailAddress = emailAddress
        request.type = type
        request.walletName = walletName
        request.walletUrl = walletUrl
        request.lang = lang
        request.onChangeCallback = onChangeCallback
        request.amount = amount
        request.countryCode = countryCode
        request.claimableBalanceSupported = claimableBalanceSupported
        request.customerId = customerId
        request.locationId = locationId
        request.extraFields = extraFields
        
        return request
    }
}

public class Sep6DepositExchangeParams {
    
    /// The on-chain asset the user wants to get from the Anchor
    /// after doing an off-chain deposit. The value passed must match one of the
    /// codes listed in the /info response's exchange object.
    public var destinationAssetCode:String
    
    /// The off-chain asset the Anchor will receive from the user. The value must
    /// match one of the asset values included in a SEP-38
    /// GET /prices?buy_asset=stellar:<destination_asset>:<asset_issuer> response
    /// using SEP-38 Asset Identification Format.
    public var sourceAssetId:FiatAssetId
    
    /// The amount of the source_asset the user would like to deposit to the
    /// anchor's off-chain account. This field may be necessary for the anchor
    /// to determine what KYC information is necessary to collect. Should be
    /// equals to quote.sell_amount if a quote_id was used.
    public var amount:String
    
    /// The stellar or muxed account ID of the user that wants to deposit.
    /// This is where the asset token will be sent. Note that the account
    /// specified in this request could differ from the account authenticated
    /// via SEP-10.
    public var account:String
    
    /// (optional) The id returned from a SEP-38 POST /quote response.
    /// If this parameter is provided and the user delivers the deposit funds
    /// to the Anchor before the quote expiration, the Anchor should respect the
    /// conversion rate agreed in that quote. If the values of destination_asset,
    /// source_asset and amount conflict with the ones used to create the
    /// SEP-38 quote, this request should be rejected with a 400.
    public var quoteId:String?
    
    /// (optional) Type of memo that the anchor should attach to the Stellar
    /// payment transaction, one of text, id or hash.
    public var memoType:MemoType?
    
    /// (optional) Value of memo to attach to transaction, for hash this should
    /// be base64-encoded. Because a memo can be specified in the SEP-10 JWT for
    /// Shared Accounts, this field as well as memoType can be different than the
    /// values included in the SEP-10 JWT. For example, a client application
    /// could use the value passed for this parameter as a reference number used
    /// to match payments made to account.
    public var memo:String?
    
    /// (optional) Email address of depositor. If desired, an anchor can use
    /// this to send email updates to the user about the deposit.
    public var emailAddress:String?
    
    /// (optional) Type of deposit. If the anchor supports multiple deposit
    /// methods (e.g. SEPA or SWIFT), the wallet should specify type. This field
    /// may be necessary for the anchor to determine which KYC fields to collect.
    public var type:String?
    
    /// (deprecated, optional) In communications / pages about the deposit,
    /// anchor should display the wallet name to the user to explain where funds
    /// are going. However, anchors should use client_domain (for non-custodial)
    /// and sub value of JWT (for custodial) to determine wallet information.
    public var walletName:String?
    
    /// (deprecated,optional) Anchor should link to this when notifying the user
    /// that the transaction has completed. However, anchors should use
    /// client_domain (for non-custodial) and sub value of JWT (for custodial)
    /// to determine wallet information.
    public var walletUrl:String?
    
    /// (optional) Defaults to en. Language code specified using ISO 639-1.
    /// error fields in the response should be in this language.
    public var lang:String?
    
    /// (optional) A URL that the anchor should POST a JSON message to when the
    /// status property of the transaction created as a result of this request
    /// changes. The JSON message should be identical to the response format
    /// for the /transaction endpoint.
    public var onChangeCallback:String?
    
    ///  (optional) The ISO 3166-1 alpha-3 code of the user's current address.
    ///  This field may be necessary for the anchor to determine what KYC
    ///  information is necessary to collect.
    public var countryCode:String?
    
    /// (optional) "true" if the client supports receiving deposit transactions as
    /// a claimable balance, "false" otherwise.
    public var claimableBalanceSupported:String?
    
    /// (optional) id of an off-chain account (managed by the anchor) associated
    /// with this user's Stellar account (identified by the JWT's sub field).
    /// If the anchor supports SEP-12, the customerId field should match the
    /// SEP-12 customer's id. customerId should be passed only when the off-chain
    /// id is know to the client, but the relationship between this id and the
    /// user's Stellar account is not known to the Anchor.
    public var customerId:String?
    
    /// (optional) id of the chosen location to drop off cash
    public var locationId:String?
    
    /// (optional) can be used to provide extra fields for the request.
    /// E.g. required fields from the /info endpoint that are not covered by
    /// the standard parameters.
    public var extraFields:[String:String]?
    
    public init(destinationAssetCode: String, sourceAssetId: FiatAssetId, amount: String, account: String, quoteId: String? = nil, memoType: MemoType? = nil, memo: String? = nil, emailAddress: String? = nil, type: String? = nil, walletName: String? = nil, walletUrl: String? = nil, lang: String? = nil, onChangeCallback: String? = nil, countryCode: String? = nil, claimableBalanceSupported: String? = nil, customerId: String? = nil, locationId: String? = nil, extraFields: [String : String]? = nil) {
        self.destinationAssetCode = destinationAssetCode
        self.sourceAssetId = sourceAssetId
        self.amount = amount
        self.account = account
        self.quoteId = quoteId
        self.memoType = memoType
        self.memo = memo
        self.emailAddress = emailAddress
        self.type = type
        self.walletName = walletName
        self.walletUrl = walletUrl
        self.lang = lang
        self.onChangeCallback = onChangeCallback
        self.countryCode = countryCode
        self.claimableBalanceSupported = claimableBalanceSupported
        self.customerId = customerId
        self.locationId = locationId
        self.extraFields = extraFields
    }
    
    internal func toDepositExchangeRequest(jwt:String) -> DepositExchangeRequest {
        
        var request = DepositExchangeRequest(destinationAsset: destinationAssetCode,
                                             sourceAsset: sourceAssetId.sep38,
                                             amount: amount,
                                             account: account)
        
        request.quoteId = quoteId
        request.memoType = memoType?.rawValue
        request.memo = memo
        request.emailAddress = emailAddress
        request.type = type
        request.walletName = walletName
        request.walletUrl = walletUrl
        request.lang = lang
        request.onChangeCallback = onChangeCallback
        request.countryCode = countryCode
        request.claimableBalanceSupported = claimableBalanceSupported
        request.customerId = customerId
        request.locationId = locationId
        request.extraFields = extraFields
        
        return request
    }
}

public class Sep6WithdrawParams {
    
    /// The on-chain asset the user wants to withdraw.
    /// The value passed must match one of the codes listed in the /info response's withdraw object.
    public var assetCode:String
    
    /// Type of withdrawal. Can be: crypto, bank_account, cash, mobile,
    /// bill_payment or other custom values. This field may be necessary
    /// for the anchor to determine what KYC information is necessary to collect.
    public var type:String
    
    /// (Deprecated) The account that the user wants to withdraw their funds to.
    /// This can be a crypto account, a bank account number, IBAN, mobile number,
    /// or email address.
    public var dest:String?
    
    /// (Deprecated, optional) Extra information to specify withdrawal location.
    /// For crypto it may be a memo in addition to the dest address.
    /// It can also be a routing number for a bank, a BIC, or the name of a
    /// partner handling the withdrawal.
    public var destExtra:String?
    
    /// (optional) The Stellar or muxed account the client will use as the source
    /// of the withdrawal payment to the anchor. If SEP-10 authentication is not
    /// used, the anchor can use account to look up the user's KYC information.
    /// Note that the account specified in this request could differ from the
    /// account authenticated via SEP-10.
    public var account:String?
    
    /// (Deprecated, optional) Type of memo. One of text, id or hash.
    /// Deprecated because memos used to identify users of the same
    /// Stellar account should always be of type of id.
    public var memoType:MemoType?
    
    /// (optional) This field should only be used if SEP-10 authentication is not.
    /// It was originally intended to distinguish users of the same Stellar account.
    /// However if SEP-10 is supported, the anchor should use the sub value
    /// included in the decoded SEP-10 JWT instead.
    public var memo:String?
    
    /// (deprecated, optional) In communications / pages about the withdrawal,
    /// anchor should display the wallet name to the user to explain where funds
    /// are coming from. However, anchors should use client_domain
    /// (for non-custodial) and sub value of JWT (for custodial) to determine
    /// wallet information.
    public var walletName:String?
    
    /// (deprecated, optional) Anchor can show this to the user when referencing
    /// the wallet involved in the withdrawal (ex. in the anchor's transaction
    /// history). However, anchors should use client_domain (for non-custodial)
    /// and sub value of JWT (for custodial) to determine wallet information.
    public var walletUrl:String?
    
    /// (optional) Defaults to en if not specified or if the
    /// specified language is not supported. Language code specified using
    /// RFC 4646. error fields and other human readable messages in the
    /// response should be in this language.
    public var lang:String?
    
    /// (optional) A URL that the anchor should POST a JSON message to when the
    /// status property of the transaction created as a result of this request
    /// changes. The JSON message should be identical to the response format
    /// for the /transaction endpoint.
    public var onChangeCallback:String?
    
    /// (optional) The amount of the asset the user would like to withdraw.
    /// This field may be necessary for the anchor to determine what KYC
    /// information is necessary to collect.
    public var amount:String?
    
    /// (optional) The ISO 3166-1 alpha-3 code of the user's current address.
    /// This field may be necessary for the anchor to determine what KYC
    /// information is necessary to collect.
    public var countryCode:String?
    
    /// (optional) The memo the anchor must use when sending refund payments back
    /// to the user. If not specified, the anchor should use the same memo used
    /// by the user to send the original payment. If specified, refundMemoType
    /// must also be specified.
    public var refundMemo:String?
    
    /// (optional) The type of the refund_memo. Can be id, text, or hash.
    /// If specified, refundMemo must also be specified.
    public var refundMemoType:String?
    
    /// (optional) id of an off-chain account (managed by the anchor) associated
    /// with this user's Stellar account (identified by the JWT's sub field).
    /// If the anchor supports SEP-12, the customer_id field should match the
    /// SEP-12 customer's id. customer_id should be passed only when the
    /// off-chain id is know to the client, but the relationship between this id
    /// and the user's Stellar account is not known to the Anchor.
    public var customerId:String?
    
    /// (optional) id of the chosen location to pick up cash
    public var locationId:String?
    
    /// (optional) can be used to provide extra fields for the request.
    /// E.g. required fields from the /info endpoint that are not covered by
    /// the standard parameters.
    public var extraFields:[String:String]?
 
    
    public init(assetCode: String, type: String, dest: String? = nil, destExtra: String? = nil, account: String? = nil, memoType: MemoType? = nil, memo: String? = nil, walletName: String? = nil, walletUrl: String? = nil, lang: String? = nil, onChangeCallback: String? = nil, amount: String? = nil, countryCode: String? = nil, refundMemo: String? = nil, refundMemoType: String? = nil, customerId: String? = nil, locationId: String? = nil, extraFields: [String : String]? = nil) {
        self.assetCode = assetCode
        self.type = type
        self.dest = dest
        self.destExtra = destExtra
        self.account = account
        self.memoType = memoType
        self.memo = memo
        self.walletName = walletName
        self.walletUrl = walletUrl
        self.lang = lang
        self.onChangeCallback = onChangeCallback
        self.amount = amount
        self.countryCode = countryCode
        self.refundMemo = refundMemo
        self.refundMemoType = refundMemoType
        self.customerId = customerId
        self.locationId = locationId
        self.extraFields = extraFields
    }
    
    internal func toWithdrawRequest(jwt:String) -> WithdrawRequest {
        
        var request = WithdrawRequest(type: type, assetCode: assetCode, jwt: jwt)
        
        request.dest = dest
        request.destExtra = destExtra
        request.account = amount
        request.memoType = memoType?.rawValue
        request.memo = memo
        request.walletName = walletName
        request.walletUrl = walletUrl
        request.lang = lang
        request.onChangeCallback = onChangeCallback
        request.amount = amount
        request.countryCode = countryCode
        request.refundMemo = refundMemo
        request.refundMemoType = refundMemoType
        request.customerId = customerId
        request.locationId = locationId
        request.extraFields = extraFields
        
        return request
    }
}

public class Sep6WithdrawExchangeParams {

    /// The on-chain asset the user wants to withdraw. The value passed
    /// must match one of the codes listed in the /info response's
    /// withdraw-exchange object.
    public var sourceAssetCode:String
    
    /// The off-chain asset the Anchor will deliver to the user's account.
    /// The value must match one of the asset values included in a SEP-38
    /// GET /prices?sell_asset=stellar:<source_asset>:<asset_issuer> response
    /// using SEP-38 Asset Identification Format.
    public var destinationAssetId:FiatAssetId
    
    /// The amount of the on-chain asset (source_asset) the user would like to
    /// send to the anchor's Stellar account. This field may be necessary for
    /// the anchor to determine what KYC information is necessary to collect.
    /// Should be equals to quote.sell_amount if a quote_id was used.
    public var amount:String
    
    /// Type of withdrawal. Can be: crypto, bank_account, cash, mobile,
    /// bill_payment or other custom values. This field may be necessary for the
    /// anchor to determine what KYC information is necessary to collect.
    public var type:String
    
    /// (Deprecated) The account that the user wants to withdraw their
    /// funds to. This can be a crypto account, a bank account number, IBAN,
    /// mobile number, or email address.
    public var dest:String?
    
    /// (Deprecated, optional) Extra information to specify withdrawal
    /// location. For crypto it may be a memo in addition to the dest address.
    /// It can also be a routing number for a bank, a BIC, or the name of a
    /// partner handling the withdrawal.
    public var destExtra:String?
    
    /// (optional) The id returned from a SEP-38 POST /quote response.
    /// If this parameter is provided and the Stellar transaction used to send
    /// the asset to the Anchor has a created_at timestamp earlier than the
    /// quote's expires_at attribute, the Anchor should respect the conversion
    /// rate agreed in that quote. If the values of destination_asset,
    /// source_asset and amount conflict with the ones used to create the
    /// SEP-38 quote, this request should be rejected with a 400.
    public var quoteId:String?
    
    /// (optional) The Stellar or muxed account of the user that wants to do the
    /// withdrawal. This is only needed if the anchor requires KYC information
    /// for withdrawal and SEP-10 authentication is not used. Instead, the anchor
    /// can use account to look up the user's KYC information. Note that the
    /// account specified in this request could differ from the account
    /// authenticated via SEP-10.
    public var account:String?
    
    /// (Deprecated, optional) Type of memo. One of text, id or hash.
    /// Deprecated because memos used to identify users of the same
    /// Stellar account should always be of type of id.
    public var memoType:MemoType?
    
    /// (optional) This field should only be used if SEP-10 authentication is not.
    /// It was originally intended to distinguish users of the same Stellar
    /// account. However if SEP-10 is supported, the anchor should use the sub
    /// value included in the decoded SEP-10 JWT instead.
    public var memo:String?
    
    /// (deprecated, optional) In communications / pages about the withdrawal,
    /// anchor should display the wallet name to the user to explain where funds
    /// are coming from. However, anchors should use client_domain
    /// (for non-custodial) and sub value of JWT (for custodial) to determine
    /// wallet information.
    public var walletName:String?

    /// (deprecated,optional) Anchor can show this to the user when referencing
    /// the wallet involved in the withdrawal (ex. in the anchor's transaction
    /// history). However, anchors should use client_domain (for non-custodial)
    /// and sub value of JWT (for custodial) to determine wallet information.
    public var walletUrl:String?
    
    /// (optional) Defaults to en if not specified or if the specified language
    /// is not supported. Language code specified using RFC 4646. error fields
    /// and other human readable messages in the response should be in
    /// this language.
    public var lang:String?
    
    /// (optional) A URL that the anchor should POST a JSON message to when the
    /// status property of the transaction created as a result of this request
    /// changes. The JSON message should be identical to the response format for
    /// the /transaction endpoint. The callback needs to be signed by the anchor
    /// and the signature needs to be verified by the wallet according to
    /// the callback signature specification.
    public var onChangeCallback:String?
    
    /// (optional) The ISO 3166-1 alpha-3 code of the user's current address.
    /// This field may be necessary for the anchor to determine what KYC
    /// information is necessary to collect.
    public var countryCode:String?
    
    /// (optional) The memo the anchor must use when sending refund payments back
    /// to the user. If not specified, the anchor should use the same memo used
    /// by the user to send the original payment. If specified, refundMemoType
    /// must also be specified.
    public var refundMemo:String?
    
    /// (optional) The type of the refund_memo. Can be id, text, or hash.
    /// If specified, refundMemo must also be specified.
    public var refundMemoType:String?
    
    /// (optional) id of an off-chain account (managed by the anchor) associated
    /// with this user's Stellar account (identified by the JWT's sub field).
    /// If the anchor supports SEP-12, the customer_id field should match the
    /// SEP-12 customer's id. customer_id should be passed only when the
    /// off-chain id is know to the client, but the relationship between this id
    /// and the user's Stellar account is not known to the Anchor.
    public var customerId:String?
    
    /// (optional) id of the chosen location to pick up cash
    public var locationId:String?
    
    /// (optional) can be used to provide extra fields for the request.
    /// E.g. required fields from the /info endpoint that are not covered by
    /// the standard parameters.
    public var extraFields:[String:String]?
 
    
    public init(sourceAssetCode: String, destinationAssetId: FiatAssetId, amount: String, type: String, dest: String? = nil, destExtra: String? = nil, quoteId: String? = nil, account: String? = nil, memoType: MemoType? = nil, memo: String? = nil, walletName: String? = nil, walletUrl: String? = nil, lang: String? = nil, onChangeCallback: String? = nil, countryCode: String? = nil, refundMemo: String? = nil, refundMemoType: String? = nil, customerId: String? = nil, locationId: String? = nil, extraFields: [String : String]? = nil) {
        self.sourceAssetCode = sourceAssetCode
        self.destinationAssetId = destinationAssetId
        self.amount = amount
        self.type = type
        self.dest = dest
        self.destExtra = destExtra
        self.quoteId = quoteId
        self.account = account
        self.memoType = memoType
        self.memo = memo
        self.walletName = walletName
        self.walletUrl = walletUrl
        self.lang = lang
        self.onChangeCallback = onChangeCallback
        self.countryCode = countryCode
        self.refundMemo = refundMemo
        self.refundMemoType = refundMemoType
        self.customerId = customerId
        self.locationId = locationId
        self.extraFields = extraFields
    }
    
    
    internal func toWithdrawExchangeRequest(jwt:String) -> WithdrawExchangeRequest {
        
        var request = WithdrawExchangeRequest(sourceAsset: sourceAssetCode,
                                              destinationAsset: destinationAssetId.sep38,
                                              amount: amount,
                                              type: type,
                                              jwt: jwt)
        
        request.dest = dest
        request.destExtra = destExtra
        request.quoteId = quoteId
        request.account = amount
        request.memoType = memoType?.rawValue
        request.memo = memo
        request.walletName = walletName
        request.walletUrl = walletUrl
        request.lang = lang
        request.onChangeCallback = onChangeCallback
        request.countryCode = countryCode
        request.refundMemo = refundMemo
        request.refundMemoType = refundMemoType
        request.customerId = customerId
        request.locationId = locationId
        request.extraFields = extraFields
        
        return request
    }
}
