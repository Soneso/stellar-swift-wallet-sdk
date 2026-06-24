//
//  CoreCoverageTests.swift
//
//
//  Offline unit tests covering pure / model types of the wallet sdk:
//  AssetId, WalletSigner, Sep10 remaining branches, Watcher / WalletExceptionHandler /
//  StatusUpdateEvent, Wallet / StellarConfig / AppConfig / Config, MemoType,
//  TransactionStatus, TransactionKind and the small recovery model types.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

/// Test fixtures namespaced with the CoreCov prefix to avoid collisions with other suites.
final class CoreCovUtils {
    static let issuer = "GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
    static let otherIssuer = "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"

    // Domain signer mock infrastructure.
    static let signerHost = "domain-signer.corecov.example"
    static let signerUrl = "https://\(signerHost)/sign"
    static let signedXdr = "AAAAAGSignedTransactionEnvelopeXdrPlaceholderForDomainSignerResponse"

    static let serverKeypair = try! KeyPair(secretSeed: "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W")
    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"

    /// A real, structurally valid JWT (header.payload.signature) with iss/sub/iat/exp/client_domain.
    /// Header: {"alg":"HS256","typ":"JWT"}
    /// Payload: {"iss":"https://issuer.example","sub":"GABC...:1234","iat":1700000000,"exp":1700003600,"client_domain":"client.example"}
    static let jwtWithClaims = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlIiwic3ViIjoiR0FCQzpkZWY6MTIzNCIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAzNjAwLCJjbGllbnRfZG9tYWluIjoiY2xpZW50LmV4YW1wbGUifQ.c2lnbmF0dXJlc2VnbWVudA"

    /// The SEP-30 response model types in the underlying iOS SDK only expose a
    /// Decodable initializer, so these helpers build them by decoding JSON.
    static func decodeSep30Identity(json: String) throws -> SEP30ResponseIdentity {
        return try JSONDecoder().decode(SEP30ResponseIdentity.self, from: json.data(using: .utf8)!)
    }

    static func decodeSep30Signer(json: String) throws -> SEP30ResponseSigner {
        return try JSONDecoder().decode(SEP30ResponseSigner.self, from: json.data(using: .utf8)!)
    }

    static func decodeSep30Account(json: String) throws -> Sep30AccountResponse {
        return try JSONDecoder().decode(Sep30AccountResponse.self, from: json.data(using: .utf8)!)
    }
}

/// Mock that returns a SEP-10 toml WITHOUT a SIGNING_KEY, used to exercise the
/// clientDomainSigningKeyNotFound error path in Sep10.authenticate.
class CoreCovTomlNoSigningKeyMock: ResponsesMock {
    let host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] _, _ in
            return self?.tomlNoSigningKey
        }
        return RequestMock(host: host,
                           path: "/.well-known/stellar.toml",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    var tomlNoSigningKey: String {
        return """
            VERSION="2.0.0"
            NETWORK_PASSPHRASE="\(Network.testnet.passphrase)"
            """
    }
}

/// Mock that returns a SEP-10 toml with an INVALID SIGNING_KEY (not a valid account id),
/// used to exercise the invaildClientDomainSigningKey error path in Sep10.authenticate.
class CoreCovTomlInvalidSigningKeyMock: ResponsesMock {
    let host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] _, _ in
            return self?.tomlInvalidSigningKey
        }
        return RequestMock(host: host,
                           path: "/.well-known/stellar.toml",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    var tomlInvalidSigningKey: String {
        return """
            VERSION="2.0.0"
            NETWORK_PASSPHRASE="\(Network.testnet.passphrase)"
            SIGNING_KEY="NOT_A_VALID_STELLAR_ACCOUNT_ID"
            """
    }
}

/// Domain signer endpoint mock returning a JSON body with a "transaction" field.
class CoreCovDomainSignerMock: ResponsesMock {
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
                {"transaction": "\(CoreCovUtils.signedXdr)"}
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

final class CoreCoverageTests: XCTestCase {

    let wallet = Wallet.testNet

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - AssetId

    func testNativeAssetId() {
        let native = NativeAssetId()
        XCTAssertEqual("native", native.id)
        XCTAssertEqual("stellar", native.scheme)
        XCTAssertEqual("stellar:native", native.sep38)

        let asset = native.toAsset()
        XCTAssertEqual(AssetType.ASSET_TYPE_NATIVE, asset.type)
    }

    func testIssuedAssetIdValid() throws {
        let issued = try IssuedAssetId(code: "USDC", issuer: CoreCovUtils.issuer)
        XCTAssertEqual("USDC", issued.code)
        XCTAssertEqual(CoreCovUtils.issuer, issued.issuer)
        XCTAssertEqual("USDC:\(CoreCovUtils.issuer)", issued.id)
        XCTAssertEqual("stellar", issued.scheme)
        XCTAssertEqual("stellar:USDC:\(CoreCovUtils.issuer)", issued.sep38)

        // toAsset round trips into an ALPHANUM4 credit asset.
        let asset = issued.toAsset()
        XCTAssertEqual(AssetType.ASSET_TYPE_CREDIT_ALPHANUM4, asset.type)
        XCTAssertEqual("USDC", asset.code)
        XCTAssertEqual(CoreCovUtils.issuer, asset.issuer?.accountId)
    }

