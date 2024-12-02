//
//  AuthTest.swift
//  
//
//  Created by Christian Rogobete on 02.12.24.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class AuthTest: XCTestCase {
    let wallet = Wallet.testNet
    let accountKeyPair = Wallet.testNet.stellar.account.createKeyPair()
    let serverHomeDomain = "testanchor.stellar.org"
    
    func testBasics() async throws {
        let anchor = wallet.anchor(homeDomain: serverHomeDomain)
        let info = try await anchor.getInfo()
        XCTAssertEqual("https://testanchor.stellar.org/auth", info.accountInformation.webAuthEndpoint)
        XCTAssertEqual("GCUZ6YLL5RQBTYLTTQLPCM73C5XAIUGK2TIMWQH7HPSGWVS2KJ2F3CHS", info.accountInformation.signingKey)
        
        let sep10 = try await anchor.sep10()
        let authToken = try await sep10.authenticate(userKeyPair: accountKeyPair)
        XCTAssertEqual("https://testanchor.stellar.org/auth", authToken.issuer)
    }
    
}
