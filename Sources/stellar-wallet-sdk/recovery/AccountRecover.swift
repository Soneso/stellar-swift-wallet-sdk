//
//  AccountRecover.swift
//
//
//  Created by Christian Rogobete on 20.03.25.
//

import Foundation
import stellarsdk

public class AccountRecover {
    
    public let stellar:StellarConfig
    public let servers:[RecoveryServerKey:RecoveryServer]
    
    internal init(stellar: StellarConfig, servers: [RecoveryServerKey : RecoveryServer]) {
        self.stellar = stellar
        self.servers = servers
    }
    
    /// Replace lost device key with a new key.
    ///
    /// - Parameters:
    ///   - account: Target account
    ///   - newKey:  A key to replace the lost key with
    ///   - serverAuth: List of servers to use
    ///   - lostKey: (optional) lost device key. If not specified, it will try to deduce the key from the account signers list
    ///   - sponsorAddress: (optional) sponsor address of the transaction. Please note that not all SEP-30 servers support signing sponsored transactions.
    ///
    public func replaceDeviceKey(account:AccountKeyPair,
                                 newKey:AccountKeyPair,
                                 serverAuth:[RecoveryServerKey:RecoveryServerSigning],
                                 lostKey:AccountKeyPair? = nil,
                                 sponsorAddress:AccountKeyPair? = nil) async throws -> Transaction {
        
        let sdk = StellarSDK(withHorizonUrl: stellar.horizonUrl)
        var stellarAccount:AccountResponse? = nil
        var responseEnum = await sdk.accounts.getAccountDetails(accountId: account.address)
        switch responseEnum {
        case .success(let details):
            stellarAccount = details
        case .failure(let error):
            switch error {
            case .notFound(_, _):
                throw ValidationError.invalidArgument(message: "Account \(account.address) doesen't exist")
            default:
                throw error
            }
        }
        guard let stellarAccount = stellarAccount else {
            throw ValidationError.invalidArgument(message: "Account \(account.address) doesen't exist")
        }
        
        var sponsorAcc:AccountResponse? = nil
        if let sponsorAddress = sponsorAddress {
            responseEnum = await sdk.accounts.getAccountDetails(accountId: sponsorAddress.address)
            switch responseEnum {
            case .success(let details):
                sponsorAcc = details
            case .failure(let error):
                switch error {
                case .notFound(_, _):
                    throw ValidationError.invalidArgument(message: "Sponsor account \(sponsorAddress.address) doesen't exist")
                default:
                    throw error
                }
            }
        }
        
        var lost:AccountKeyPair? = nil
        var weight:Int? = nil
        if let lostKey = lostKey {
            lost = lostKey
            for signer in stellarAccount.signers {
                if signer.key == lostKey.address {
                    weight = signer.weight
                }
            }
            if weight == nil {
                throw ValidationError.invalidArgument(message: "Lost key doesn't belong to the account")
            }
        } else {
            let deduced = try deduceKey(stellarAccount: stellarAccount, serverAuth: serverAuth)
            lost = try PublicKeyPair(accountId: deduced.key)
            weight = deduced.weight
        }
        
        var operations:[stellarsdk.Operation] = []
        if let sponsorAddress = sponsorAddress {
            let begingSponsorshipOp = BeginSponsoringFutureReservesOperation(sponsoredAccountId: stellarAccount.accountId, 
                                                                             sponsoringAccountId: sponsorAddress.address)
            operations.append(begingSponsorshipOp)
        }
        
        let sLostKey = SignerKeyXDR.ed25519((try KeyPair(accountId: lost!.address)).publicKey.wrappedData32())
        let removeLostSignerOperation = try SetOptionsOperation(sourceAccountId:stellarAccount.accountId,
                                                          signer: sLostKey,
                                                          signerWeight: 0) // remove
        operations.append(removeLostSignerOperation)
        
        let sNewKey = SignerKeyXDR.ed25519((try KeyPair(accountId: newKey.address)).publicKey.wrappedData32())
        let addSignerOperation = try SetOptionsOperation(sourceAccountId:stellarAccount.accountId,
                                                         signer: sNewKey,
                                                         signerWeight: UInt32(weight!)) // add
        operations.append(addSignerOperation)
        
        if sponsorAddress != nil {
            let endSponsoringOp = EndSponsoringFutureReservesOperation(sponsoredAccountId: stellarAccount.accountId)
            operations.append(endSponsoringOp)
        }
        
        let tx = try Transaction(sourceAccount: sponsorAcc ?? stellarAccount, operations: operations, memo: Memo.none)
        
        return try await signWithRecoveryServers(transaction: tx, accountAddress: account, serverAuth: serverAuth)
    }
    
