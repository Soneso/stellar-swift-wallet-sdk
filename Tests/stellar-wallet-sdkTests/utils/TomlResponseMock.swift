//
//  TomlResponseMock.swift
//  
//
//  Created by Christian Rogobete on 18.02.25.
//

import Foundation
import stellarsdk

class TomlResponseMock: ResponsesMock {
    var host: String
    var serverSigningKey: String
    var authServer: String?
    var sep24TransferServer: String?
    var anchorQuoteServer:String?
    
    init(host:String, 
         serverSigningKey: String,
         authServer: String? = nil,
         sep24TransferServer:String? = nil,
         anchorQuoteServer:String? = nil) {
        self.host = host
        self.serverSigningKey = serverSigningKey
        self.authServer = authServer
        self.sep24TransferServer = sep24TransferServer
        self.anchorQuoteServer = anchorQuoteServer
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        
        let handler: MockHandler = { [weak self] mock, request in
            return self?.stellarToml
        }
        
        return RequestMock(host: host,
                           path: "/.well-known/stellar.toml",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    var stellarToml:String {
        get {
            return """
                # Sample stellar.toml
                VERSION="2.0.0"
                NETWORK_PASSPHRASE="\(Network.testnet.passphrase)"
                """ + (sep24TransferServer == nil ? "" : """
                TRANSFER_SERVER_SEP0024="\(sep24TransferServer!)"
                """) + (anchorQuoteServer == nil ? "" : """
                ANCHOR_QUOTE_SERVER="\(anchorQuoteServer!)"
                """ )
                +
                """
                SIGNING_KEY="\(serverSigningKey)"
                """ + (authServer == nil ? "" : """
                WEB_AUTH_ENDPOINT="\(authServer!)"
                """) +
                """
                [[CURRENCIES]]
                code="USDC"
                issuer="GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
                display_decimals=2

                [[CURRENCIES]]
                code="ETH"
                issuer="GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U"
                display_decimals=7
            """
        }
    }
}
