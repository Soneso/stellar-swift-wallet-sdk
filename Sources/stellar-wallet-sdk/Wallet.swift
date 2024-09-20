//
//  Wallet.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

import stellarsdk

public class Wallet {
    public static var versionNumber:String = "0.0.1"
    public var stellarConfig:StellarConfig
    public var appConfig:AppConfig
    public var stellar:Stellar
    
    public init(stellarConfig: StellarConfig, appConfig:AppConfig) {
        self.stellarConfig = stellarConfig
        self.appConfig = appConfig
        self.stellar = Stellar(config: Config(stellar: stellarConfig, app: appConfig))
    }
    
    public convenience init(stellarConfig: StellarConfig) {
        self.init(stellarConfig: stellarConfig, appConfig: AppConfig())
    }
    
    public static var publicNet:Wallet {
        return Wallet(stellarConfig:StellarConfig.publicNet)
    };
    
    public static var testNet:Wallet {
        return Wallet(stellarConfig:StellarConfig.testNet)
    };
    
    public static var futureNet:Wallet {
        return Wallet(stellarConfig:StellarConfig.futureNet)
    };
}