    /// Sign transaction with recovery servers. It is used to recover an account using
    /// [SEP-30](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md).
    ///
    /// - Parameters:
    ///   - transaction: Transaction with new signer to be signed by recovery servers
    ///   - accountAddress: Address of the account that is recovered
    ///   - serverAuth: List of servers to use
    ///
    public func signWithRecoveryServers(transaction:Transaction,
                                        accountAddress:AccountKeyPair,
                                        serverAuth:[RecoveryServerKey:RecoveryServerSigning]) async throws -> Transaction {
        
        for (key, val) in serverAuth {
            transaction.addSignature(signature: (try await getRecoveryServerTxnSignature(transaction: transaction,
                                                                      accountAddress: accountAddress.address,
                                                                      serverAuthKey: key,
                                                                      serverAuthVal: val)))
        }
        return transaction

    }
    
    private func getRecoveryServerTxnSignature(transaction:Transaction, 
                                               accountAddress:String,
                                               serverAuthKey: RecoveryServerKey,
                                               serverAuthVal:RecoveryServerSigning) async throws -> DecoratedSignatureXDR {
        if let server  = servers[serverAuthKey] {
            let service = RecoveryService(serviceAddress: server.endpoint)
            guard let txB64 = transaction.toEnvelopeXdrBase64() else {
                throw ValidationError.invalidArgument(message: "Cound not encode transaction")
            }
            let responseEnum = await service.signTransaction(address: accountAddress,
                                                                 signingAddress: serverAuthVal.signerAddress,
                                                                 transaction: txB64,
                                                                 jwt: serverAuthVal.authToken)
            switch responseEnum {
            case .success(let response):
                let kp = try KeyPair(accountId: serverAuthVal.signerAddress)
                var publicKeyData = kp.publicKey.bytes
                let hint = Data(bytes: &publicKeyData, count: publicKeyData.count).suffix(4)
                guard let signatureData = Data(base64Encoded: response.signature) else {
                    throw RecoveryServiceError.parsingResponseFailed(message: "Cound not base 64 decode signature obtained from recovery server: \(server.endpoint)")
                }
                return DecoratedSignatureXDR(hint: WrappedData4(hint), signature: signatureData)
            case .failure(let error):
                print("Service address: \(server.endpoint)")
                print("Account address: \(accountAddress)")
                print("Signing address: \(serverAuthVal.signerAddress)")
                print("Err: \(error)")
                throw error
            }
        } else {
            throw ValidationError.invalidArgument(message: "key not found in servers map")
        }
    }
    
    private func deduceKey(stellarAccount:AccountResponse, serverAuth:[RecoveryServerKey:RecoveryServerSigning]) throws -> AccountSignerResponse {
        
        var recoverySigners:[String] = []
        for s in serverAuth.values {
            recoverySigners.append(s.signerAddress)
        }
        
        var nonRecoverySigners:[AccountSignerResponse] = []
        for signer in stellarAccount.signers {
            if signer.weight != 0 && !recoverySigners.contains(signer.key) {
                nonRecoverySigners.append(signer)
            }
        }
        
        if nonRecoverySigners.count > 1 {
            var groupedRecovery:[Int:[AccountSignerResponse]] = [:]
            for signer in stellarAccount.signers {
                if recoverySigners.contains(signer.key) {
                    if groupedRecovery[signer.weight] != nil {
                        groupedRecovery[signer.weight]!.append(signer)
                    } else {
                        groupedRecovery[signer.weight] = [signer]
                    }
                }
            }
            if groupedRecovery.count == 1 {
                let recoveryWeight = groupedRecovery.first!.value.first!.weight
                let filtered:[AccountSignerResponse] = nonRecoverySigners.filter{$0.weight != recoveryWeight}
                if filtered.count != 1 {
                    throw ValidationError.invalidArgument(message: "Couldn't deduce lost key. Please provide lost key explicitly")
                }
                return filtered.first!
            } else {
                throw ValidationError.invalidArgument(message: "Couldn't deduce lost key. Please provide lost key explicitly")
            }
        } else {
            if nonRecoverySigners.isEmpty {
                throw ValidationError.invalidArgument(message: "No device key is setup for this account")
            } else {
                return nonRecoverySigners.first!
            }
        }
    }
    
}
