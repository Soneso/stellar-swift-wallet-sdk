//
//  AssetId.swift
//
//
//  Created by Christian Rogobete on 23.09.24.
//

import stellarsdk

public protocol AssetId {
    var id:String {get}
    var scheme:String {get}
    var sep38:String {get}
}

public protocol StellarAssetId: AssetId {
    func toAsset() -> stellarsdk.Asset
    func fromAsset(asset:stellarsdk.Asset) throws -> StellarAssetId
}

public extension StellarAssetId {
    func fromAsset(asset:stellarsdk.Asset) throws -> StellarAssetId {
        let type = asset.type
        switch type {
        case AssetType.ASSET_TYPE_CREDIT_ALPHANUM4, AssetType.ASSET_TYPE_CREDIT_ALPHANUM12:
            do {
                return try IssuedAssetId(code: asset.code ?? "", issuer: asset.issuer?.accountId ?? "")
            } catch {
                throw ValidationError.invalidArgument(message: "invalid asset")
            }
        case AssetType.ASSET_TYPE_NATIVE:
            return NativeAssetId()
        default:
            throw ValidationError.invalidArgument(message: "unknown or unsupported asset type: \(type)")
        }
    }
}

public class IssuedAssetId: StellarAssetId {
    
    public var id: String
    public var scheme: String
    public var sep38: String
    
    public init(code:String, issuer:String) throws {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCode.count > 12 || trimmedCode.count < 0 {
            throw ValidationError.invalidArgument(message: "invalid issued asset code: \(code)")
        }
        do {
            let kp = try KeyPair(accountId: issuer)
        } catch {
            throw ValidationError.invalidArgument(message: "invalid issued asset issuer (account id): \(issuer)")
        }
        self.id = "\(trimmedCode):\(issuer)"
        self.scheme = "stellar"
        self.sep38 = "\(self.id):\(self.scheme)"
    }
    
    public func toAsset() -> stellarsdk.Asset {
        return Asset(canonicalForm: self.id)!
    }
}

public class NativeAssetId: StellarAssetId {
    
    public var id: String
    public var scheme: String
    public var sep38: String
    
    public init() {
        self.id = "native"
        self.scheme = "stellar"
        self.sep38 = "\(self.id):\(self.scheme)"
    }
    
    public func toAsset() -> stellarsdk.Asset {
        return Asset(type:AssetType.ASSET_TYPE_NATIVE)!
    }
}

public class FiatAssetId: AssetId {
    
    public var id: String
    public var scheme: String
    public var sep38: String
    
    public init(id:String) {
        self.id = id
        self.scheme = "iso4217"
        self.sep38 = "\(self.id):\(self.scheme)"
    }
}