//
//  AssetId.swift
//
//
//  Created by Christian Rogobete on 23.09.24.
//

import stellarsdk

/// Protocol for handling assets in the wallet sdk.
public protocol AssetId {
    /// id of the asset.
    /// E.g. `USD` for a fialt asset 
    /// or `USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5` (code:issuer) for a stellar issued asset
    /// or `native` for stellar native asset (lumens, XLM)
    var id:String {get}
    
    /// Scheme of the asset. Possible values are `stellar` for stellar assets or `iso4217`for fiat assets
    var scheme:String {get}
    
    /// SEP-38 representation of the asset. E.g. `stellar:native` or `iso4217:USD` or `stellar:USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5`
    var sep38:String {get}
}

/// Represents an asset on the stellar network.
///
///  - Important: this class can not be used directly. It has a private initializer. Use `IssuedAssetId` or `NativeAssetId` classes instead.
///
public class StellarAssetId: AssetId, Hashable {
    /// id of the asset.
    /// E.g. `USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5` (code:issuer) for a stellar issued asset
    /// or `native` for stellar native asset (lumens, XLM)
    public var id: String
    
    /// Scheme of the asset.  Always `stellar`
    public var scheme: String
    
    /// SEP-38 representation of the asset. E.g. `stellar:native` or `stellar:USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5`
    public var sep38: String
    
    /// Filieprivate Constructor
    ///  - Parameter id: Id of the asset - `code:issuer` for a stellar issued asset or `native` for stellar native asset (lumens, XLM)
    fileprivate init(id:String) {
        self.id = id
        self.scheme = "stellar"
        self.sep38 = "\(self.scheme):\(self.id)"
    }
    
    /// Creates a  `IssuedAssetId` or  `NativeAssetId` from the given `stellarsdk.Asset`
    ///
    ///  This function throws a validation error `ValidationError.invalidArgument` if the given `stellarsdk.Asset`
    ///  is not an asset of type `ASSET_TYPE_CREDIT_ALPHANUM4` or `ASSET_TYPE_CREDIT_ALPHANUM12`or `ASSET_TYPE_NATIVE`
    ///
    /// - Parameter asset: the `stellarsdk.Asset` to create a  `IssuedAssetId` or  `NativeAssetId`from
    ///
    public static func fromAsset(asset:stellarsdk.Asset) throws -> StellarAssetId {
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
    
    /// Creates a  `IssuedAssetId` or  `NativeAssetId` from the given asset data
    ///
    ///  This function throws a validation error `ValidationError.invalidArgument` if the given data is not valid
    ///
    /// - Parameters:
    ///   - type: type: one of "native", "credit_alphanum4", "credit_alphanum12"
    ///   - code: asset code if not native
    ///   - issuerAccountId: account id of the asset issuer if not a native asset
    ///
    public static func fromAssetData(type:String, code:String? = nil, issuerAccountId:String? = nil ) throws -> StellarAssetId {
        
        switch type {
        case "credit_alphanum4", "credit_alphanum12":
            do {
                return try IssuedAssetId(code: code ?? "", issuer: issuerAccountId ?? "")
            } catch {
                throw ValidationError.invalidArgument(message: "invalid asset")
            }
        case "native":
            return NativeAssetId()
        default:
            throw ValidationError.invalidArgument(message: "unknown or unsupported asset type: \(type)")
        }
    }
    
    /// Converst this asset to a `stellarsdk.Asset`
    public func toAsset() -> stellarsdk.Asset {
        if (id == "native") {
            return Asset(type:AssetType.ASSET_TYPE_NATIVE)!
        }
        return Asset(canonicalForm: self.id)!
    }
    
    public static func == (lhs: StellarAssetId, rhs: StellarAssetId) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents an issued asset on the stellar network.
public class IssuedAssetId: StellarAssetId {
    
    public let code:String
    public let issuer:String
    
    /// Initializes the `IssuedAssetId`
    ///
    /// This initializer throws a validation error `ValidationError.invalidArgument` if the given code or issuer address are invalid.
    ///
    /// - Parameters:
    ///   - code: The code of the issued asset. E.g. `USDC`
    ///   - issuer: The address (account id) of the issuer of this asset. E.g. `GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5`
    
    public init(code:String, issuer:String) throws {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCode.count > 12 || trimmedCode.count < 0 {
            throw ValidationError.invalidArgument(message: "invalid issued asset code: \(code)")
        }
        do {
            let _ = try KeyPair(accountId: issuer)
        } catch {
            throw ValidationError.invalidArgument(message: "invalid issued asset issuer (account id): \(issuer)")
        }
        self.code = trimmedCode
        self.issuer = issuer
        super.init(id: "\(trimmedCode):\(issuer)")

    }
}

/// Represents the native asset (XLM) on the stellar network.
public class NativeAssetId: StellarAssetId {
    
    /// Initializer
    public init() {
        super.init(id: "native")
    }
}

/// Represents a fiat asset. E.g. `USD`.
public class FiatAssetId: AssetId {
    /// id of the asset. E.g. `USD`
    public var id: String
    
    /// Scheme of the asset.  Always `iso4217`
    public var scheme: String
    
    /// SEP-38 representation of the asset. E.g. `iso4217:USD`
    public var sep38: String
    
    /// Initializes a fiat asset.
    ///  - Parameter id: id of the fiat asset. E.g. `USD`
    public init(id:String) {
        self.id = id
        self.scheme = "iso4217"
        self.sep38 = "\(self.scheme):\(self.id)"
    }
}
