//
//  AuthTest.swift
//  
//
//  Created by Christian Rogobete on 02.12.24.
//

import XCTest
import stellarsdk
import Foundation
@testable import stellar_wallet_sdk

final class AuthTestUtils {

    static let anchorDomain = "place.anchor.com"
    static let anchorWebAuthDomain = "api.anchor.org"
    static let webAuthEndpoint = "https://\(anchorWebAuthDomain)/auth"
    static let clientDomain = "api.client.org"
    static let clientSignerUrl = "https://\(clientDomain)/auth"
    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userAccountId = "GB4L7JUU5DENUXYH3ANTLVYQL66KQLDDJTN5SF7MWEDGWSGUA375V44V"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"
    static let clientAccountId = "GBMR7A2B6O73HNRMH2LA5VZPVXIGGKFDZDXJXJXWUF5NX2RY73N4IFOA"
    static let clientSecretSeed = "SAWJ3S2JBMPI2F2K6DFAUPCROT3RA46XZXAC5EIJAD7K5C7FCUWEKVSB"
    static let wrongSecretSeed = "SAT4GUGO2N7RVVVD2TSL7TZ6T5A6PM7PJD5NUGQI5DDH67XO4KNO2QOW"
    static let jwtSuccess = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0"
    
    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)
    static let clientKeypair = try! KeyPair(secretSeed: clientSecretSeed)
    static let userKeypair = try! KeyPair(secretSeed: userSecretSeed)
    
    static let testMemoValid:UInt64 = 19989123;
    // this are used to generate errors in the mocks, that have to be handled by the sep-10 client validation
    static let testMemoInvalidSeqNr:UInt64 = 100;
    static let testMemoInvalidFirstOpSrcAcc:UInt64 = 101;
    static let testMemoInvalidSecondOpSrcAcc:UInt64 = 102;
    static let testMemoInvalidHomeDomain:UInt64 = 103;
    static let testMemoInvalidWebAuthDomain:UInt64 = 104;
    static let testMemoInvalidTimebounds:UInt64 = 105;
    static let testMemoInvalidOperationType:UInt64 = 106;
    static let testMemoInvalidSignature:UInt64 = 107;
    static let testMemoMultipleSignature:UInt64 = 108;
    
}

final class AuthTest: XCTestCase {
    let wallet = Wallet.testNet
    var anchorTomlServerMock: WebAuthTomlResponseMock!
    var clientTomlServerMock: WebAuthTomlResponseMock!
    var challengeServerMock: AuthTestWebAuthChallengeResponseMock!
    var sendChallengeServerMock: AuthTestWebAuthSendChallengeResponseMock!
    var clientSignerServerMock: ClientSignerResponseMock!
    
    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        anchorTomlServerMock = WebAuthTomlResponseMock(address: AuthTestUtils.anchorDomain,
                                                       serverSigningKey: AuthTestUtils.serverAccountId,
                                                       authServer: AuthTestUtils.webAuthEndpoint)
        
        clientTomlServerMock = WebAuthTomlResponseMock(address: AuthTestUtils.clientDomain,
                                                       serverSigningKey: AuthTestUtils.clientAccountId)
        
        challengeServerMock = AuthTestWebAuthChallengeResponseMock(address: AuthTestUtils.anchorWebAuthDomain,
                                                           serverKeyPair: AuthTestUtils.serverKeypair)
        
        sendChallengeServerMock = AuthTestWebAuthSendChallengeResponseMock(address: AuthTestUtils.anchorWebAuthDomain)
        
        clientSignerServerMock = ClientSignerResponseMock(address: AuthTestUtils.clientDomain)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    func testAll() async throws {
        try await basicSuccessTest()
        try await clientDomainSuccessTest()
        try await basicMemoSuccessTest()
        try await getChallengeInvalidSeqNrTest()
        try await getChallengeInvalidSecondOpSrcAccTest()
        try await getChallengeInvalidHomeDomainTest()
        try await getChallengeInvalidWebAuthDomainTest()
        try await getChallengeInvalidTimeboundsTest()
        try await getChallengeInvalidOperationTypeTest()
        try await getChallengeInvalidSignatureTest()
        try await getChallengeMultipleSignaturesTest()
    }
    
