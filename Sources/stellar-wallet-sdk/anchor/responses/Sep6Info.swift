//
//  Sep6Info.swift
//
//
//  Created by Christian Rogobete on 01.03.25.
//

import Foundation
import stellarsdk

public class Sep6Info {
    
    /// supported deposit assets and their info
    public let deposit:[String : Sep6DepositInfo]?
    
    /// supported deposit exchange assets and their info
    public let depositExchange:[String : Sep6DepositExchangeInfo]?
    
    /// supported withdrawal assets and their info
    public let withdraw:[String : Sep6WithdrawInfo]?
    
    /// supported withdrawal exchange assets and their info
    public let withdrawExchange:[String : Sep6WithdrawExchangeInfo]?
    
    /// fee endpoint info
    public let fee:Sep6EndpointInfo?

    /// single transaction endpoint info
    public let transaction:Sep6EndpointInfo?
    
    /// transactions endpoint info
    public let transactions:Sep6EndpointInfo?
    
    /// anchor features info
    public let features: Sep6FeaturesInfo?
    
    internal init(deposit: [String : Sep6DepositInfo]? = nil, 
                  depositExchange: [String : Sep6DepositExchangeInfo]? = nil,
                  withdraw: [String : Sep6WithdrawInfo]? = nil,
                  withdrawExchange: [String : Sep6WithdrawExchangeInfo]? = nil,
                  fee: Sep6EndpointInfo? = nil,
                  transaction: Sep6EndpointInfo? = nil,
                  transactions: Sep6EndpointInfo? = nil,
                  features: Sep6FeaturesInfo? = nil) {
        
        self.deposit = deposit
        self.depositExchange = depositExchange
        self.withdraw = withdraw
        self.withdrawExchange = withdrawExchange
        self.fee = fee
        self.transaction = transaction
        self.transactions = transactions
        self.features = features
    }
    
    internal convenience init(response: AnchorInfoResponse) {
        var deposit:[String : Sep6DepositInfo]?
        if let depositAssets = response.deposit {
            deposit = [:]
            for (key, val) in depositAssets {
                deposit![key] = Sep6DepositInfo(depositAsset: val)
            }
        }
        
        var depositExchange:[String : Sep6DepositExchangeInfo]?
        if let depositExchangeAssets = response.depositExchange {
            depositExchange = [:]
            for (key, val) in depositExchangeAssets {
                depositExchange![key] = Sep6DepositExchangeInfo(depositExchangeAsset: val)
            }
        }
        
        var withdraw:[String : Sep6WithdrawInfo]?
        if let withdrawAssets = response.withdraw {
            withdraw = [:]
            for (key, val) in withdrawAssets {
                withdraw![key] = Sep6WithdrawInfo(withdrawAsset: val)
            }
        }
        
        var withdrawExchange:[String : Sep6WithdrawExchangeInfo]?
        if let withdrawExchangeAssets = response.withdrawExchange {
            withdrawExchange = [:]
            for (key, val) in withdrawExchangeAssets {
                withdrawExchange![key] = Sep6WithdrawExchangeInfo(withdrawExchangeAsset: val)
            }
        }
        
        var fee:Sep6EndpointInfo? = nil
        if let feeInfo = response.fee {
            fee = Sep6EndpointInfo(feeInfo: feeInfo)
        }
        
        var transaction:Sep6EndpointInfo? = nil
        if let transactionInfo = response.transaction {
            transaction = Sep6EndpointInfo(transactionInfo: transactionInfo)
        }
        
        var transactions:Sep6EndpointInfo? = nil
        if let transactionsInfo = response.transactions {
            transactions = Sep6EndpointInfo(transactionsInfo: transactionsInfo)
        }
        
        var features:Sep6FeaturesInfo? = nil
        if let featureFlags = response.features {
            features = Sep6FeaturesInfo(featureFlags: featureFlags)
        }
        
        self.init(deposit: deposit,
                  depositExchange: depositExchange,
                  withdraw: withdraw,
                  withdrawExchange: withdrawExchange,
                  fee: fee, transaction: transaction,
                  transactions: transactions,
                  features: features)
    }
    
}

