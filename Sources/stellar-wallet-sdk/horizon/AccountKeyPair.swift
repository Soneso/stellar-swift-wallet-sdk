//
//  AccountKeyPair.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

import stellarsdk

/// Stellar account's key pair. It can be either `PublicKeyPair` obtained from public key, or
/// `SigningKeyPair`, obtained from private key.
public protocol AccountKeyPair {
    /// The associated stellarsdk.KeyPair
    var keyPair:stellarsdk.KeyPair {get}
    
    /// Account Id (encoded String representation of the public key) from the keypair.
    var address:String {get}
    
    /// XDR Public key
    var publicKey:stellarsdk.PublicKey {get}
}

/// Public keypair containing only the public key, and can not be used for signing.
public class PublicKeyPair:AccountKeyPair {
    /// The associated stellarsdk.KeyPair
    public var keyPair: stellarsdk.KeyPair
    
    /// Account Id (encoded String representation of the public key) from the keypair.
    public var address: String
    
    /// XDR Public key
    public var publicKey: stellarsdk.PublicKey
    
    /// Initializes from a stellarsdk.KeyPair that must only have a public key.
    ///
    /// - Parameter keyPair: The `stellarsdk.KeyPair` to initialize from.
    ///
    public init(keyPair: stellarsdk.KeyPair) {
        self.keyPair = keyPair
        self.address = keyPair.accountId
        self.publicKey = keyPair.publicKey
    }
    
    /// Initializes from a stellar address (encoded String representation of the public key)
    ///
    ///  This initializer throws a `ValidationError.invalidArgument` if an invalid account id was given.
    ///
    /// - Parameter accountId: The stellar address of the account (encoded String representation of the public key)
    ///
    public convenience init(accountId: String) throws {
        do {
            self.init(keyPair: try KeyPair(accountId: accountId))
        } catch {
            throw ValidationError.invalidArgument(message: "Invalid account id")
        }
    }
}

/// Signing keypair containing the public and secret (private) key, and can be used for signing.
public class SigningKeyPair:AccountKeyPair{
    /// The associated stellarsdk.KeyPair
    public var keyPair: stellarsdk.KeyPair
    
    /// Account Id (encoded String representation of the public key) from the keypair.
    public var address: String
    
    /// Secret seed (encoded String representation of the private key) from the keypair.
    public var secretKey: String
    
    /// XDR Public key
    public var publicKey: stellarsdk.PublicKey
    
    /// Initializes from a stellarsdk.KeyPair that must  have a private key.
    ///
    /// Throws a `ValidationError.invalidArgument`if the given `stellarsdk.KeyPair` has no private key.
    ///
    /// - Parameter keyPair: The `stellarsdk.KeyPair` to initialize from.
    ///
    public init(keyPair: stellarsdk.KeyPair) throws {
        self.keyPair = keyPair
        if (keyPair.seed == nil) {
            throw ValidationError.invalidArgument(message: "This keypair doesn't have a private key and can't sign")
        }
        self.address = keyPair.accountId
        self.publicKey = keyPair.publicKey
        self.secretKey = keyPair.secretSeed
    }
    
    /// Initializes from a stellar secret seed (encoded String representation of the private key)
    ///
    ///  This initializer throws a `ValidationError.invalidArgument` if an invalid secret seed was given.
    ///
    /// - Parameter secretKey: The stellar secret seed of the account (encoded String representation of the private key)
    ///
    public convenience init(secretKey: String) throws {
        do {
            try self.init(keyPair: try stellarsdk.KeyPair(secretSeed: secretKey))
        } catch {
            throw ValidationError.invalidArgument(message: "Invalid secret key")
        }
    }
    
    /// Generates a new random SigningKeyPair
    public static var random:SigningKeyPair {
        let kp = try! KeyPair.generateRandomKeyPair()
        return try! SigningKeyPair(keyPair: kp)
    };
    
    /// Signs a given transaction of the given network.
    ///
    /// - Parameters:
    ///   - transaction: The transaction to sign
    ///   - network: The network to sing the transaction for. E.g. Network.testnet
    ///
    public func sign(transaction:stellarsdk.Transaction, network:stellarsdk.Network) {
        try! transaction.sign(keyPair: self.keyPair, network: network)
    }
    
    /// Creates a new `PublicKeyPair` from this `SigningKeyPair`.
    /// The new `PublicKeyPair` will contain only the public key and cannot be used for signing.
    public func toPublicKeyPair() -> PublicKeyPair {
        return try! PublicKeyPair(accountId: address)
    }
    
}
