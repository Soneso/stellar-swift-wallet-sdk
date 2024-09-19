//
//  AccountKeyPair.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

import stellarsdk

public protocol AccountKeyPair {
    var keyPair:KeyPair {get}
    var address:String {get}
    var publicKey:PublicKey {get}
}

public class PublicKeyPair:AccountKeyPair{
    public var keyPair: KeyPair
    public var address: String
    public var publicKey: stellarsdk.PublicKey
    
    public init(keyPair: KeyPair) {
        self.keyPair = keyPair
        self.address = keyPair.accountId
        self.publicKey = keyPair.publicKey
    }
    
    public convenience init(accountId: String) throws {
        self.init(keyPair: try KeyPair(accountId: accountId))
    }
}

public class SigningKeyPair:AccountKeyPair{
    public var keyPair: KeyPair
    public var address: String
    public var secretKey: String
    public var publicKey: stellarsdk.PublicKey
    
    public init(keyPair: KeyPair) throws {
        self.keyPair = keyPair
        if (keyPair.seed == nil) {
            throw ValidationError.invalidArgument(message: "This keypair doesn't have a private key and can't sign")
        }
        self.address = keyPair.accountId
        self.publicKey = keyPair.publicKey
        self.secretKey = keyPair.secretSeed
    }
    
    public convenience init(secretKey: String) throws {
        do {
            try self.init(keyPair: try KeyPair(secretSeed: secretKey))
        } catch {
            throw ValidationError.invalidArgument(message: "Invalid secret key")
        }
    }
    
    public static var random:SigningKeyPair {
        let kp = try! KeyPair.generateRandomKeyPair()
        return try! SigningKeyPair(keyPair: kp)
    };
    
    public func sign(transaction:Transaction, network:Network) {
        try! transaction.sign(keyPair: self.keyPair, network: network)
    }
    
    public func toPublicKeyPair() -> PublicKeyPair {
        return try! PublicKeyPair(accountId: address)
    }
    
}
