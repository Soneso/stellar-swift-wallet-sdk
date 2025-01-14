//
//  TomlInfo.swift
//
//
//  Created by Christian Rogobete on 08.01.25.
//

import Foundation
import stellarsdk

public class TomlInfo {
    public let version:String?
    public let networkPassphrase:String?
    public let federationServer:String?
    public let authServer:String?
    public let transferServer:String?
    public let transferServerSep24:String?
    public let kycServer:String?
    public let webAuthEndpoint:String?
    public let signingKey:String?
    public let horizonUrl:String?
    public let accounts:[String]?
    public let uriRequestSigningKey:String?
    public let directPaymentServer:String?
    public let anchorQuoteServer:String?
    public let documentaion:InfoDocumentation?
    public let principals:[InfoContact]?
    public let currencies:[InfoCurrency]?
    public let validators:[InfoValidator]?
    
    public var hasAuth:Bool {
        get {
            return self.webAuthEndpoint != nil && self.signingKey != nil
        }
    }
    
    public var services:InfoServices {
        get {
            var sep6:Sep6InfoData? = nil
            var sep10:Sep10InfoData? = nil
            var sep12:Sep12InfoData? = nil
            var sep24:Sep24InfoData? = nil
            var sep31:Sep31InfoData? = nil
            
            if let transferServer = self.transferServer {
                sep6 = Sep6InfoData(transferServer: transferServer, anchorQuoteServer: self.anchorQuoteServer)
            }
            
            if let transferServer = self.transferServer {
                sep6 = Sep6InfoData(transferServer: transferServer, anchorQuoteServer: self.anchorQuoteServer)
            }
            
            if let webAuthEndpoint = self.webAuthEndpoint, let signingKey = self.signingKey {
                sep10 = Sep10InfoData(webAuthEndpoint: webAuthEndpoint, signingKey: signingKey)
            }
            
            if let kycServer = self.kycServer {
                sep12 = Sep12InfoData(kycServer: kycServer, signingKey: signingKey)
            }
            
            if let transferServerSep24 = self.transferServerSep24 {
                sep24 = Sep24InfoData(transferServerSep24: transferServerSep24, hasAuth: hasAuth)
            }
            
            if let directPaymentServer = self.directPaymentServer {
                sep31 = Sep31InfoData(directPaymentServer: directPaymentServer,
                                      hasAuth: hasAuth,
                                      kycServer: self.kycServer,
                                      anchorQuoteServer: self.anchorQuoteServer)
            }
            
            return InfoServices(sep6: sep6, 
                                sep10: sep10,
                                sep12: sep12,
                                sep24: sep24,
                                sep31: sep31)

        }
    }
    
    internal init(stellarToml:StellarToml) {
        self.version = stellarToml.accountInformation.version
        self.networkPassphrase = stellarToml.accountInformation.networkPassphrase
        self.federationServer = stellarToml.accountInformation.federationServer
        self.authServer = stellarToml.accountInformation.authServer
        self.transferServer = stellarToml.accountInformation.transferServer
        self.transferServerSep24 = stellarToml.accountInformation.transferServerSep24
        self.kycServer = stellarToml.accountInformation.kycServer
        self.webAuthEndpoint = stellarToml.accountInformation.webAuthEndpoint
        self.signingKey = stellarToml.accountInformation.signingKey
        self.horizonUrl = stellarToml.accountInformation.horizonUrl
        self.accounts = stellarToml.accountInformation.accounts
        self.uriRequestSigningKey = stellarToml.accountInformation.uriRequestSigningKey
        self.directPaymentServer = stellarToml.accountInformation.directPaymentServer
        self.anchorQuoteServer = stellarToml.accountInformation.anchorQuoteServer
        self.documentaion = InfoDocumentation(documentation: stellarToml.issuerDocumentation)
        
        if !stellarToml.pointsOfContact.isEmpty {
            var principals:[InfoContact] = []
            for poc in stellarToml.pointsOfContact {
                principals.append(InfoContact(pointOfContact: poc))
            }
            self.principals = principals
        } else {
            self.principals = nil
        }
        
        if !stellarToml.currenciesDocumentation.isEmpty {
            var currencies:[InfoCurrency] = []
            for curr in stellarToml.currenciesDocumentation {
                currencies.append(InfoCurrency(currency: curr))
            }
            self.currencies = currencies
        } else {
            self.currencies = nil
        }
        
        if !stellarToml.validatorsInformation.isEmpty {
            var validators:[InfoValidator] = []
            for validator in stellarToml.validatorsInformation {
                validators.append(InfoValidator(validator: validator))
            }
            self.validators = validators
        } else {
            self.validators = nil
        }
    }
}