public class Sep6DepositInfo {

    /// true if SEP-6 deposit for this asset is supported.
    public let enabled:Bool
    
    /// Optional. true if client must be authenticated before accessing the
    /// deposit endpoint for this asset. false if not specified.
    public let authenticationRequired:Bool?
    
    /// Optional fixed (flat) fee for deposit, in units of the Stellar asset.
    /// Null if there is no fee or the fee schedule is complex.
    public let feeFixed:Double?
    
    /// Optional percentage fee for deposit, in percentage points of the Stellar
    /// asset. Null if there is no fee or the fee schedule is complex.
    public let feePercent:Double?
    
    /// Optional minimum amount. No limit if not specified.
    public let minAmount:Double?
    
    /// Optional maximum amount. No limit if not specified.
    public let maxAmount:Double?

    /// (Deprecated) Accepting personally identifiable information through
    /// request parameters is a security risk due to web server request logging.
    /// KYC information should be supplied to the Anchor via SEP-12).
    public let fieldsInfo:[String:Sep6FieldInfo]?
    
    internal init(enabled: Bool, 
                  authenticationRequired: Bool? = false,
                  feeFixed: Double? = nil,
                  feePercent: Double? = nil,
                  minAmount: Double? = nil,
                  maxAmount: Double? = nil,
                  fieldsInfo: [String : Sep6FieldInfo]? = nil) {
        
        self.enabled = enabled
        self.authenticationRequired = authenticationRequired ?? false
        self.feeFixed = feeFixed
        self.feePercent = feePercent
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.fieldsInfo = fieldsInfo
    }
    
    internal convenience init(depositAsset: DepositAsset) {
        
        var fieldsInfo:[String:Sep6FieldInfo]? = nil
        if let anchorFields = depositAsset.fields {
            fieldsInfo = [:]
            for (key, val) in anchorFields {
                fieldsInfo![key] = Sep6FieldInfo(anchorField: val)
            }
        }
        self.init(enabled: depositAsset.enabled,
                  authenticationRequired: depositAsset.authenticationRequired,
                  feeFixed: depositAsset.feeFixed,
                  feePercent:depositAsset.feePercent,
                  minAmount: depositAsset.minAmount,
                  maxAmount: depositAsset.maxAmount,
                  fieldsInfo: fieldsInfo)
    }
}

public class Sep6DepositExchangeInfo {

    /// true if SEP-6 deposit exchange for this asset is supported.
    public let enabled:Bool
    
    /// Optional. true if client must be authenticated before accessing the
    /// deposit exchange endpoint for this asset. false if not specified.
    public let authenticationRequired:Bool?
    

    /// (Deprecated) Accepting personally identifiable information through
    /// request parameters is a security risk due to web server request logging.
    /// KYC information should be supplied to the Anchor via SEP-12).
    public let fieldsInfo:[String:Sep6FieldInfo]?
    
    internal init(enabled: Bool,
                  authenticationRequired: Bool? = false,
                  fieldsInfo: [String : Sep6FieldInfo]? = nil) {
        
        self.enabled = enabled
        self.authenticationRequired = authenticationRequired ?? false
        self.fieldsInfo = fieldsInfo
    }
    
    internal convenience init(depositExchangeAsset: DepositExchangeAsset) {
        
        var fieldsInfo:[String:Sep6FieldInfo]? = nil
        if let anchorFields = depositExchangeAsset.fields {
            fieldsInfo = [:]
            for (key, val) in anchorFields {
                fieldsInfo![key] = Sep6FieldInfo(anchorField: val)
            }
        }
        self.init(enabled: depositExchangeAsset.enabled,
                  authenticationRequired: depositExchangeAsset.authenticationRequired,
                  fieldsInfo: fieldsInfo)
    }
}

public class Sep6WithdrawInfo {

