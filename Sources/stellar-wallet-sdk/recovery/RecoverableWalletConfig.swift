//
//  RecoverableWalletConfig.swift
//
//
//  Created by Christian Rogobete on 21.03.25.
//

import Foundation

public class RecoverableWalletConfig {

    
    public var accountAddress:AccountKeyPair
    public var deviceAddress:AccountKeyPair
    public var accountThreshold:AccountThreshold
    public var accountIdentity:[RecoveryServerKey:[RecoveryAccountIdentity]]
    public var signerWeight:SignerWeight
    public var sponsorAddress:AccountKeyPair?
    
    /// Constructor
    ///
    /// - Parameters:
    ///   - accountAddress: Stellar address of the account that is registering
    ///   - deviceAddress: Stellar address of the device that is added as a primary signer. It will replace the master key of [accountAddress]
    ///   - accountThreshold: Low, medium, and high thresholds to set on the account
    ///   - accountIdentity: A list of account identities to be registered with the recovery servers
    ///   - signerWeight: Signer weight of the device and recovery keys to set
    ///   - sponsorAddress: (optional) Stellar address of the account sponsoring this transaction
    ///
    public init(accountAddress: any AccountKeyPair,
                deviceAddress: any AccountKeyPair,
                accountThreshold: AccountThreshold,
                accountIdentity: [RecoveryServerKey : [RecoveryAccountIdentity]],
                signerWeight: SignerWeight,
                sponsorAddress: (any AccountKeyPair)? = nil) {
        
        self.accountAddress = accountAddress
        self.deviceAddress = deviceAddress
        self.accountThreshold = accountThreshold
        self.accountIdentity = accountIdentity
        self.signerWeight = signerWeight
        self.sponsorAddress = sponsorAddress
    }
}
