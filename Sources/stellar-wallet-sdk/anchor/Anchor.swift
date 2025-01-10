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
    
    public var info:TomlInfo {
        get async throws {
            return try await infoHolder.info
        }
    }
    
    public var sep1:TomlInfo {
        get async throws {
            return try await info
        }
    }
    
    public var sep10:Sep10 {
        get async throws {
            let toml = try await infoHolder.info
            guard let webAuthEndpoint = toml.webAuthEndpoint, let signingKey = toml.signingKey else {
                throw AnchorAuthError.notSupported
            }
            return Sep10(config: config,
                         serverHomeDomain: homeDomain,
                         serverAuthEndpoint: webAuthEndpoint,
                         serverSigningKey: signingKey)
        }
    }
    
    public var sep24:Sep24 {
        get {
            return Sep24(anchor:self)
        }
    }
    
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
}

public class InfoHolder {
    public var network:Network
    public var homeDomain:String
    public var lang:String?
    private var cachedTomlInfo:TomlInfo?
    private var cachedServiceInfo:Sep24Info?
    
    public var info:TomlInfo {
        get async throws {
            if (cachedTomlInfo != nil) {
                return cachedTomlInfo!
            }
            
            let response = await StellarToml.from(domain: homeDomain)
            switch response {
            case .success(let response):
                cachedTomlInfo = TomlInfo(stellarToml: response)
                return cachedTomlInfo!
            case .failure(let error):
                throw error
            }
        }
    }
    
    public var serviceInfo:Sep24Info {
        get async throws {
            if let cachedServiceInfo = self.cachedServiceInfo {
                return cachedServiceInfo
            } else {
                let info = try await info
                guard let transferServerSep24 = info.services.sep24?.transferServerSep24 else {
                    throw AnchorError.interactiveFlowNotSupported
                }
                let interactiveService = InteractiveService(serviceAddress: transferServerSep24)
                let response = await interactiveService.info(language: self.lang)
                switch response {
                case .success(let response):
                    self.cachedServiceInfo = Sep24Info(info: response)
                    return self.cachedServiceInfo!
                case .failure(let error):
                    throw error
                }
            }
        }
    }
    
    public init(network:Network,
                homeDomain:String,
                lang:String? = nil) {
        self.network = network
        self.homeDomain = homeDomain
        self.lang = lang
    }
}
