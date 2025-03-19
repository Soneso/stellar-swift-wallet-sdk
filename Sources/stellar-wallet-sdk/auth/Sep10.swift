//
//  Sep10.swift
//
//
//  Created by Christian Rogobete on 30.11.24.
//

import Foundation
import stellarsdk

public class Sep10 {
    
    internal var config:Config
    public var serverHomeDomain:String
    public var serverAuthEndpoint:String
    public var serverSigningKey:String
    
    internal init(config: Config, 
                  serverHomeDomain:String,
                  serverAuthEndpoint:String,
                  serverSigningKey:String) {
        self.config = config
        self.serverHomeDomain = serverHomeDomain
        self.serverAuthEndpoint = serverAuthEndpoint
        self.serverSigningKey = serverSigningKey
    }
    
    public func authenticate(userKeyPair:AccountKeyPair, 
                             memoId:UInt64? = nil,
                             clientDomain:String? = nil,
                             clientDomainSigner:WalletSigner? = nil) async throws -> AuthToken {
        
        let webAuth = WebAuthenticator(authEndpoint: serverAuthEndpoint,
                                       network: config.stellar.network,
                                       serverSigningKey: serverSigningKey,
                                       serverHomeDomain: serverHomeDomain)
        
        if let clientDomain = clientDomain, let clientDomainSigner = clientDomainSigner {
            // get client domain account id
            var clientDomainAccountId:String?
            let stellarToml = await StellarToml.from(domain: clientDomain)
            switch stellarToml {
            case .success(let response):
                clientDomainAccountId = response.accountInformation.signingKey
            case .failure(let error):
                throw error
            }
            
            guard let clientDomainAccountId = clientDomainAccountId else {
                throw AnchorAuthError.clientDomainSigningKeyNotFound(clientDomain:clientDomain)
            }
            
            guard let clientDomainKeyPair = try? KeyPair(accountId: clientDomainAccountId) else {
                throw AnchorAuthError.invaildClientDomainSigningKey(clientDomain: clientDomain, key: clientDomainAccountId)
            }
            
            let response = await webAuth.jwtToken(forUserAccount: userKeyPair.address,
                                                  memo: memoId,
                                                  signers: [userKeyPair.keyPair],
                                                  homeDomain: serverHomeDomain,
                                                  clientDomain: clientDomain,
                                                  clientDomainAccountKeyPair: clientDomainKeyPair,
                                                  clientDomainSigningFunction: { (txEnvelopeXdr) async throws in
                return try await clientDomainSigner.signWithDomainAccount(transactionXdr: txEnvelopeXdr,
                                                                          networkPassphrase:self.config.stellar.network.passphrase)})
            
            switch response {
            case .success(let jwtToken):
                return try AuthToken(jwt: jwtToken)
            case .failure(let error):
                throw error
            }
        } else {
            let response = await webAuth.jwtToken(forUserAccount: userKeyPair.address,
                                                  memo: memoId,
                                                  signers: [userKeyPair.keyPair],
                                                  homeDomain: serverHomeDomain)
            switch response {
            case .success(let jwtToken):
                return try AuthToken(jwt: jwtToken)
            case .failure(let error):
                throw error
            }
        }
    }
}

public class AuthToken {
    public var jwt:String
    public var decodedToken:[String: Any]
    public var issuer:String
    public var principalAccount:String
    public var issuedAt:Date
    public var expiresAt:Date
    public var clientDomain:String?
    public var signature:String
    
    public var account:String {
        get {
            return principalAccount.components(separatedBy: ":").first!
        }
    }
    
    public init(jwt:String) throws {
        self.jwt = jwt
        self.decodedToken = try AuthToken.decode(jwtToken: jwt)
        if let iss = self.decodedToken["iss"] as? String {
            self.issuer = "\(iss)"
        } else {
            throw AnchorAuthError.invalidJwtToken
        }
        if let sub = self.decodedToken["sub"] as? String {
            self.principalAccount = "\(sub)"
        } else {
            throw AnchorAuthError.invalidJwtToken
        }
        if let iat = self.decodedToken["iat"] as? Int {
            self.issuedAt = Date(timeIntervalSince1970: Double(iat))
        } else {
            throw AnchorAuthError.invalidJwtToken
        }
        if let exp = self.decodedToken["exp"] as? Int {
            self.expiresAt = Date(timeIntervalSince1970: Double(exp))
        } else {
            throw AnchorAuthError.invalidJwtToken
        }
        if let clientDomain = self.decodedToken["client_domain"] as? String {
            self.clientDomain = clientDomain
        }
        
        let segments = jwt.components(separatedBy: ".")
        if (segments.count != 3) {
            throw AnchorAuthError.invalidJwtToken
        }
        self.signature = segments[2]
    }
    
    private static func decode(jwtToken jwt: String) throws -> [String: Any] {

        func base64Decode(_ base64: String) throws -> Data {
            let base64 = base64
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            let padded = base64.padding(toLength: ((base64.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            guard let decoded = Data(base64Encoded: padded) else {
                throw AnchorAuthError.invalidJwtToken
            }
            return decoded
        }

        func decodeJWTPart(_ value: String) throws -> [String: Any] {
            let bodyData = try base64Decode(value)
            let json = try JSONSerialization.jsonObject(with: bodyData, options: [])
            guard let payload = json as? [String: Any] else {
                throw AnchorAuthError.invalidJwtPayload
            }
            return payload
        }

        let segments = jwt.components(separatedBy: ".")
        if (segments.count != 3) {
            throw AnchorAuthError.invalidJwtToken
        }
        let decodedHeader:[String: Any] = try decodeJWTPart(segments[0])
        let decodedBody:[String: Any] = try decodeJWTPart(segments[1])
        return decodedHeader.merging(decodedBody, uniquingKeysWith: { (first, _) in first })
    }
}
