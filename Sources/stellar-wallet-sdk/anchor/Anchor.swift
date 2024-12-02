//
//  Anchor.swift
//  
//
//  Created by Christian Rogobete on 02.12.24.
//

import Foundation
import stellarsdk

public class Anchor {
    internal var config:Config
    public var homeDomain:String
    public var lang:String?
    public var infoHolder:InfoHolder
    
    internal init(config:Config,
                homeDomain:String,
                lang:String? = nil) {
        
        self.config = config
        self.homeDomain = homeDomain
        self.lang = lang
        self.infoHolder = InfoHolder(network: config.stellar.network, 
                                     homeDomain: homeDomain,
                                     lang: lang)
    }
    
    public func sep1() async throws -> StellarToml {
        return try await infoHolder.info()
    }
    
    public func getInfo() async throws -> StellarToml {
        return try await infoHolder.info()
    }
    
    public func sep10() async throws -> Sep10 {
        let toml = try await infoHolder.info()
        if (toml.accountInformation.webAuthEndpoint == nil || toml.accountInformation.signingKey == nil) {
            throw AnchorAuthError.notSupported
        }
        return Sep10(config: config,
                     serverHomeDomain: homeDomain,
                     serverAuthEndpoint: toml.accountInformation.webAuthEndpoint!,
                     serverSigningKey: toml.accountInformation.signingKey!)
    }
    
}

public class InfoHolder {
    public var network:Network
    public var homeDomain:String
    public var lang:String?
    private var tomlInfo:StellarToml?
    
    public init(network:Network,
                homeDomain:String,
                lang:String? = nil) {
        self.network = network
        self.homeDomain = homeDomain
        self.lang = lang
    }
    
    
    public func info() async throws -> StellarToml {
        
        if (tomlInfo != nil) {
            return tomlInfo!
        }
        
        let response = await StellarToml.from(domain: homeDomain)
        switch response {
        case .success(let response):
            tomlInfo = response
            return response
        case .failure(let error):
            throw error
        }
    }
}
