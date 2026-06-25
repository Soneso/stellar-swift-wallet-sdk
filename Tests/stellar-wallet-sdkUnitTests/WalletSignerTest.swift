//
//  WalletSignerTest.swift
//
//
//  Offline unit tests covering the WalletSigner implementations of the wallet sdk:
//  DefaultSigner and DomainSigner.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

/// Test fixtures namespaced with the WalletSignerTest prefix to avoid collisions with other suites.
final class WalletSignerTestUtils {
    static let issuer = "GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"

    // Domain signer mock infrastructure.
    static let signerHost = "domain-signer.walletsigner.example"
    static let signerUrl = "https://\(signerHost)/sign"
    static let signedXdr = "AAAAAGSignedTransactionEnvelopeXdrPlaceholderForDomainSignerResponse"
}

/// Domain signer endpoint mock returning a JSON body with a "transaction" field.
class WalletSignerTestDomainSignerMock: ResponsesMock {
    let host: String
    var statusToReturn: Int = 200
    var includeTransactionField: Bool = true

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, _ in
            guard let self = self else { return "{}" }
            mock.statusCode = self.statusToReturn
            if self.statusToReturn == 200 && self.includeTransactionField {
                return """
                {"transaction": "\(WalletSignerTestUtils.signedXdr)"}
                """
            } else if self.statusToReturn == 200 {
                // 200 but no transaction field.
                return "{}"
            } else {
                return """
                {"error": "server error"}
                """
            }
        }
        return RequestMock(host: host,
                           path: "/sign",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
}

final class WalletSignerTest: XCTestCase {

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    func testDefaultSignerSignsTransaction() throws {
        // Build a simple, valid transaction and verify DefaultSigner adds a signature.
        let sourceKp = SigningKeyPair.random
        let account = Account(keyPair: sourceKp.keyPair, sequenceNumber: 10)
        let destination = try KeyPair(accountId: WalletSignerTestUtils.issuer)
        let op = try PaymentOperation(sourceAccountId: sourceKp.address,
                                      destinationAccountId: destination.accountId,
                                      asset: Asset(type: AssetType.ASSET_TYPE_NATIVE)!,
                                      amount: 10)
        let tx = try Transaction(sourceAccount: account, operations: [op], memo: Memo.none)
        XCTAssertEqual(0, tx.transactionXDR.signatures.count)

        let signer = DefaultSigner()
        signer.signWithClientAccount(tnx: tx, network: Network.testnet, accountKp: sourceKp)
        XCTAssertEqual(1, tx.transactionXDR.signatures.count)
    }

    func testDefaultSignerDomainSigningNotSupported() async {
        let signer = DefaultSigner()
        do {
            _ = try await signer.signWithDomainAccount(transactionXdr: "abc",
                                                       networkPassphrase: Network.testnet.passphrase)
            XCTFail("should have thrown")
        } catch ValidationError.invalidArgument {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDomainSignerInvalidUrlThrows() {
        // An empty string is not a valid URL.
        XCTAssertThrowsError(try DomainSigner(url: "")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testDomainSignerSetsContentTypeHeader() throws {
        let signer = try DomainSigner(url: WalletSignerTestUtils.signerUrl,
                                      requestHeaders: ["Authorization": "Bearer token"])
        XCTAssertEqual("application/json", signer.requestHeaders["Content-Type"])
        XCTAssertEqual("Bearer token", signer.requestHeaders["Authorization"])
        XCTAssertEqual(WalletSignerTestUtils.signerUrl, signer.endpoint.absoluteString)
    }

    func testDomainSignerSuccess() async throws {
        let mock = WalletSignerTestDomainSignerMock(host: WalletSignerTestUtils.signerHost)
        mock.statusToReturn = 200
        mock.includeTransactionField = true

        let signer = try DomainSigner(url: WalletSignerTestUtils.signerUrl)
        let result = try await signer.signWithDomainAccount(transactionXdr: "envelope",
                                                            networkPassphrase: Network.testnet.passphrase)
        XCTAssertEqual(WalletSignerTestUtils.signedXdr, result)
        withExtendedLifetime(mock) {}
    }

    func testDomainSigner200WithoutTransactionFieldThrows() async throws {
        let mock = WalletSignerTestDomainSignerMock(host: WalletSignerTestUtils.signerHost)
        mock.statusToReturn = 200
        mock.includeTransactionField = false

        let signer = try DomainSigner(url: WalletSignerTestUtils.signerUrl)
        do {
            _ = try await signer.signWithDomainAccount(transactionXdr: "envelope",
                                                       networkPassphrase: Network.testnet.passphrase)
            XCTFail("should have thrown")
        } catch DomainSignerError.requestError {
            // The implementation wraps the thrown unexpectedResponse in a requestError
            // because the throw happens inside the do block of the same try/catch.
        } catch DomainSignerError.unexpectedResponse {
            // Acceptable as well, depending on control flow.
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        withExtendedLifetime(mock) {}
    }

    func testDomainSignerErrorStatusThrows() async throws {
        let mock = WalletSignerTestDomainSignerMock(host: WalletSignerTestUtils.signerHost)
        mock.statusToReturn = 500

        let signer = try DomainSigner(url: WalletSignerTestUtils.signerUrl)
        do {
            _ = try await signer.signWithDomainAccount(transactionXdr: "envelope",
                                                       networkPassphrase: Network.testnet.passphrase)
            XCTFail("should have thrown")
        } catch DomainSignerError.requestError {
            // expected: error status path throws unexpectedResponse, wrapped as requestError.
        } catch DomainSignerError.unexpectedResponse {
            // acceptable as well
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        withExtendedLifetime(mock) {}
    }
}