public class InfoDocumentation {
    public let orgName:String?
    public let orgDba:String?
    public let orgUrl:String?
    public let orgLogo:String?
    public let orgDescription:String?
    public let orgPhysicalAddress:String?
    public let orgPhysicalAddressAttestation:String?
    public let orgPhoneNumber:String?
    public let orgPhoneNumberAttestation:String?
    public let orgKeybase:String?
    public let orgTwitter:String?
    public let orgGithub:String?
    public let orgOfficialEmail:String?
    public let orgSupportEmail:String?
    public let orgLicensingAuthority:String?
    public let orgLicenseType:String?
    public let orgLicenseNumber:String?
    
    internal init(documentation:IssuerDocumentation) {
        self.orgName = documentation.orgName
        self.orgDba = documentation.orgDBA
        self.orgUrl = documentation.orgURL
        self.orgLogo = documentation.orgLogo
        self.orgDescription = documentation.orgDescription
        self.orgPhysicalAddress = documentation.orgPhysicalAddress
        self.orgPhysicalAddressAttestation = documentation.orgPhysicalAddressAttestation
        self.orgPhoneNumber = documentation.orgPhoneNumber
        self.orgPhoneNumberAttestation = documentation.orgPhoneNumberAttestation
        self.orgKeybase = documentation.orgKeybase
        self.orgTwitter = documentation.orgTwitter
        self.orgGithub = documentation.orgGithub
        self.orgOfficialEmail = documentation.orgOfficialEmail
        self.orgSupportEmail = documentation.orgSupportEmail
        self.orgLicensingAuthority = documentation.orgLicensingAuthority
        self.orgLicenseType = documentation.orgLicenseType
        self.orgLicenseNumber = documentation.orgLicenseNumber
    }
}

public class InfoContact {
    public let name:String?
    public let email:String?
    public let keybase:String?
    public let telegram:String?
    public let twitter:String?
    public let github:String?
    public let idPhotoHash:String?
    public let verificationPhotoHash:String?
    
    internal init(pointOfContact:PointOfContactDocumentation) {
        self.name = pointOfContact.name
        self.email = pointOfContact.email
        self.keybase = pointOfContact.keybase
        self.telegram = pointOfContact.telegram
        self.twitter = pointOfContact.twitter
        self.github = pointOfContact.github
        self.idPhotoHash = pointOfContact.idPhotoHash
        self.verificationPhotoHash = pointOfContact.verificationPhotoHash
    }
}

public class InfoValidator {
    public let alias:String?
    public let displayName:String?
    public let publicKey:String?
    public let host:String?
    
    internal init(validator:ValidatorInformation) {
        self.alias = validator.alias
        self.displayName = validator.displayName
        self.publicKey = validator.publicKey
        self.host = validator.host
    }
}

public class InfoCurrency {
    public let code:String?
    public let issuer:String?
    public let codeTemplate:String?
    public let status:String?
    public let displayDecimals:Int?
    public let name:String?
    public let desc:String?
    public let conditions:String?
    public let image:String?
    public let fixedNumber:Int?
    public let maxNumber:Int?
    public let isUnlimited:Bool?
    public let isAssetAnchored:Bool?
    public let anchorAssetType:String?
    public let anchorAsset:String?
    public let attestationOfReserve:String?
    public let redemptionInstructions:String?
    public let collateralAddresses:[String]?
    public let collateralAddressMessages:[String]?
    public let collateralAddressSignatures:[String]?
    public let regulated:Bool?
    public let approvalServer:String?
    public let approvalCriteria:String?
    
