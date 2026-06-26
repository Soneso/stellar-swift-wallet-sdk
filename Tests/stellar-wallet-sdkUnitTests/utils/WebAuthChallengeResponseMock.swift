//
//  WebAuthChallengeResponseMock.swift
//
//
//  Created by Christian Rogobete on 18.02.25.
//

import Foundation
import stellarsdk

class WebAuthChallengeResponseMock: ResponsesMock {
    var host: String
    var serverKeyPair: KeyPair
    var homeDomain: String?
    
    init(host:String, serverKeyPair:KeyPair, homeDomain:String? = nil) {
        self.host = host
        self.serverKeyPair = serverKeyPair
        self.homeDomain = homeDomain
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let account = mock.variables["account"] {
                mock.statusCode = 200
                return self?.requestSuccess(account: account)
            }
            mock.statusCode = 400
            return """
                {"error": "Bad request"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/auth",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func generateNonce(length: Int) -> String? {
        let nonce = NSMutableData(length: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, nonce!.length, nonce!.mutableBytes)
        if result == errSecSuccess {
            return (nonce! as Data).base64EncodedString()
        } else {
            return nil
        }
    }
    
    func getValidTimeBounds() -> TransactionPreconditions {
        return TransactionPreconditions(timeBounds: TimeBounds(minTime: UInt64(Date().timeIntervalSince1970),
                                                               maxTime: UInt64(Date().timeIntervalSince1970 + 300)))
    }
    
    func getValidFirstManageDataOp (accountId: String) -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: accountId, name: "\(homeDomain ?? AuthTestUtils.anchorDomain) auth", data: generateNonce(length: 64)?.data(using: .utf8))
    }
    
    func getValidSecondManageDataOp () -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: serverKeyPair.accountId, name: "web_auth_domain", data: host.data(using: .utf8))
    }
    
    func getResponseJson(_ transaction:Transaction) -> String {
        return """
                {
                "transaction": "\(try! transaction.encodedEnvelope())"
                }
                """
    }
    
    func getValidTxAccount() -> Account {
        return Account(keyPair: serverKeyPair, sequenceNumber: -1)
    }
    
    func requestSuccess(account: String) -> String {
 
        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [getValidFirstManageDataOp(accountId: account), getValidSecondManageDataOp()],
                                           memo: nil,
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
}