    /// true if SEP-6 withdrawal for this asset is supported.
    public let enabled:Bool
    
    /// Optional. true if client must be authenticated before accessing the
    /// withdrawal endpoint for this asset. false if not specified.
    public let authenticationRequired:Bool?
    
    /// Optional fixed (flat) fee for withdrawal, in units of the Stellar asset.
    /// Null if there is no fee or the fee schedule is complex.
    public let feeFixed:Double?
    
    /// Optional percentage fee for withdrawal, in percentage points of the Stellar
    /// asset. Null if there is no fee or the fee schedule is complex.
    public let feePercent:Double?
    
    /// Optional minimum amount. No limit if not specified.
    public let minAmount:Double?
    
    /// Optional maximum amount. No limit if not specified.
    public let maxAmount:Double?

    /// A map with each type of withdrawal supported for that asset as a key.
    /// Each type can specify a field info object explaining what fields
    /// are needed and what they do. Anchors are encouraged to use SEP-9
    /// financial account fields, but can also define custom fields if necessary.
    /// If a fields object is not specified, the wallet should assume that no
    /// extra field info are needed for that type of withdrawal. In the case that
    /// the Anchor requires additional fields for a withdrawal, it should set the
    /// transaction status to pending_customer_info_update. The wallet can query
    /// the /transaction endpoint to get the field info needed to complete the
    /// transaction in required_customer_info_updates and then use SEP-12 to
    /// collect the information from the user.
    public let types:[String:[String:Sep6FieldInfo]?]?
    
    internal init(enabled: Bool,
                  authenticationRequired: Bool? = false,
                  feeFixed: Double? = nil,
                  feePercent: Double? = nil,
                  minAmount: Double? = nil,
                  maxAmount: Double? = nil,
                  types: [String:[String:Sep6FieldInfo]?]? = nil) {
        
        self.enabled = enabled
        self.authenticationRequired = authenticationRequired ?? false
        self.feeFixed = feeFixed
        self.feePercent = feePercent
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.types = types
    }
    
    internal convenience init(withdrawAsset: WithdrawAsset) {
        
        var types:[String:[String:Sep6FieldInfo]?]? = nil
        if let anchorTypes = withdrawAsset.types {
            types = [:]
            for (key, val) in anchorTypes {
                if let fields = val.fields {
                    var nFields:[String:Sep6FieldInfo] = [:]
                    for (key2, val2) in fields {
                        nFields[key2] = Sep6FieldInfo(anchorField: val2)
                    }
                    types![key] = nFields
                } else {
                    types![key] = nil
                }
            }
        }
        
        self.init(enabled: withdrawAsset.enabled,
                  authenticationRequired: withdrawAsset.authenticationRequired,
                  feeFixed: withdrawAsset.feeFixed,
                  feePercent:withdrawAsset.feePercent,
                  minAmount: withdrawAsset.minAmount,
                  maxAmount: withdrawAsset.maxAmount,
                  types: types)
    }
}

public class Sep6WithdrawExchangeInfo {

    /// true if SEP-6 withdrawal exchange for this asset is supported.
    public let enabled:Bool
    
    /// Optional. true if client must be authenticated before accessing the
    ///  withdrawal exchange endpoint for this asset. false if not specified.
    public let authenticationRequired:Bool?

    /// A map with each type of withdrawal supported for that asset as a key.
    /// Each type can specify a field info object explaining what fields
    /// are needed and what they do. Anchors are encouraged to use SEP-9
    /// financial account fields, but can also define custom fields if necessary.
    /// If a fields object is not specified, the wallet should assume that no
    /// extra field info are needed for that type of withdrawal. In the case that
    /// the Anchor requires additional fields for a withdrawal, it should set the
    /// transaction status to pending_customer_info_update. The wallet can query
    /// the /transaction endpoint to get the field info needed to complete the
    /// transaction in required_customer_info_updates and then use SEP-12 to
    /// collect the information from the user.
    public let types:[String:[String:Sep6FieldInfo]?]?
    
