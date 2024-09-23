//
//  Wallet.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

import stellarsdk

/// Wallet SDK main entry point. It provides methods to build wallet applications on the Stellar network.
public class Wallet {
    
    /// version number of the wallet sdk.
    public static var versionNumber:String = "0.0.1"
    
    /// Configuration for all Stellar-related activity.
    public var stellarConfig:StellarConfig
    
    /// Application configuration
    public var appConfig:AppConfig
    
    /// Stellar class for accessing the stellar network through horizon.
    public var stellar:Stellar
    
    /// Initializes a Wallet object from stellar and app config
    ///
    /// - Parameters:
    ///   - stellarConfig: The stellar config for all Stellar-related activity. See `StellarConfig`
    ///   - appConfig: The app config to be used accross the app. See `AppConfig`
    ///
    public init(stellarConfig: StellarConfig, appConfig:AppConfig) {
        self.stellarConfig = stellarConfig
        self.appConfig = appConfig
        self.stellar = Stellar(config: Config(stellar: stellarConfig, app: appConfig))
    }
    
    /// Initializes a Wallet object from stellar config. Uses the default `AppConfig` with a default wallet signer and no client domain.
    ///
    /// - Parameter stellarConfig: The stellar config for all Stellar-related activity. See `StellarConfig`
    ///
    public convenience init(stellarConfig: StellarConfig) {
        self.init(stellarConfig: stellarConfig, appConfig: AppConfig())
    }
    
    /// Creates a new instance of `Wallet` for the public (main) Stellar network.
    /// Uses the default `AppConfig` with a default wallet signer and no client domain.
    public static var publicNet:Wallet {
        return Wallet(stellarConfig:StellarConfig.publicNet)
    };
    
    /// Creates a new instance of `Wallet` for the test Stellar network.
    /// Uses the default `AppConfig` with a default wallet signer and no client domain.
    public static var testNet:Wallet {
        return Wallet(stellarConfig:StellarConfig.testNet)
    };
    
    /// Creates a new instance of `Wallet` for the futurenet Stellar network.
    /// Uses the default `AppConfig` with a default wallet signer and no client domain.
    public static var futureNet:Wallet {
        return Wallet(stellarConfig:StellarConfig.futureNet)
    };
}