    func testIssuedAssetIdAlphanum12() throws {
        let issued = try IssuedAssetId(code: "LONGASSET12", issuer: CoreCovUtils.issuer)
        XCTAssertEqual("LONGASSET12", issued.code)
        let asset = issued.toAsset()
        XCTAssertEqual(AssetType.ASSET_TYPE_CREDIT_ALPHANUM12, asset.type)
        XCTAssertEqual("LONGASSET12", asset.code)
    }

    func testIssuedAssetIdTrimsCode() throws {
        let issued = try IssuedAssetId(code: "  USDC  ", issuer: CoreCovUtils.issuer)
        XCTAssertEqual("USDC", issued.code)
        XCTAssertEqual("USDC:\(CoreCovUtils.issuer)", issued.id)
    }

    func testIssuedAssetIdEmptyCodeThrows() {
        XCTAssertThrowsError(try IssuedAssetId(code: "   ", issuer: CoreCovUtils.issuer)) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testIssuedAssetIdTooLongCodeThrows() {
        XCTAssertThrowsError(try IssuedAssetId(code: "THIRTEENCHARS", issuer: CoreCovUtils.issuer)) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testIssuedAssetIdInvalidIssuerThrows() {
        XCTAssertThrowsError(try IssuedAssetId(code: "USDC", issuer: "NOT_AN_ACCOUNT_ID")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testFiatAssetId() {
        let fiat = FiatAssetId(id: "USD")
        XCTAssertEqual("USD", fiat.id)
        XCTAssertEqual("iso4217", fiat.scheme)
        XCTAssertEqual("iso4217:USD", fiat.sep38)
    }

    func testStellarAssetIdEqualityAndHash() throws {
        let a = try IssuedAssetId(code: "USDC", issuer: CoreCovUtils.issuer)
        let b = try IssuedAssetId(code: "USDC", issuer: CoreCovUtils.issuer)
        let c = try IssuedAssetId(code: "USDC", issuer: CoreCovUtils.otherIssuer)
        let native = NativeAssetId()

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a as StellarAssetId, native as StellarAssetId)

        var set = Set<StellarAssetId>()
        set.insert(a)
        set.insert(b)
        set.insert(c)
        // a and b are equal so the set holds only two distinct entries.
        XCTAssertEqual(2, set.count)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testFromAssetNative() throws {
        let nativeAsset = Asset(type: AssetType.ASSET_TYPE_NATIVE)!
        let result = try StellarAssetId.fromAsset(asset: nativeAsset)
        XCTAssertTrue(result is NativeAssetId)
        XCTAssertEqual("native", result.id)
    }

    func testFromAssetAlphanum4() throws {
        let issuerKp = try KeyPair(accountId: CoreCovUtils.issuer)
        let asset = Asset(type: AssetType.ASSET_TYPE_CREDIT_ALPHANUM4, code: "USDC", issuer: issuerKp)!
        let result = try StellarAssetId.fromAsset(asset: asset)
        XCTAssertTrue(result is IssuedAssetId)
        XCTAssertEqual("USDC:\(CoreCovUtils.issuer)", result.id)
    }

    func testFromAssetAlphanum12() throws {
        let issuerKp = try KeyPair(accountId: CoreCovUtils.issuer)
        let asset = Asset(type: AssetType.ASSET_TYPE_CREDIT_ALPHANUM12, code: "LONGASSET12", issuer: issuerKp)!
        let result = try StellarAssetId.fromAsset(asset: asset)
        XCTAssertTrue(result is IssuedAssetId)
        XCTAssertEqual("LONGASSET12:\(CoreCovUtils.issuer)", result.id)
    }

    func testFromAssetDataNative() throws {
        let result = try StellarAssetId.fromAssetData(type: "native")
        XCTAssertTrue(result is NativeAssetId)
        XCTAssertEqual("native", result.id)
    }

    func testFromAssetDataAlphanum4() throws {
        let result = try StellarAssetId.fromAssetData(type: "credit_alphanum4",
                                                      code: "USDC",
                                                      issuerAccountId: CoreCovUtils.issuer)
        XCTAssertTrue(result is IssuedAssetId)
        XCTAssertEqual("USDC:\(CoreCovUtils.issuer)", result.id)
    }

    func testFromAssetDataAlphanum12() throws {
        let result = try StellarAssetId.fromAssetData(type: "credit_alphanum12",
                                                      code: "LONGASSET12",
                                                      issuerAccountId: CoreCovUtils.issuer)
        XCTAssertTrue(result is IssuedAssetId)
        XCTAssertEqual("LONGASSET12:\(CoreCovUtils.issuer)", result.id)
    }

    func testFromAssetDataUnknownTypeThrows() {
        XCTAssertThrowsError(try StellarAssetId.fromAssetData(type: "bogus")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testFromAssetDataInvalidIssuerThrows() {
        XCTAssertThrowsError(try StellarAssetId.fromAssetData(type: "credit_alphanum4",
                                                              code: "USDC",
                                                              issuerAccountId: "NOPE")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    // MARK: - WalletSigner (DefaultSigner / DomainSigner)

    func testDefaultSignerSignsTransaction() throws {
        // Build a simple, valid transaction and verify DefaultSigner adds a signature.
        let sourceKp = SigningKeyPair.random
        let account = Account(keyPair: sourceKp.keyPair, sequenceNumber: 10)
        let destination = try KeyPair(accountId: CoreCovUtils.issuer)
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
        let signer = try DomainSigner(url: CoreCovUtils.signerUrl,
                                      requestHeaders: ["Authorization": "Bearer token"])
        XCTAssertEqual("application/json", signer.requestHeaders["Content-Type"])
        XCTAssertEqual("Bearer token", signer.requestHeaders["Authorization"])
        XCTAssertEqual(CoreCovUtils.signerUrl, signer.endpoint.absoluteString)
    }

    func testDomainSignerSuccess() async throws {
        let mock = CoreCovDomainSignerMock(host: CoreCovUtils.signerHost)
        mock.statusToReturn = 200
        mock.includeTransactionField = true

        let signer = try DomainSigner(url: CoreCovUtils.signerUrl)
        let result = try await signer.signWithDomainAccount(transactionXdr: "envelope",
                                                            networkPassphrase: Network.testnet.passphrase)
        XCTAssertEqual(CoreCovUtils.signedXdr, result)
        withExtendedLifetime(mock) {}
    }

    func testDomainSigner200WithoutTransactionFieldThrows() async throws {
        let mock = CoreCovDomainSignerMock(host: CoreCovUtils.signerHost)
        mock.statusToReturn = 200
        mock.includeTransactionField = false

        let signer = try DomainSigner(url: CoreCovUtils.signerUrl)
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
        let mock = CoreCovDomainSignerMock(host: CoreCovUtils.signerHost)
        mock.statusToReturn = 500

        let signer = try DomainSigner(url: CoreCovUtils.signerUrl)
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

    // MARK: - Sep10 remaining branches (AuthToken decode + client domain errors)

    func testAuthTokenDecodeClaims() throws {
        let token = try AuthToken(jwt: CoreCovUtils.jwtWithClaims)
        XCTAssertEqual(CoreCovUtils.jwtWithClaims, token.jwt)
        XCTAssertEqual("https://issuer.example", token.issuer)
        XCTAssertEqual("GABC:def:1234", token.principalAccount)
        // account strips everything after the first colon.
        XCTAssertEqual("GABC", token.account)
        XCTAssertEqual("client.example", token.clientDomain)
        XCTAssertEqual(Date(timeIntervalSince1970: 1700000000), token.issuedAt)
        XCTAssertEqual(Date(timeIntervalSince1970: 1700003600), token.expiresAt)
        XCTAssertEqual("c2lnbmF0dXJlc2VnbWVudA", token.signature)
    }

    func testAuthTokenInvalidSegmentCountThrows() {
        // Only two segments instead of three.
        XCTAssertThrowsError(try AuthToken(jwt: "header.payload")) { error in
            guard case AnchorAuthError.invalidJwtToken = error else {
                return XCTFail("expected invalidJwtToken, got \(error)")
            }
        }
    }

    func testAuthTokenMissingClaimsThrows() {
        // Valid base64 header + payload with no iss claim. payload = {"foo":"bar"}
        let payload = "eyJmb28iOiJiYXIifQ" // {"foo":"bar"}
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let jwt = "\(header).\(payload).sig"
        XCTAssertThrowsError(try AuthToken(jwt: jwt)) { error in
            guard case AnchorAuthError.invalidJwtToken = error else {
                return XCTFail("expected invalidJwtToken, got \(error)")
            }
        }
    }

    func testAuthTokenInvalidBase64Throws() {
        // Three segments but the payload is not valid base64 JSON.
        let jwt = "!!!.@@@.###"
        XCTAssertThrowsError(try AuthToken(jwt: jwt)) { error in
            guard let anchorErr = error as? AnchorAuthError else {
                return XCTFail("expected AnchorAuthError, got \(error)")
            }
            switch anchorErr {
            case .invalidJwtToken, .invalidJwtPayload:
                break
            default:
                XCTFail("unexpected AnchorAuthError: \(anchorErr)")
            }
        }
    }

    func testSep10ServerPropertiesExposed() async throws {
        // Anchor.sep10 reads the toml; verify Sep10 carries the configured server values.
        let tomlMock = TomlResponseMock(host: "sep10.corecov.example",
                                        serverSigningKey: CoreCovUtils.serverAccountId,
                                        authServer: "https://auth.sep10.corecov.example/auth")

        let anchor = wallet.anchor(homeDomain: "sep10.corecov.example")
        let sep10 = try await anchor.sep10
        XCTAssertEqual("sep10.corecov.example", sep10.serverHomeDomain)
        XCTAssertEqual("https://auth.sep10.corecov.example/auth", sep10.serverAuthEndpoint)
        XCTAssertEqual(CoreCovUtils.serverAccountId, sep10.serverSigningKey)
        // Keep the auto-registered toml mock alive until after the network fetch.
        withExtendedLifetime(tomlMock) {}
    }

    func testSep10NotSupportedWhenNoWebAuthEndpoint() async throws {
        // toml without WEB_AUTH_ENDPOINT -> Anchor.sep10 must throw notSupported.
        let tomlMock = TomlResponseMock(host: "nosep10.corecov.example",
                                        serverSigningKey: CoreCovUtils.serverAccountId)

        let anchor = wallet.anchor(homeDomain: "nosep10.corecov.example")
        do {
            _ = try await anchor.sep10
            XCTFail("should have thrown")
        } catch AnchorAuthError.notSupported {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        withExtendedLifetime(tomlMock) {}
    }

    func testSep10ClientDomainSigningKeyNotFound() async throws {
        // Anchor toml is fine for sep10. The client domain toml has NO signing key.
        let anchorHost = "anchor.cd1.corecov.example"
        let clientHost = "client.cd1.corecov.example"
        let anchorTomlMock = TomlResponseMock(host: anchorHost,
                                              serverSigningKey: CoreCovUtils.serverAccountId,
                                              authServer: "https://auth.\(anchorHost)/auth")
        let clientTomlMock = CoreCovTomlNoSigningKeyMock(host: clientHost)

        let anchor = wallet.anchor(homeDomain: anchorHost)
        let sep10 = try await anchor.sep10
        let userKp = SigningKeyPair.random
        let clientSigner = try DomainSigner(url: "https://\(clientHost)/sign")

        do {
            _ = try await sep10.authenticate(userKeyPair: userKp,
                                             clientDomain: clientHost,
                                             clientDomainSigner: clientSigner)
            XCTFail("should have thrown")
        } catch AnchorAuthError.clientDomainSigningKeyNotFound(let clientDomain) {
            XCTAssertEqual(clientHost, clientDomain)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        withExtendedLifetime(anchorTomlMock) {}
        withExtendedLifetime(clientTomlMock) {}
    }

    func testSep10InvalidClientDomainSigningKey() async throws {
        let anchorHost = "anchor.cd2.corecov.example"
        let clientHost = "client.cd2.corecov.example"
        let anchorTomlMock = TomlResponseMock(host: anchorHost,
                                              serverSigningKey: CoreCovUtils.serverAccountId,
                                              authServer: "https://auth.\(anchorHost)/auth")
        let clientTomlMock = CoreCovTomlInvalidSigningKeyMock(host: clientHost)

        let anchor = wallet.anchor(homeDomain: anchorHost)
        let sep10 = try await anchor.sep10
        let userKp = SigningKeyPair.random
        let clientSigner = try DomainSigner(url: "https://\(clientHost)/sign")

        do {
            _ = try await sep10.authenticate(userKeyPair: userKp,
                                             clientDomain: clientHost,
                                             clientDomainSigner: clientSigner)
            XCTFail("should have thrown")
        } catch AnchorAuthError.invaildClientDomainSigningKey(let clientDomain, let key) {
            XCTAssertEqual(clientHost, clientDomain)
            XCTAssertEqual("NOT_A_VALID_STELLAR_ACCOUNT_ID", key)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        withExtendedLifetime(anchorTomlMock) {}
        withExtendedLifetime(clientTomlMock) {}
    }

    // MARK: - WalletExceptionHandler / RetryContext

    func testRetryContextOnErrorAndRefresh() {
        let ctx = RetryContext()
        XCTAssertEqual(0, ctx.retries)
        XCTAssertNil(ctx.error)

        struct CoreCovDummyError: Error {}
        ctx.onError(e: CoreCovDummyError())
        XCTAssertEqual(1, ctx.retries)
        XCTAssertNotNil(ctx.error)

        ctx.onError(e: CoreCovDummyError())
        XCTAssertEqual(2, ctx.retries)

        ctx.refresh()
        XCTAssertEqual(0, ctx.retries)
        XCTAssertNil(ctx.error)
    }

    func testRetryExceptionHandlerRetriesThenGivesUp() async {
        // backoffPeriod is intentionally tiny to keep this offline test fast.
        let handler = RetryExceptionHandler(maxRetryCount: 2, backoffPeriod: 0.001)
        let ctx = RetryContext()

        struct CoreCovDummyError: Error {}

        // retries < maxRetryCount -> false (keep retrying)
        ctx.onError(e: CoreCovDummyError()) // retries == 1
        let shouldExit1 = await handler.invoke(ctx: ctx)
        XCTAssertFalse(shouldExit1)

        ctx.onError(e: CoreCovDummyError()) // retries == 2 == maxRetryCount
        let shouldExit2 = await handler.invoke(ctx: ctx)
        XCTAssertTrue(shouldExit2, "once retries reaches maxRetryCount the handler gives up")
    }

    func testRetryExceptionHandlerDefaults() {
        let handler = RetryExceptionHandler()
        XCTAssertEqual(3, handler.maxRetryCount)
        XCTAssertEqual(5.0, handler.backoffPeriod)
    }

    // MARK: - StatusUpdateEvent

    func testStatusChangeTerminalAndError() {
        let completedTx = AnchorTransaction(id: "tx1", transactionStatus: .completed)
        let change = StatusChange(transaction: completedTx,
                                  status: .completed,
                                  oldStatus: .pendingAnchor)
        XCTAssertTrue(change.isTerminal())
        XCTAssertFalse(change.isError())
        XCTAssertEqual(.completed, change.status)
        XCTAssertEqual(.pendingAnchor, change.oldStatus)
        XCTAssertTrue(change.transaction === completedTx)
    }

    func testStatusChangeErrorStatus() {
        let errorTx = AnchorTransaction(id: "tx2", transactionStatus: .error, message: "boom")
        let change = StatusChange(transaction: errorTx, status: .error)
        XCTAssertTrue(change.isError())
        XCTAssertTrue(change.isTerminal())
        XCTAssertNil(change.oldStatus)
        XCTAssertEqual("boom", change.transaction.message)
    }

    func testStatusChangeNonTerminal() {
        let pendingTx = AnchorTransaction(id: "tx3", transactionStatus: .pendingUser)
        let change = StatusChange(transaction: pendingTx, status: .pendingUser)
        XCTAssertFalse(change.isTerminal())
        XCTAssertFalse(change.isError())
    }

    func testExceptionHandlerExitAndNotificationsClosedAreEvents() {
        let exit: StatusUpdateEvent = ExceptionHandlerExit()
        let closed: StatusUpdateEvent = NotificationsClosed()
        XCTAssertTrue(exit is ExceptionHandlerExit)
        XCTAssertTrue(closed is NotificationsClosed)
    }

    // MARK: - Watcher (construction + result lifecycle, no network polling)

    func testWatcherConstructionViaSep24() {
        let anchor = wallet.anchor(homeDomain: "watcher.corecov.example")
        let handler = RetryExceptionHandler(maxRetryCount: 1, backoffPeriod: 0.001)
        let watcher = anchor.sep24.watcher(pollDelay: 1.0, exceptionHandler: handler)
        XCTAssertEqual(1.0, watcher.pollDelay)
        XCTAssertTrue(watcher.exceptionHandler is RetryExceptionHandler)
        XCTAssertTrue(watcher.anchor === anchor)
    }

    func testWatcherConstructionViaSep6() {
        let anchor = wallet.anchor(homeDomain: "watcher6.corecov.example")
        let watcher = anchor.sep6.watcher(pollDelay: 2.0)
        XCTAssertEqual(2.0, watcher.pollDelay)
        XCTAssertTrue(watcher.anchor === anchor)
    }

    func testWatcherResultStopInvalidatesTimer() {
        // Build a timer that won't fire (huge interval) and wrap it in a WatcherResult.
        let timer = Timer(timeInterval: 10000, repeats: true) { _ in }
        let result = WatcherResult(notificationName: Notification.Name("corecov_test"), timer: timer)
        XCTAssertTrue(result.timer.isValid)
        result.stop()
        XCTAssertFalse(result.timer.isValid)
        // Calling stop again on an invalid timer must be a no-op.
        result.stop()
        XCTAssertFalse(result.timer.isValid)
    }

    // MARK: - Wallet / StellarConfig / AppConfig / Config

    func testStellarConfigTestNet() {
        let cfg = StellarConfig.testNet
        XCTAssertEqual(Network.testnet.passphrase, cfg.network.passphrase)
        XCTAssertEqual(StellarSDK.testNetUrl, cfg.horizonUrl)
        XCTAssertEqual(100, cfg.baseFee)
        XCTAssertEqual(300, cfg.txTimeout)
    }

    func testStellarConfigPublicNet() {
        let cfg = StellarConfig.publicNet
        XCTAssertEqual(Network.public.passphrase, cfg.network.passphrase)
        XCTAssertEqual(StellarSDK.publicNetUrl, cfg.horizonUrl)
    }

    func testStellarConfigFutureNet() {
        let cfg = StellarConfig.futureNet
        XCTAssertEqual(Network.futurenet.passphrase, cfg.network.passphrase)
        XCTAssertEqual(StellarSDK.futureNetUrl, cfg.horizonUrl)
    }

    func testStellarConfigCustomValues() {
        let cfg = StellarConfig(network: Network.testnet,
                                horizonUrl: "https://custom.horizon.example",
                                baseFee: 250,
                                txTimeout: 120)
        XCTAssertEqual("https://custom.horizon.example", cfg.horizonUrl)
        XCTAssertEqual(250, cfg.baseFee)
        XCTAssertEqual(120, cfg.txTimeout)
    }

    func testAppConfigDefaults() {
        let cfg = AppConfig()
        XCTAssertTrue(cfg.defaultSigner is DefaultSigner)
        XCTAssertNil(cfg.defaultClientDomain)
    }

    func testAppConfigCustomSignerAndDomain() throws {
        let domainSigner = try DomainSigner(url: CoreCovUtils.signerUrl)
        let cfg = AppConfig(defaultSigner: domainSigner, defaultClientDomain: "client.example")
        XCTAssertTrue(cfg.defaultSigner is DomainSigner)
        XCTAssertEqual("client.example", cfg.defaultClientDomain)
    }

    func testConfigHoldsStellarAndApp() {
        let stellarCfg = StellarConfig.testNet
        let appCfg = AppConfig()
        let config = Config(stellar: stellarCfg, app: appCfg)
        XCTAssertTrue(config.stellar === stellarCfg)
        XCTAssertTrue(config.app === appCfg)
    }

    func testWalletTestNet() {
        let w = Wallet.testNet
        XCTAssertEqual(Network.testnet.passphrase, w.stellarConfig.network.passphrase)
        XCTAssertEqual(StellarSDK.testNetUrl, w.stellarConfig.horizonUrl)
        XCTAssertTrue(w.appConfig.defaultSigner is DefaultSigner)
    }

    func testWalletPublicNet() {
        let w = Wallet.publicNet
        XCTAssertEqual(Network.public.passphrase, w.stellarConfig.network.passphrase)
    }

    func testWalletFutureNet() {
        let w = Wallet.futureNet
        XCTAssertEqual(Network.futurenet.passphrase, w.stellarConfig.network.passphrase)
    }

    func testWalletConvenienceInitUsesDefaultAppConfig() {
        let w = Wallet(stellarConfig: StellarConfig.testNet)
        XCTAssertTrue(w.appConfig.defaultSigner is DefaultSigner)
        XCTAssertNil(w.appConfig.defaultClientDomain)
    }

    func testWalletAnchorReturnsConfiguredHomeDomain() {
        let anchor = wallet.anchor(homeDomain: "my.anchor.example")
        XCTAssertEqual("my.anchor.example", anchor.homeDomain)
    }

    func testWalletVersionNumberIsSet() {
        XCTAssertFalse(Wallet.versionNumber.isEmpty)
    }

    // MARK: - MemoType

    func testMemoTypeRawValues() {
        XCTAssertEqual("text", MemoType.text.rawValue)
        XCTAssertEqual("hash", MemoType.hash.rawValue)
        XCTAssertEqual("id", MemoType.id.rawValue)
        XCTAssertEqual(.text, MemoType(rawValue: "text"))
        XCTAssertEqual(.hash, MemoType(rawValue: "hash"))
        XCTAssertEqual(.id, MemoType(rawValue: "id"))
        XCTAssertNil(MemoType(rawValue: "unknown"))
    }

    // MARK: - TransactionStatus

    func testTransactionStatusRawValues() {
        XCTAssertEqual(.incomplete, TransactionStatus(rawValue: "incomplete"))
        XCTAssertEqual(.pendingUserTransferStart, TransactionStatus(rawValue: "pending_user_transfer_start"))
        XCTAssertEqual(.completed, TransactionStatus(rawValue: "completed"))
        XCTAssertEqual(.pendingCustomerInfoUpdate, TransactionStatus(rawValue: "pending_customer_info_update"))
        XCTAssertNil(TransactionStatus(rawValue: "does_not_exist"))
    }

    func testTransactionStatusIsError() {
        XCTAssertTrue(TransactionStatus.error.isError())
        XCTAssertTrue(TransactionStatus.noMarket.isError())
        XCTAssertTrue(TransactionStatus.tooLarge.isError())
        XCTAssertTrue(TransactionStatus.tooSmall.isError())

        XCTAssertFalse(TransactionStatus.completed.isError())
        XCTAssertFalse(TransactionStatus.refunded.isError())
        XCTAssertFalse(TransactionStatus.pendingAnchor.isError())
        XCTAssertFalse(TransactionStatus.incomplete.isError())
    }

    func testTransactionStatusIsTerminal() {
        XCTAssertTrue(TransactionStatus.completed.isTerminal())
        XCTAssertTrue(TransactionStatus.refunded.isTerminal())
        XCTAssertTrue(TransactionStatus.expired.isTerminal())
        XCTAssertTrue(TransactionStatus.error.isTerminal())
        XCTAssertTrue(TransactionStatus.noMarket.isTerminal())
        XCTAssertTrue(TransactionStatus.tooLarge.isTerminal())
        XCTAssertTrue(TransactionStatus.tooSmall.isTerminal())

        XCTAssertFalse(TransactionStatus.incomplete.isTerminal())
        XCTAssertFalse(TransactionStatus.pendingAnchor.isTerminal())
        XCTAssertFalse(TransactionStatus.pendingUser.isTerminal())
        XCTAssertFalse(TransactionStatus.pendingStellar.isTerminal())
    }

    // MARK: - TransactionKind

    func testTransactionKindRawValues() {
        XCTAssertEqual("deposit", TransactionKind.deposit.rawValue)
        XCTAssertEqual("withdrawal", TransactionKind.withdrawal.rawValue)
        XCTAssertEqual("deposit-exchange", TransactionKind.depositExchange.rawValue)
        XCTAssertEqual("withdrawal-exchange", TransactionKind.withdrawalExchange.rawValue)
        XCTAssertEqual(.deposit, TransactionKind(rawValue: "deposit"))
        XCTAssertEqual(.withdrawalExchange, TransactionKind(rawValue: "withdrawal-exchange"))
        XCTAssertNil(TransactionKind(rawValue: "swap"))
    }

    // MARK: - Recovery model types

    func testRecoveryServerKeyEqualityAndHash() {
        let a = RecoveryServerKey(name: "server1")
        let b = RecoveryServerKey(name: "server1")
        let c = RecoveryServerKey(name: "server2")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(a.hashValue, b.hashValue)

        var dict: [RecoveryServerKey: Int] = [:]
        dict[a] = 1
        dict[b] = 2 // overwrites because a == b
        dict[c] = 3
        XCTAssertEqual(2, dict.count)
        XCTAssertEqual(2, dict[a])
    }

    func testRecoveryServerProperties() throws {
        let signer = try DomainSigner(url: CoreCovUtils.signerUrl)
        let server = RecoveryServer(endpoint: "https://recovery.example.com",
                                    authEndpoint: "https://auth.example.com",
                                    homeDomain: "recovery.example.com",
                                    walletSigner: signer,
                                    clientDomain: "client.example.com")
        XCTAssertEqual("https://recovery.example.com", server.endpoint)
        XCTAssertEqual("https://auth.example.com", server.authEndpoint)
        XCTAssertEqual("recovery.example.com", server.homeDomain)
        XCTAssertTrue(server.walletSigner is DomainSigner)
        XCTAssertEqual("client.example.com", server.clientDomain)
    }

    func testRecoveryServerOptionalDefaults() {
        let server = RecoveryServer(endpoint: "https://recovery.example.com",
                                    authEndpoint: "https://auth.example.com",
                                    homeDomain: "recovery.example.com")
        XCTAssertNil(server.walletSigner)
        XCTAssertNil(server.clientDomain)
    }

    func testRecoveryServerSigning() {
        let signing = RecoveryServerSigning(signerAddress: CoreCovUtils.serverAccountId,
                                            authToken: "jwt-token")
        XCTAssertEqual(CoreCovUtils.serverAccountId, signing.signerAddress)
        XCTAssertEqual("jwt-token", signing.authToken)
    }

    func testSignerWeight() {
        let w = SignerWeight(device: 10, recoveryServer: 5)
        XCTAssertEqual(10, w.device)
        XCTAssertEqual(5, w.recoveryServer)
    }

    func testAccountThreshold() {
        let t = AccountThreshold(low: 1, medium: 2, high: 3)
        XCTAssertEqual(1, t.low)
        XCTAssertEqual(2, t.medium)
        XCTAssertEqual(3, t.high)
    }

    func testRecoveryRoleRawValues() {
        XCTAssertEqual("owner", RecoveryRole.owner.rawValue)
        XCTAssertEqual("sender", RecoveryRole.sender.rawValue)
        XCTAssertEqual("receiver", RecoveryRole.receiver.rawValue)
        XCTAssertEqual(.owner, RecoveryRole(rawValue: "owner"))
        XCTAssertNil(RecoveryRole(rawValue: "admin"))
    }

    func testRecoveryTypeRawValues() {
        XCTAssertEqual("stellar_address", RecoveryType.stellarAddress.rawValue)
        XCTAssertEqual("phone_number", RecoveryType.phoneNumber.rawValue)
        XCTAssertEqual("email", RecoveryType.email.rawValue)
        XCTAssertEqual(.email, RecoveryType(rawValue: "email"))
        XCTAssertNil(RecoveryType(rawValue: "carrier_pigeon"))
    }

    func testRecoveryAccountAuthMethodToSep30() {
        let method = RecoveryAccountAuthMethod(type: .email, value: "user@example.com")
        XCTAssertEqual(.email, method.type)
        XCTAssertEqual("user@example.com", method.value)

        let sep30 = method.toSEP30AuthMethod()
        XCTAssertEqual("email", sep30.type)
        XCTAssertEqual("user@example.com", sep30.value)
    }

    func testRecoveryAccountIdentityToSep30() {
        let m1 = RecoveryAccountAuthMethod(type: .email, value: "user@example.com")
        let m2 = RecoveryAccountAuthMethod(type: .phoneNumber, value: "+1555")
        let identity = RecoveryAccountIdentity(role: .owner, authMethods: [m1, m2])
        XCTAssertEqual(.owner, identity.role)
        XCTAssertEqual(2, identity.authMethods.count)

        let sep30 = identity.toSEP30RequestIdentity()
        XCTAssertEqual("owner", sep30.role)
        XCTAssertEqual(2, sep30.authMethods.count)
        XCTAssertEqual("email", sep30.authMethods[0].type)
        XCTAssertEqual("phone_number", sep30.authMethods[1].type)
    }

    func testAccountSigner() {
        let kp = SigningKeyPair.random
        let signer = AccountSigner(address: kp, weight: 7)
        XCTAssertEqual(kp.address, signer.address.address)
        XCTAssertEqual(7, signer.weight)
    }

    func testRecoverableWalletConfig() throws {
        let accountKp = SigningKeyPair.random
        let deviceKp = SigningKeyPair.random
        let threshold = AccountThreshold(low: 10, medium: 10, high: 10)
        let serverKey = RecoveryServerKey(name: "server1")
        let identity = RecoveryAccountIdentity(role: .owner,
                                               authMethods: [RecoveryAccountAuthMethod(type: .email, value: "a@b.c")])
        let weight = SignerWeight(device: 10, recoveryServer: 5)

        let config = RecoverableWalletConfig(accountAddress: accountKp,
                                             deviceAddress: deviceKp,
                                             accountThreshold: threshold,
                                             accountIdentity: [serverKey: [identity]],
                                             signerWeight: weight)
        XCTAssertEqual(accountKp.address, config.accountAddress.address)
        XCTAssertEqual(deviceKp.address, config.deviceAddress.address)
        XCTAssertEqual(10, config.accountThreshold.high)
        XCTAssertEqual(1, config.accountIdentity.count)
        XCTAssertEqual(10, config.signerWeight.device)
        XCTAssertNil(config.sponsorAddress)

        let sponsorKp = SigningKeyPair.random
        let sponsored = RecoverableWalletConfig(accountAddress: accountKp,
                                                deviceAddress: deviceKp,
                                                accountThreshold: threshold,
                                                accountIdentity: [serverKey: [identity]],
                                                signerWeight: weight,
                                                sponsorAddress: sponsorKp)
        XCTAssertNotNil(sponsored.sponsorAddress)
        XCTAssertEqual(sponsorKp.address, sponsored.sponsorAddress?.address)
    }

    func testRecoverableWalletHoldsTransactionAndSigners() throws {
        let sourceKp = SigningKeyPair.random
        let account = Account(keyPair: sourceKp.keyPair, sequenceNumber: 1)
        let op = try PaymentOperation(sourceAccountId: sourceKp.address,
                                      destinationAccountId: CoreCovUtils.issuer,
                                      asset: Asset(type: AssetType.ASSET_TYPE_NATIVE)!,
                                      amount: 1)
        let tx = try Transaction(sourceAccount: account, operations: [op], memo: Memo.none)
        let recoverable = RecoverableWallet(transaction: tx, signers: ["signer1", "signer2"])
        XCTAssertTrue(recoverable.transaction === tx)
        XCTAssertEqual(["signer1", "signer2"], recoverable.signers)
    }

    func testRecoverableIdentityFromResponseValid() throws {
        let response = try CoreCovUtils.decodeSep30Identity(json: """
            {"role": "owner", "authenticated": true}
            """)
        let identity = try RecoverableIdentity(response: response)
        XCTAssertEqual(.owner, identity.role)
        XCTAssertEqual(true, identity.authenticated)
    }

    func testRecoverableIdentityFromResponseMissingRoleThrows() throws {
        let response = try CoreCovUtils.decodeSep30Identity(json: "{}")
        XCTAssertThrowsError(try RecoverableIdentity(response: response)) { error in
            guard case RecoveryServiceError.parsingResponseFailed = error else {
                return XCTFail("expected parsingResponseFailed, got \(error)")
            }
        }
    }

    func testRecoverableIdentityFromResponseUnknownRoleThrows() throws {
        let response = try CoreCovUtils.decodeSep30Identity(json: """
            {"role": "wizard"}
            """)
        XCTAssertThrowsError(try RecoverableIdentity(response: response)) { error in
            guard case RecoveryServiceError.parsingResponseFailed = error else {
                return XCTFail("expected parsingResponseFailed, got \(error)")
            }
        }
    }

    func testRecoverableSignerFromResponseValid() throws {
        let response = try CoreCovUtils.decodeSep30Signer(json: """
            {"key": "\(CoreCovUtils.issuer)"}
            """)
        let signer = try RecoverableSigner(response: response)
        XCTAssertEqual(CoreCovUtils.issuer, signer.key.address)
        XCTAssertNil(signer.added)
    }

    func testRecoverableSignerFromResponseInvalidKeyThrows() throws {
        let response = try CoreCovUtils.decodeSep30Signer(json: """
            {"key": "NOT_A_KEY"}
            """)
        XCTAssertThrowsError(try RecoverableSigner(response: response)) { error in
            guard case RecoveryServiceError.parsingResponseFailed = error else {
                return XCTFail("expected parsingResponseFailed, got \(error)")
            }
        }
    }

    func testRecoverableAccountInfoFromResponse() throws {
        let response = try CoreCovUtils.decodeSep30Account(json: """
            {
              "address": "\(CoreCovUtils.otherIssuer)",
              "identities": [{"role": "owner", "authenticated": true}],
              "signers": [{"key": "\(CoreCovUtils.issuer)"}]
            }
            """)
        let info = try RecoverableAccountInfo(response: response)
        XCTAssertEqual(CoreCovUtils.otherIssuer, info.address.address)
        XCTAssertEqual(1, info.identities.count)
        XCTAssertEqual(.owner, info.identities[0].role)
        XCTAssertEqual(1, info.signers.count)
        XCTAssertEqual(CoreCovUtils.issuer, info.signers[0].key.address)
    }
}