    internal init(enabled: Bool,
                  authenticationRequired: Bool? = false,
                  feeFixed: Double? = nil,
                  feePercent: Double? = nil,
                  minAmount: Double? = nil,
                  maxAmount: Double? = nil,
                  types: [String:[String:Sep6FieldInfo]?]? = nil) {
        
        self.enabled = enabled
        self.authenticationRequired = authenticationRequired ?? false
        self.types = types
    }
    
    internal convenience init(withdrawExchangeAsset: WithdrawExchangeAsset) {
        
        var types:[String:[String:Sep6FieldInfo]?]? = nil
        if let anchorTypes = withdrawExchangeAsset.types {
            types = [:]
            for (key, val) in anchorTypes {
                if let fields = val.fields {
                    var nFields:[String:Sep6FieldInfo] = [:]
                    for (key2, val2) in fields {
                        nFields[key2] = Sep6FieldInfo(anchorField: val2)
                    }
                    types![key] = nFields
                } else {
                    types![key] = nil
                }
            }
        }
        
        self.init(enabled: withdrawExchangeAsset.enabled,
                  authenticationRequired: withdrawExchangeAsset.authenticationRequired,
                  types: types)
    }
}

public class Sep6FieldInfo {
 
    /// description of field to show to user.
    public let description:String?
    
    /// if field is optional. Defaults to false.
    public let optional:Bool?
    
    /// list of possible values for the field.
    public let choices:[String]?

    internal init(description: String? = nil, optional:Bool? = false, choices: [String]? = nil) {
        self.description = description
        self.choices = choices
        self.optional = optional ?? false
    }
    
    
    internal convenience init(anchorField: AnchorField) {
        self.init(description: anchorField.description,
                  optional: anchorField.optional, choices: anchorField.choices)
    }
}

public class Sep6EndpointInfo {

    /// true if the endpoint is available.
    public let enabled:Bool
    
    /// true if client must be authenticated before accessing the endpoint.
    public let authenticationRequired:Bool?
    
    /// Optional. Anchors are encouraged to add a description field to the
    /// fee object returned in GET /info containing a short explanation of
    /// how fees are calculated so client applications will be able to display
    /// this message to their users. This is especially important if the
    /// GET /fee endpoint is not supported and fees cannot be models using
    /// fixed and percentage values for each Stellar asset.
    public let description:String?
    
    internal init(enabled: Bool,
                  authenticationRequired: Bool?,
                  description:String? = nil) {
        
        self.enabled = enabled
        self.authenticationRequired = authenticationRequired
        self.description = description
    }
    
    internal convenience init(feeInfo: AnchorFeeInfo) {
        self.init(enabled: feeInfo.enabled,
                  authenticationRequired: feeInfo.authenticationRequired,
                  description: nil)
    }
    
    internal convenience init(transactionInfo: AnchorTransactionInfo) {
        self.init(enabled: transactionInfo.enabled,
                  authenticationRequired: transactionInfo.authenticationRequired,
                  description: nil)
    }
    
    internal convenience init(transactionsInfo: AnchorTransactionsInfo) {
        self.init(enabled: transactionsInfo.enabled,
                  authenticationRequired: transactionsInfo.authenticationRequired,
                  description: nil)
    }
}

public class Sep6FeaturesInfo {

    /// Whether or not the anchor supports creating accounts for users requesting
    /// deposits. Defaults to true.
    public let accountCreation:Bool
    
    /// Whether or not the anchor supports sending deposit funds as claimable
    /// balances. This is relevant for users of Stellar accounts without a
    /// trustline to the requested asset. Defaults to false.
    public let claimableBalances:Bool
    
    internal init(accountCreation: Bool, claimableBalances: Bool) {
        self.accountCreation = accountCreation
        self.claimableBalances = claimableBalances
    }

    
    internal convenience init(featureFlags: AnchorFeatureFlags) {
        self.init(accountCreation: featureFlags.accountCreation,
                  claimableBalances: featureFlags.claimableBalances)
    }
}

