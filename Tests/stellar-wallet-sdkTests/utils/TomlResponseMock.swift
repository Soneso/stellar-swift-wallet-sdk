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
    var sep6TransferServer: String?
    var anchorQuoteServer:String?
    var kycServer:String?
    
    init(host:String, 
         serverSigningKey: String,
         authServer: String? = nil,
         sep24TransferServer:String? = nil,
         sep6TransferServer:String? = nil,
         anchorQuoteServer:String? = nil,
         kycServer:String? = nil) {
        self.host = host
        self.serverSigningKey = serverSigningKey
        self.authServer = authServer
        self.sep24TransferServer = sep24TransferServer
        self.sep6TransferServer = sep6TransferServer
        self.anchorQuoteServer = anchorQuoteServer
        self.kycServer = kycServer
        
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
                """) +  (sep6TransferServer == nil ? "" : """
                TRANSFER_SERVER="\(sep6TransferServer!)"
                """) + (anchorQuoteServer == nil ? "" : """
                ANCHOR_QUOTE_SERVER="\(anchorQuoteServer!)"
                """ )
                +
                """
                SIGNING_KEY="\(serverSigningKey)"
                """ + (authServer == nil ? "" : """
                WEB_AUTH_ENDPOINT="\(authServer!)"
                """) + (kycServer == nil ? "" : """
                KYC_SERVER="\(kycServer!)"
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
