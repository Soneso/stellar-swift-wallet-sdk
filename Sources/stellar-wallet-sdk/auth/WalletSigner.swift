//
//  WalletSigner.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

import stellarsdk

/// A Wallet Signer for signing Stellar transactions.
public protocol WalletSigner {
    /// Sign a transaction with a client keypair.
    /// - Parameters:
    ///   - tnx: The  transaction to sign
    ///   - network: The stellar network to sign for. E.g. `Network.testnet`
    ///   - accountKp: The keyPair to sign the transaction with.
    func signWithClientAccount(tnx:stellarsdk.Transaction, network:stellarsdk.Network, accountKp:SigningKeyPair) throws
    
    /// Sign a transaction using the domain account's keypair.
    /// - Parameters:
    ///   - transactionXdr: The base64 encoded XDR representation of the transaction to sign.
    ///   - networkPassphrase: The network passphrase for the Stellar network.
    func signWithDomainAccount(transactionXdr:String, networkPassphrase:String) async throws
}

/// Wallet signer that supports signing with a client signing keypair.
public class DefaultSigner:WalletSigner {
    /// Sign a transaction with a client keypair.
    /// - Parameters:
    ///   - tnx: The  transaction to sign
    ///   - network: The stellar network to sign for. E.g. `Network.testnet`
    ///   - accountKp: The keyPair to sign the transaction with.
    public func signWithClientAccount(tnx: stellarsdk.Transaction, network: stellarsdk.Network, accountKp: SigningKeyPair) {
        accountKp.sign(transaction: tnx, network: network)
    }
    
    /// Not supported. Throws `ValidationError.invalidArgument`
    public func signWithDomainAccount(transactionXdr: String, networkPassphrase: String) async throws {
        throw ValidationError.invalidArgument(message: "This signer can't sign transaction with domain")
    }
}

// Todo: DomainSigner = Wallet signer that supports signing with a client domain using standard [SigningData] reques and response type.
