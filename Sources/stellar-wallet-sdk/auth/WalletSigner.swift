//
//  WalletSigner.swift
//
//
//  Created by Christian Rogobete on 19.09.24.
//

import stellarsdk
import Foundation

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

/// A Domain Signer used for signing Stellar transactions with a domain server.
public class DomainSigner:DefaultSigner {
    public var endpoint:URL
    public var requestHeaders: [String: String] = [:]
    
    /// Create a new instance of the DomainSigner class.
    ///
    /// - Parameters:
    ///   - url: The URL of the domain server endpoint used to sign the transaction
    ///   - requestHeaders: The HTTP headers for requests to the domain server. These headers can be used for authentication purposes.
    ///
    public init(url: String, requestHeaders: [String: String]? = nil ) throws {
        guard let endpointUrl = URL(string: url) else {
            throw ValidationError.invalidArgument(message: "invalid url")
        }
        self.endpoint = endpointUrl
        if requestHeaders != nil {
            self.requestHeaders = requestHeaders!
        }
        self.requestHeaders["Content-Type"] = "application/json"
    }
    
    /// Sign a transaction using the domain account's keypair.
    /// - Parameters:
    ///   - transactionXdr: The base64 encoded XDR representation of the transaction to sign.
    ///   - networkPassphrase: The network passphrase for the Stellar network.
    public func signWithDomainAccount(transactionXDR: String, networkPassPhrase: String) async throws -> String {
        var urlRequest = URLRequest(url: endpoint)
        requestHeaders.forEach {
            urlRequest.addValue($0.value, forHTTPHeaderField: $0.key)
        }
        urlRequest.httpMethod = "POST"
        let jsonData: [String : Any] = [
            "transaction": transactionXDR,
            "network_passphrase": networkPassPhrase
        ]
        let requestData = try JSONSerialization.data(withJSONObject:jsonData)
        urlRequest.httpBody = requestData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DomainSignerError.unexpectedResponse(response: response)
            }
            
            if httpResponse.statusCode == 200 {
                let decodedResponse = try? JSONDecoder().decode(DomainSignerResponse.self, from: data)
                if let transaction = decodedResponse?.transaction {
                    return transaction
                } else {
                    throw DomainSignerError.unexpectedResponse(response: httpResponse)
                }
            } else {
                throw DomainSignerError.unexpectedResponse(response: httpResponse)
            }
        } catch {
            throw DomainSignerError.requestError(error: error)
        }
    }
}

private class DomainSignerResponse: NSObject, Decodable {
    
    public var transaction:String?
    
    private enum CodingKeys: String, CodingKey {
        case transaction
    }
    
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        transaction = try values.decodeIfPresent(String.self, forKey: .transaction)
    }
}
