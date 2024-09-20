//
//  StellarConfig.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

import stellarsdk

public class StellarConfig {
 
    /**
        Network to be used.
     */
    public var network:Network
    
    /**
        URL of the horizon server
     */
    public var horizonUrl:String
    
    /**
     Default [base fee](https://developers.stellar.org/docs/encyclopedia/fees-surge-pricing-fee-strategies#network-fees-on-stellar)
     to be used
     */
    public var maxOperationFee:UInt32 = 100
    
    /**
     Default transaction timeout in seconds
     */
    public var defaultTimeout:UInt32 = 120
    
    public init(network: Network, horizonUrl:String, maxOperationFee:UInt32 = 100, defaultTimeout:UInt32 = 100) {
        self.network = network
        self.horizonUrl = horizonUrl
        self.maxOperationFee = maxOperationFee
        self.defaultTimeout = defaultTimeout
    }
    
    public static var publicNet:StellarConfig {
        return StellarConfig(network: Network.public, horizonUrl: StellarSDK.publicNetUrl)
    };
    
    public static var testNet:StellarConfig {
        return StellarConfig(network: Network.testnet, horizonUrl: StellarSDK.testNetUrl)
    };
    
    public static var futureNet:StellarConfig {
        return StellarConfig(network: Network.futurenet, horizonUrl: StellarSDK.futureNetUrl)
    };
    
}

