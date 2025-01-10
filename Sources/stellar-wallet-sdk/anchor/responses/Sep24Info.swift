//
//  Sep24Info.swift
//
//
//  Created by Christian Rogobete on 08.01.25.
//

import Foundation
import stellarsdk

public class Sep24Info {
    public let deposit:[String:Sep24AssetInfo]
    public let withdraw:[String:Sep24AssetInfo]
    public let fee:Sep24ServiceFee
    public let features:Sep24ServiceFeatures?
    
    internal init(info:Sep24InfoResponse) {
        var deposit:[String:Sep24AssetInfo] = [:]
        if let depositAssets = info.depositAssets {
            for (key, val) in depositAssets {
                deposit[key] = Sep24AssetInfo(depositAsset: val)
            }
        }
        self.deposit = deposit
        
        var withdraw:[String:Sep24AssetInfo] = [:]
        if let withdrawAssets = info.withdrawAssets {
            for (key, val) in withdrawAssets {
                withdraw[key] = Sep24AssetInfo(withdrawAsset: val)
            }
        }
        self.withdraw = withdraw
        
        if let feeInfo = info.feeEndpointInfo {
            self.fee = Sep24ServiceFee(feeInfo: feeInfo)
        } else {
            self.fee = Sep24ServiceFee(enabled: false, authenticationRequired: false)
        }
        
        if let featureFlags = info.featureFlags {
            self.features = Sep24ServiceFeatures(flags: featureFlags)
        } else {
            self.features = nil
        }
    }
    
    public func depositServiceAsset(assetId:StellarAssetId) -> Sep24AssetInfo? {
        var assetKey:String = assetId.id
        if let issuedAssetId = assetId as? IssuedAssetId {
            assetKey = issuedAssetId.code
        }
        return deposit[assetKey]
    }
    
    public func withdrawServiceAsset(assetId:StellarAssetId) -> Sep24AssetInfo? {
        var assetKey:String = assetId.id
        if let issuedAssetId = assetId as? IssuedAssetId {
            assetKey = issuedAssetId.code
        }
        return withdraw[assetKey]
    }
}

public class Sep24AssetInfo {
    
    public let enabled:Bool
    public let minAmount:Double?
    public let maxAmount:Double?
    public let feeFixed:Double?
    public let feePercent:Double?
    public let feeMinimum:Double?
    
    internal init(enabled: Bool, 
                  minAmount: Double? = nil,
                  maxAmount: Double? = nil,
                  feeFixed: Double? = nil,
                  feePercent: Double? = nil,
                  feeMinimum: Double? = nil) {
        
        self.enabled = enabled
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.feeFixed = feeFixed
        self.feePercent = feePercent
        self.feeMinimum = feeMinimum
    }
    
    internal convenience init(depositAsset: Sep24DepositAsset) {
        self.init(enabled: depositAsset.enabled,
                  minAmount: depositAsset.minAmount,
                  maxAmount: depositAsset.maxAmount,
                  feeFixed: depositAsset.feeFixed,
                  feePercent: depositAsset.feePercent,
                  feeMinimum: depositAsset.feeMinimum)
    }
    
    internal convenience init(withdrawAsset: Sep24WithdrawAsset) {
        self.init(enabled: withdrawAsset.enabled,
                  minAmount: withdrawAsset.minAmount,
                  maxAmount: withdrawAsset.maxAmount,
                  feeFixed: withdrawAsset.feeFixed,
                  feePercent: withdrawAsset.feePercent,
                  feeMinimum: withdrawAsset.feeMinimum)
    }
}

public class Sep24ServiceFeatures {

    public let accountCreation:Bool
    public let claimableBalances:Bool
    
    internal init(accountCreation: Bool, claimableBalances: Bool) {
        self.accountCreation = accountCreation
        self.claimableBalances = claimableBalances
    }
    
    internal convenience init(flags: Sep24FeatureFlags) {
        self.init(accountCreation: flags.accountCreation,
                  claimableBalances: flags.claimableBalances)
    }
}

public class Sep24ServiceFee {
    
    public let enabled:Bool
    public let authenticationRequired:Bool
    
    internal init(enabled: Bool, authenticationRequired: Bool) {
        self.enabled = enabled
        self.authenticationRequired = authenticationRequired
    }
    
    internal convenience init(feeInfo: Sep24FeeEndpointInfo) {
        self.init(enabled: feeInfo.enabled,
                  authenticationRequired: feeInfo.authenticationRequired)
    }
}
