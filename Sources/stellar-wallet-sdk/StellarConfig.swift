//
//  StellarConfig.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

import stellarsdk

/// Configuration for all Stellar-related activity.
public class StellarConfig {
 
    /// Network to be used. E.g. Network.testnet
    public var network:Network
    
    /// URL of the horizon server
    public var horizonUrl:String
    
    /// Default base fee - max fee per operation in stoops - to be used
    /// see: [base fee](https://developers.stellar.org/docs/encyclopedia/fees-surge-pricing-fee-strategies#network-fees-on-stellar)
    public var baseFee:UInt32 = 100
    
    /// Default transaction timeout in seconds
    public var txTimeout:UInt32 = 300
    
    public init(network: Network, horizonUrl:String, baseFee:UInt32 = 100, txTimeout:UInt32 = 300) {
        self.network = network
        self.horizonUrl = horizonUrl
        self.baseFee = baseFee
        self.txTimeout = txTimeout
    }
    
    /// Creates a new instance of `StellarConfig` for the public (main) Stellar network.
    public static var publicNet:StellarConfig {
        return StellarConfig(network: Network.public, horizonUrl: StellarSDK.publicNetUrl)
    };
    
    /// Creates a new instance of `StellarConfig` for the test Stellar network.
    public static var testNet:StellarConfig {
        return StellarConfig(network: Network.testnet, horizonUrl: StellarSDK.testNetUrl)
    };
    
    /// Creates a new instance of `StellarConfig` for the futurenet Stellar network.
    public static var futureNet:StellarConfig {
        return StellarConfig(network: Network.futurenet, horizonUrl: StellarSDK.futureNetUrl)
    };
    
}

