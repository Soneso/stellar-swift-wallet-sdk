//
//  WalletSigner.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

import stellarsdk

public protocol WalletSigner {
    func signWithClientAccount(tnx:stellarsdk.Transaction, network:stellarsdk.Network, account:AccountKeyPair) throws
    func signWithDomainAccount(transactionXdr:String, networkPassphrase:String) throws
}

public class DefaultSigner:WalletSigner {
    public func signWithClientAccount(tnx: stellarsdk.Transaction, network: stellarsdk.Network, account: any AccountKeyPair) throws {
        if account is SigningKeyPair {
            (account as! SigningKeyPair).sign(transaction: tnx, network: network)
        } else {
            throw ValidationError.invalidArgument(message: "Can't sign with provided public keypair")
        }
    }
    
    public func signWithDomainAccount(transactionXdr: String, networkPassphrase: String) throws {
        throw ValidationError.invalidArgument(message: "This signer can't sign transaction with domain")
    }
}

// Todo: DomainSigner