    public var assetId:StellarAssetId {
        get throws {
            guard let assetCode = self.code else {
                return NativeAssetId()
            }
            if assetCode == "native" {
                return NativeAssetId()
            }
            guard let assetIssuer = self.issuer else {
                throw ValidationError.invalidArgument(message: "invalid asset code and issuer pair: \(assetCode):nil")
            }
            return try IssuedAssetId(code: assetCode, issuer: assetIssuer)
        }
    }
    
    internal init(currency:CurrencyDocumentation) {
        self.code = currency.code
        self.issuer = currency.issuer
        self.codeTemplate = currency.codeTemplate
        self.status = currency.status
        self.displayDecimals = currency.displayDecimals
        self.name = currency.name
        self.desc = currency.desc
        self.conditions = currency.conditions
        self.image = currency.image
        self.fixedNumber = currency.fixedNumber
        self.maxNumber = currency.maxNumber
        self.isUnlimited = currency.isUnlimited
        self.isAssetAnchored = currency.isAssetAnchored
        self.anchorAssetType = currency.anchorAssetType
        self.anchorAsset = currency.anchorAsset
        self.attestationOfReserve = currency.attestationOfReserve
        self.redemptionInstructions = currency.redemptionInstructions
        self.collateralAddresses = currency.collateralAddresses
        self.collateralAddressSignatures = currency.collateralAddressSignatures
        self.collateralAddressMessages = currency.collateralAddressMessages
        self.regulated = currency.regulated
        self.approvalServer = currency.approvalServer
        self.approvalCriteria = currency.approvalCriteria

    }
}

public class InfoServices {
    
    public let sep6:Sep6InfoData?
    public let sep10:Sep10InfoData?
    public let sep12:Sep12InfoData?
    public let sep24:Sep24InfoData?
    public let sep31:Sep31InfoData?
    
    internal init(sep6: Sep6InfoData? = nil, 
                  sep10: Sep10InfoData? = nil,
                  sep12: Sep12InfoData? = nil,
                  sep24: Sep24InfoData? = nil,
                  sep31: Sep31InfoData? = nil) {
        
        self.sep6 = sep6
        self.sep10 = sep10
        self.sep12 = sep12
        self.sep24 = sep24
        self.sep31 = sep31
    }
}

public class Sep6InfoData {
    
    public let transferServer:String
    public let anchorQuoteServer:String?
    
    internal init(transferServer: String, anchorQuoteServer: String? = nil) {
        self.transferServer = transferServer
        self.anchorQuoteServer = anchorQuoteServer
    }
}

public class Sep10InfoData {
    
    public let webAuthEndpoint:String
    public let signingKey:String
    
    internal init(webAuthEndpoint: String, signingKey: String) {
        self.webAuthEndpoint = webAuthEndpoint
        self.signingKey = signingKey
    }
}

public class Sep12InfoData {

    public let kycServer:String
    public let signingKey:String?
    
    internal init(kycServer: String, signingKey: String? = nil) {
        self.kycServer = kycServer
        self.signingKey = signingKey
    }
}

public class Sep24InfoData {
    
    public let transferServerSep24:String
    public let hasAuth:Bool
    
    internal init(transferServerSep24: String, hasAuth: Bool) {
        self.transferServerSep24 = transferServerSep24
        self.hasAuth = hasAuth
    }
}

public class Sep31InfoData {

    public let directPaymentServer:String
    public let hasAuth:Bool
    public let kycServer:String?
    public let anchorQuoteServer:String?

    internal init(directPaymentServer: String, hasAuth: Bool, kycServer: String? = nil, anchorQuoteServer: String? = nil) {
        self.directPaymentServer = directPaymentServer
        self.hasAuth = hasAuth
        self.kycServer = kycServer
        self.anchorQuoteServer = anchorQuoteServer
    }
}
