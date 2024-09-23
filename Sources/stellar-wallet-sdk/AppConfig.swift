//
//  AppConfig.swift
//  
//
//  Created by Christian Rogobete on 19.09.24.
//

/// Application configuration.
public class AppConfig {
    
    /// Default signer implementation to be used across application
    public var defaultSigner:WalletSigner = DefaultSigner()
    
    /// Default client domain
    public var defalutClientDomain:String?
    
}
