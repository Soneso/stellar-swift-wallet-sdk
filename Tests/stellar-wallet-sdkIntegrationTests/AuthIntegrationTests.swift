//
//  AuthIntegrationTests.swift
//
//
//  Created by Christian Rogobete.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

/// Live SEP-10 web authentication tests that run against public test infrastructure
/// (the Stellar test anchor and a remote client domain signer). These require network
/// access and therefore live in the integration test target rather than the unit suite.
final class AuthIntegrationTests: XCTestCase {

    let wallet = Wallet.testNet

    /// Authenticates against the live test anchor and validates the returned token issuer.
    func testStellarAnchorBasics() async throws {
        let anchor = wallet.anchor(homeDomain: "testanchor.stellar.org")
        let info = try await anchor.info
        XCTAssertEqual("https://testanchor.stellar.org/auth", info.webAuthEndpoint)
        XCTAssertEqual("GCHLHDBOKG2JWMJQBTLSL5XG6NO7ESXI2TAQKZXCXWXB5WI2X6W233PR", info.signingKey)

        let sep10 = try await anchor.sep10
        let accountKeyPair = wallet.stellar.account.createKeyPair()
        let authToken = try await sep10.authenticate(userKeyPair: accountKeyPair)
        XCTAssertEqual("https://testanchor.stellar.org/auth", authToken.issuer)
    }

    /// Authenticates with a client domain signed remotely by an external domain signer.
    func testClientDomainRemote() async throws {
        let anchor = wallet.anchor(homeDomain: "testanchor.stellar.org")
        let authKey = SigningKeyPair.random

        // Client domain signer src: https://github.com/Soneso/go-server-signer
        let clientDomain = "testsigner.stellargate.com"
        let clientDomainSigner = try DomainSigner(url: "https://\(clientDomain)/sign-sep-10",
                                                  requestHeaders: ["Authorization":
                                                                    "Bearer 7b23fe8428e7fb9b3335ed36c39fb5649d3cd7361af8bf88c2554d62e8ca3017"])
        let sep10 = try await anchor.sep10
        let authToken = try await sep10.authenticate(userKeyPair: authKey,
                                                     clientDomain: clientDomain,
                                                     clientDomainSigner: clientDomainSigner)
        XCTAssertFalse(authToken.jwt.isEmpty)
    }
}