    func basicSuccessTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func clientDomainSuccessTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        let clientDomainSigner = try DomainSigner(url: AuthTestUtils.clientSignerUrl)
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey,
                                                         clientDomain: AuthTestUtils.clientDomain,
                                                         clientDomainSigner: clientDomainSigner)
            
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func basicMemoSuccessTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoValid)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func getChallengeInvalidSeqNrTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidSeqNr)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .sequenceNumberNot0:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testGetChallengeInvalidFirstOpSrcAcc() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidFirstOpSrcAcc)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidSourceAccount:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidSecondOpSrcAccTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidSecondOpSrcAcc)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidSourceAccount:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidHomeDomainTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidHomeDomain)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidHomeDomain:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidWebAuthDomainTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidWebAuthDomain)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidWebAuthDomain:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidTimeboundsTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidTimebounds)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidTimeBounds:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidOperationTypeTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidOperationType)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidOperationType:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeInvalidSignatureTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoInvalidSignature)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .invalidSignature:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func getChallengeMultipleSignaturesTest() async throws {
        let anchor = wallet.anchor(homeDomain: AuthTestUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        
        do {
            let sep10 = try await anchor.sep10
            XCTAssertEqual(AuthTestUtils.webAuthEndpoint, sep10.serverAuthEndpoint)
            let authToken = try await sep10.authenticate(userKeyPair: authKey, memoId: AuthTestUtils.testMemoMultipleSignature)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            XCTFail("should not reach")
        } catch GetJWTTokenError.validationErrorError(let validationError){
            switch validationError {
            case .signatureNotFound:
                return
            default:
                XCTFail(validationError.localizedDescription)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Sep10 remaining branches (AuthToken decode + client domain errors)

    func testAuthTokenDecodeClaims() throws {
        let token = try AuthToken(jwt: AuthTestSep10Fixtures.jwtWithClaims)
        XCTAssertEqual(AuthTestSep10Fixtures.jwtWithClaims, token.jwt)
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
                                        serverSigningKey: AuthTestSep10Fixtures.serverAccountId,
                                        authServer: "https://auth.sep10.corecov.example/auth")

        let anchor = wallet.anchor(homeDomain: "sep10.corecov.example")
        let sep10 = try await anchor.sep10
        XCTAssertEqual("sep10.corecov.example", sep10.serverHomeDomain)
        XCTAssertEqual("https://auth.sep10.corecov.example/auth", sep10.serverAuthEndpoint)
        XCTAssertEqual(AuthTestSep10Fixtures.serverAccountId, sep10.serverSigningKey)
        // Keep the auto-registered toml mock alive until after the network fetch.
        withExtendedLifetime(tomlMock) {}
    }

    func testSep10NotSupportedWhenNoWebAuthEndpoint() async throws {
        // toml without WEB_AUTH_ENDPOINT -> Anchor.sep10 must throw notSupported.
        let tomlMock = TomlResponseMock(host: "nosep10.corecov.example",
                                        serverSigningKey: AuthTestSep10Fixtures.serverAccountId)

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
                                              serverSigningKey: AuthTestSep10Fixtures.serverAccountId,
                                              authServer: "https://auth.\(anchorHost)/auth")
        let clientTomlMock = AuthTestTomlNoSigningKeyMock(host: clientHost)

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
                                              serverSigningKey: AuthTestSep10Fixtures.serverAccountId,
                                              authServer: "https://auth.\(anchorHost)/auth")
        let clientTomlMock = AuthTestTomlInvalidSigningKeyMock(host: clientHost)

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
}

/// Fixtures for the folded Sep10 remaining-branch tests, prefixed to avoid
/// collisions with the names already used in this suite.
final class AuthTestSep10Fixtures {
    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"

    /// A real, structurally valid JWT (header.payload.signature) with iss/sub/iat/exp/client_domain.
    /// Header: {"alg":"HS256","typ":"JWT"}
    /// Payload: {"iss":"https://issuer.example","sub":"GABC...:1234","iat":1700000000,"exp":1700003600,"client_domain":"client.example"}
    static let jwtWithClaims = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlIiwic3ViIjoiR0FCQzpkZWY6MTIzNCIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAzNjAwLCJjbGllbnRfZG9tYWluIjoiY2xpZW50LmV4YW1wbGUifQ.c2lnbmF0dXJlc2VnbWVudA"
}

/// Mock that returns a SEP-10 toml WITHOUT a SIGNING_KEY, used to exercise the
/// clientDomainSigningKeyNotFound error path in Sep10.authenticate.
class AuthTestTomlNoSigningKeyMock: ResponsesMock {
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
class AuthTestTomlInvalidSigningKeyMock: ResponsesMock {
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

class WebAuthTomlResponseMock: ResponsesMock {
    var address: String
    var serverSigningKey: String
    var authServer: String?
    
    init(address:String, serverSigningKey: String, authServer: String? = nil) {
        self.address = address
        self.serverSigningKey = serverSigningKey
        self.authServer = authServer
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        
        let handler: MockHandler = { [weak self] mock, request in
            return self?.stellarToml
        }
        
        return RequestMock(host: address,
                           path: "/.well-known/stellar.toml",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    var stellarToml:String {
        get {
            return """
                # Sample stellar.toml
                VERSION="2.0.0"
                NETWORK_PASSPHRASE="\(Network.testnet.passphrase)"
                SIGNING_KEY="\(serverSigningKey)"
            """ + (authServer == nil ? "" : """
                WEB_AUTH_ENDPOINT="\(authServer!)"
            """)
        }
    }
}

class AuthTestWebAuthChallengeResponseMock: ResponsesMock {
    var address: String
    var serverKeyPair: KeyPair
    
    init(address:String, serverKeyPair:KeyPair) {
        self.address = address
        self.serverKeyPair = serverKeyPair
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let account = mock.variables["account"] {
                mock.statusCode = 200
                
                let memo:UInt64? = mock.variables["memo"] == nil ? nil : UInt64(mock.variables["memo"]!)
                if(memo == nil || memo == AuthTestUtils.testMemoValid) {
                    return self?.requestSuccess(account: account, memo:memo)
                } else if let memo = memo {
                    if (memo == AuthTestUtils.testMemoInvalidSeqNr) {
                        return self?.requestChallengeInvalidSequenceNumber(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidFirstOpSrcAcc) {
                        return self?.requestChallengeInvalidFirstOpSrcAcc(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidSecondOpSrcAcc) {
                        return self?.requestChallengeInvalidSecondOpSrcAcc(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidHomeDomain) {
                        return self?.requestChallengeInvalidHomeDomain(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidWebAuthDomain) {
                        return self?.requestChallengeInvalidWebAuthDomain(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidTimebounds) {
                        return self?.requestChallengeInvalidTimebounds(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidOperationType) {
                        return self?.requestChallengeInvalidOperationType(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoInvalidSignature) {
                        return self?.requestChallengeInvalidSignature(account: account, memo:memo)
                    } else if (memo == AuthTestUtils.testMemoMultipleSignature) {
                        return self?.requestChallengeMultipleSignature(account: account, memo:memo)
                    }
                }
            }
            mock.statusCode = 400
            return """
                {"error": "Bad request"}
            """
        }
        
        return RequestMock(host: address,
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
    
    func getInvalidTimeBounds() -> TransactionPreconditions {
        return TransactionPreconditions(timeBounds: TimeBounds(minTime: UInt64(Date().timeIntervalSince1970) - 700,
                                                               maxTime: UInt64(Date().timeIntervalSince1970 - 400)))
    }
    
    func getValidFirstManageDataOp (accountId: String) -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: accountId, name: "\(AuthTestUtils.anchorDomain) auth", data: generateNonce(length: 64)?.data(using: .utf8))
    }
    
    func getInvalidHomeDomainFirstOp (accountId: String) -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: accountId, name: "fake.com auth", data: generateNonce(length: 64)?.data(using: .utf8))
    }
    
    func getValidSecondManageDataOp () -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: serverKeyPair.accountId, name: "web_auth_domain", data: address.data(using: .utf8))
    }
    
    func getSecondManageDataOpInvalidSourceAccount () -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: AuthTestUtils.userAccountId, // invalid, must be server account id
                                   name: "web_auth_domain",
                                   data: address.data(using: .utf8))
    }
    
    func getInvalidWebAuthOp () -> ManageDataOperation {
        return ManageDataOperation(sourceAccountId: serverKeyPair.accountId, name: "web_auth_domain", data: "api.fake.org".data(using: .utf8))
    }
    
    func getMemo(_ memo:UInt64? = nil) -> Memo {
        var txmemo = Memo.none
        if let memoval = memo {
            txmemo = Memo.id(memoval)
        }
        return txmemo
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
    
    func requestSuccess(account: String, memo:UInt64? = nil) -> String {
 
        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [getValidFirstManageDataOp(accountId: account),getValidSecondManageDataOp()],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidSequenceNumber(account: String, memo:UInt64? = nil) -> String {
 
        let transaction = try! Transaction(sourceAccount: Account(keyPair: serverKeyPair, sequenceNumber: 2803983),
                                           operations: [getValidFirstManageDataOp(accountId: account),getValidSecondManageDataOp()],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidFirstOpSrcAcc(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: AuthTestUtils.serverAccountId), // invalid, because must be user account
                                            getValidSecondManageDataOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidSecondOpSrcAcc(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getSecondManageDataOpInvalidSourceAccount()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidHomeDomain(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getInvalidHomeDomainFirstOp(accountId: account),
                                            getSecondManageDataOpInvalidSourceAccount()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidWebAuthDomain(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getInvalidWebAuthOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidTimebounds(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getValidSecondManageDataOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getInvalidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidOperationType(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getValidSecondManageDataOp(),
                                            PaymentOperation(sourceAccountId: AuthTestUtils.userAccountId,
                                                             destinationAccountId: serverKeyPair.accountId,
                                                             asset: NativeAssetId().toAsset(),
                                                             amount: 100)
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeInvalidSignature(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getValidSecondManageDataOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        
        try! transaction.sign(keyPair: KeyPair.generateRandomKeyPair(), network: .testnet)
        
        return getResponseJson(transaction)
    }
    
    func requestChallengeMultipleSignature(account: String, memo:UInt64? = nil) -> String {

        let transaction = try! Transaction(sourceAccount: getValidTxAccount(),
                                           operations: [
                                            getValidFirstManageDataOp(accountId: account),
                                            getValidSecondManageDataOp()
                                           ],
                                           memo: getMemo(memo),
                                           preconditions: getValidTimeBounds())
        
        try! transaction.sign(keyPair: serverKeyPair, network: .testnet)
        try! transaction.sign(keyPair: KeyPair.generateRandomKeyPair(), network: .testnet)
        
        return getResponseJson(transaction)
    }
}

class AuthTestWebAuthSendChallengeResponseMock: ResponsesMock {
    var address: String
    
    init(address:String) {
        self.address = address
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let data = request.httpBodyStream?.readfully(), let json = try! JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String:Any] {
                if let key = json["transaction"] as? String {
                    let transactionEnvelope = try! TransactionEnvelopeXDR(xdr: key)
                    let transactionHash = try! [UInt8](transactionEnvelope.txHash(network: .testnet))
                    
                    // validate signature
                    var userSignatureFound = false
                    var clientSignatureFound = false
                    for signature in transactionEnvelope.txSignatures {
                        if !userSignatureFound {
                            userSignatureFound = try! AuthTestUtils.userKeypair.verify(signature: [UInt8](signature.signature), message: transactionHash)
                        }
                        if !clientSignatureFound {
                            clientSignatureFound = try! AuthTestUtils.clientKeypair.verify(signature: [UInt8](signature.signature), message: transactionHash)
                        }
                    }
                    var needsClientSignature = false
                    for operationXDR in transactionEnvelope.txOperations {
                        let operationBodyXDR = operationXDR.body
                        switch operationBodyXDR {
                        case .manageDataOp(let manageDataOperation):
                            if (manageDataOperation.dataName == "client_domain") {
                                needsClientSignature = true
                            }
                            break
                        default:
                            break
                        }
                    }
                    
                    if needsClientSignature && !clientSignatureFound {
                        mock.statusCode = 404
                        return """
                            {"error": "client domain signature not found"}
                        """
                    }
                    
                    if userSignatureFound {
                        mock.statusCode = 200
                        return self?.requestSuccess()
                    }
                }
            }
            mock.statusCode = 400
            return """
                {"error": "Bad request"}
            """
        }
        
        return RequestMock(host: address,
                           path: "/auth",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    func requestSuccess() -> String {
        return """
        {
        "token": "\(AuthTestUtils.jwtSuccess)"
        }
        """
    }
}


class ClientSignerResponseMock: ResponsesMock {
    var address: String
    
    init(address:String) {
        self.address = address
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let data = request.httpBodyStream?.readfully(), let json = try! JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String:Any] {
                if let tx = json["transaction"] as? String {
                    let signedTx = try! self?.signTx(txEnvelopeXdr: tx, seed: AuthTestUtils.clientSecretSeed)
                    mock.statusCode = 200
                    return self?.requestSuccess(signedTx: signedTx!)
                }
            }
            mock.statusCode = 400
            return """
                {"error": "Bad request"}
            """
        }
        
        return RequestMock(host: address,
                           path: "/auth",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    func signTx(txEnvelopeXdr:String, seed:String) throws -> String {
        let envelopeXDR = try TransactionEnvelopeXDR(xdr: txEnvelopeXdr)
        let transactionHash = try [UInt8](envelopeXDR.txHash(network: .testnet))
        let clientDomainAccountKey = try! KeyPair(secretSeed:seed)
        let signature = clientDomainAccountKey.signDecorated(transactionHash)
        envelopeXDR.appendSignature(signature: signature)
        let encoded = try XDREncoder.encode(envelopeXDR)
        return Data(bytes: encoded, count: encoded.count).base64EncodedString()
    }
    
    func requestSuccess(signedTx:String) -> String {
        return """
        {
        "transaction": "\(signedTx)",
        "network_passphrase": "\(Network.testnet.passphrase)"
        }
        """
    }
}
