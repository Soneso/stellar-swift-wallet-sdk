//
//  Config.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

/// Internal class for passing configurations.
internal class Config {
    public var stellar:StellarConfig
    public var app:AppConfig
    
    public init(stellar:StellarConfig, app:AppConfig) {
        self.stellar = stellar
        self.app = app
    }
}
