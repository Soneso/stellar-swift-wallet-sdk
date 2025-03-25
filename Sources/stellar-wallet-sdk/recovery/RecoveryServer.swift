//
//  RecoveryServer.swift
//  
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation

public class RecoveryServer {
    
    public var endpoint:String
    public var authEndpoint:String
    public var homeDomain:String
    public var walletSigner:WalletSigner?
    public var clientDomain:String?
    
    /// Constructor
    ///
    /// - Parameters:
    ///   - endpoint:  main endpoint (root domain) of SEP-30 recovery server. E.g. `https://recovery.example.com` or `https://example.com/recovery`, etc.
    ///   - authEndpoint: SEP-10 auth endpoint to be used. Should be in format `<https://...>`. E.g. `https://example.com/auth` or `https://auth.example.com` etc. )
    ///   - homeDomain: SEP-10 home domain. E.g. `recovery.example.com` or `example.com`, etc.
    ///   - walletSigner: Optional [WalletSigner] used to sign authentication
    ///   - clientDomain: Optional client domain
    ///
    public init(endpoint: String, authEndpoint: String, homeDomain: String, walletSigner: (any WalletSigner)? = nil, clientDomain: String? = nil) {
        self.endpoint = endpoint
        self.authEndpoint = authEndpoint
        self.homeDomain = homeDomain
        self.walletSigner = walletSigner
        self.clientDomain = clientDomain
    }
}
