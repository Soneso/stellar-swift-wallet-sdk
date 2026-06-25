//
//  KYCTest.swift
//
//
//  Created by Christian Rogobete on 19.02.25.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class KYCTestUtils {

    static let anchorDomain = "place.anchor.com"
    static let apiHost = "api.anchor.org"
    static let webAuthEndpoint = "https://\(apiHost)/auth"
    static let serviceAddress = "http://\(apiHost)/kyc"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"
    static let jwtSuccess = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0"
    
    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)
    
    static let customerId = "d1ce2f48-3ff1-495d-9240-7a50d806cfed"
}

final class KYCTest: XCTestCase {

    let wallet = Wallet.testNet
    var anchorTomlServerMock: TomlResponseMock!
    var challengeServerMock: WebAuthChallengeResponseMock!
    var sendChallengeServerMock: WebAuthSendChallengeResponseMock!
    var addCustomerServerMock: AddCustomerResponseMock!
    var getCustomerServerMock:GetCustomerResponseMock!
    var putVerificationServerMock:PutVerificationResponseMock!
    var deleteCustomerServerMock: DeleteCustomerResponseMock!

    var sep12FullTomlMock: TomlResponseMock!
    var sep12ChallengeMock: WebAuthChallengeResponseMock!
    var sep12SendChallengeMock: WebAuthSendChallengeResponseMock!
    var sep12CustomerMock: Sep12TestCustomerMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)
        anchorTomlServerMock = TomlResponseMock(host: KYCTestUtils.anchorDomain,
                                                serverSigningKey: KYCTestUtils.serverAccountId,
                                                authServer: KYCTestUtils.webAuthEndpoint,
                                                kycServer: KYCTestUtils.serviceAddress)

        challengeServerMock = WebAuthChallengeResponseMock(host: KYCTestUtils.apiHost,
                                                           serverKeyPair: KYCTestUtils.serverKeypair)

        sendChallengeServerMock = WebAuthSendChallengeResponseMock(host: KYCTestUtils.apiHost)
        addCustomerServerMock = AddCustomerResponseMock(host: KYCTestUtils.apiHost)
        getCustomerServerMock = GetCustomerResponseMock(host: KYCTestUtils.apiHost)
        putVerificationServerMock = PutVerificationResponseMock(host: KYCTestUtils.apiHost)
        deleteCustomerServerMock = DeleteCustomerResponseMock(host: KYCTestUtils.apiHost)

        sep12FullTomlMock = TomlResponseMock(host: Sep12TestUtils.fullAnchorDomain,
                                        serverSigningKey: Sep12TestUtils.serverAccountId,
                                        authServer: Sep12TestUtils.webAuthEndpoint,
                                        sep24TransferServer: Sep12TestUtils.interactiveServer,
                                        anchorQuoteServer: Sep12TestUtils.quoteServer,
                                        kycServer: Sep12TestUtils.kycServer)

        sep12ChallengeMock = WebAuthChallengeResponseMock(host: Sep12TestUtils.apiHost,
                                                     serverKeyPair: Sep12TestUtils.serverKeypair,
                                                     homeDomain: Sep12TestUtils.fullAnchorDomain)
        sep12SendChallengeMock = WebAuthSendChallengeResponseMock(host: Sep12TestUtils.apiHost)

        sep12CustomerMock = Sep12TestCustomerMock(host: Sep12TestUtils.kycHost)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    func testAll() async throws {
        let anchor = wallet.anchor(homeDomain: QuotesTestUtils.anchorDomain)
        let sep10 = try await anchor.sep10
        let authKey = try SigningKeyPair(secretKey: KYCTestUtils.userSecretSeed)
        let authToken = try await sep10.authenticate(userKeyPair: authKey)
        let sep12 = try await anchor.sep12(authToken: authToken)
        try await addTest(sep12: sep12)
        try await getTest(sep12: sep12)
        try await putVerificationTest(sep12: sep12)
        try await deleteTest(sep12: sep12)
    }
    
    func addTest(sep12:Sep12) async throws {
        let sep9Info:[String:String] = [Sep9PersonKeys.firstName : "John", 
                                        Sep9PersonKeys.lastName : "Doe",
                                        Sep9PersonKeys.emailAddress : "john@doe.com"]
        
        let response = try await sep12.add(sep9Info: sep9Info)
        XCTAssertEqual(KYCTestUtils.customerId, response.id)
    }
    
    func getTest(sep12:Sep12) async throws {
        
        let response = try await sep12.get(id:KYCTestUtils.customerId)
        XCTAssertEqual(KYCTestUtils.customerId, response.id)
        XCTAssertEqual(Sep12Status.accepted, response.sep12Status)
        guard let providedFields = response.providedFields else {
            XCTFail("should contain provided fields")
            return
        }
        guard let firstName = providedFields[Sep9PersonKeys.firstName] else {
            XCTFail("should contain provided field: first_name")
            return
        }
        XCTAssertEqual(Sep12Status.accepted, firstName.sep12Status)
        XCTAssertEqual("The customer's first name", firstName.description)
        XCTAssertEqual(FieldType.string, firstName.type)
        
        guard let lastName = providedFields[Sep9PersonKeys.lastName] else {
            XCTFail("should contain provided field: last_name")
            return
        }
        XCTAssertEqual(Sep12Status.accepted, lastName.sep12Status)
        XCTAssertEqual("The customer's last name", lastName.description)
        XCTAssertEqual(FieldType.string, lastName.type)
        
        guard let emailAddress = providedFields[Sep9PersonKeys.emailAddress] else {
            XCTFail("should contain provided field: email_address")
            return
        }
        XCTAssertEqual(Sep12Status.accepted, emailAddress.sep12Status)
        XCTAssertEqual("The customer's email address", emailAddress.description)
        XCTAssertEqual(FieldType.string, emailAddress.type)
    }
    
    func putVerificationTest(sep12:Sep12) async throws {
        
        let response = try await sep12.verify(id: KYCTestUtils.customerId, 
                                              verificationFields: ["mobile_number_verification": "1871287"])
        XCTAssertEqual(KYCTestUtils.customerId, response.id)
        XCTAssertEqual(Sep12Status.accepted, response.sep12Status)
        guard let providedFields = response.providedFields else {
            XCTFail("should contain provided fields")
            return
        }
        guard let mobileNumber = providedFields[Sep9PersonKeys.mobileNumber] else {
            XCTFail("should contain provided field: mobile_number")
            return
        }
        XCTAssertEqual(Sep12Status.accepted, mobileNumber.sep12Status)
        XCTAssertEqual("phone number of the customer", mobileNumber.description)
        XCTAssertEqual(FieldType.string, mobileNumber.type)
    }
    
    func deleteTest(sep12:Sep12) async throws {
        let accountId = try KeyPair(secretSeed: KYCTestUtils.userSecretSeed).accountId
        try await sep12.delete(account: accountId)
    }

    // MARK: - helpers

    private func fullAnchor() -> Anchor {
        return wallet.anchor(homeDomain: Sep12TestUtils.fullAnchorDomain)
    }

    private func authToken(for anchor: Anchor) async throws -> AuthToken {
        let authKey = try SigningKeyPair(secretKey: Sep12TestUtils.userSecretSeed)
        return try await anchor.sep10.authenticate(userKeyPair: authKey)
    }

    // MARK: - Sep12.swift error / parsing branches

    func testSep12GetNotFound() async throws {
        let token = try await authToken(for: fullAnchor())
        let sep12 = try await fullAnchor().sep12(authToken: token)
        do {
            _ = try await sep12.get(id: "does-not-exist")
            XCTFail("expected KycServiceError.notFound")
        } catch KycServiceError.notFound {
            // expected
        }
    }

    func testSep12GetByAuthTokenOnlyNeedsInfo() async throws {
        let token = try await authToken(for: fullAnchor())
        let sep12 = try await fullAnchor().sep12(authToken: token)
        // No id -> auth-token-only path returning NEEDS_INFO with required fields.
        let response = try await sep12.getByAuthTokenOnly()
        XCTAssertEqual(.neesdInfo, response.sep12Status)
        guard let fields = response.fields else {
            XCTFail("expected fields for NEEDS_INFO")
            return
        }
        guard let emailField = fields["email_address"] else {
            XCTFail("expected email_address field")
            return
        }
        XCTAssertEqual(.string, emailField.type)
        XCTAssertEqual(true, emailField.optional)
        guard let idTypeField = fields["id_type"] else {
            XCTFail("expected id_type field")
            return
        }
        XCTAssertEqual(["passport", "drivers_license"], idTypeField.choices)
    }

    func testSep12AddBadRequest() async throws {
        let token = try await authToken(for: fullAnchor())
        let sep12 = try await fullAnchor().sep12(authToken: token)
        sep12CustomerMock.putStatusCode = 400
        do {
            _ = try await sep12.add(sep9Info: [Sep9PersonKeys.firstName: "x"])
            XCTFail("expected KycServiceError.badRequest")
        } catch KycServiceError.badRequest {
            // expected
        }
    }

    func testSep12GetProvidedFieldRejectedWithError() async throws {
        let token = try await authToken(for: fullAnchor())
        let sep12 = try await fullAnchor().sep12(authToken: token)
        let response = try await sep12.getByIdAndType(id: "rejected-customer", type: "sep24")
        XCTAssertEqual(.rejected, response.sep12Status)
        XCTAssertEqual("rejected-customer", response.id)
        XCTAssertEqual("documents are not legible", response.message)
        guard let provided = response.providedFields,
              let photoField = provided["photo_id_front"] else {
            XCTFail("expected provided photo_id_front field")
            return
        }
        XCTAssertEqual(.binary, photoField.type)
        XCTAssertEqual(.rejected, photoField.sep12Status)
        XCTAssertEqual("the photo is too blurry", photoField.error)
    }

    func testSep12GetUnknownStatusDefaultsToNeedsInfo() async throws {
        let token = try await authToken(for: fullAnchor())
        let sep12 = try await fullAnchor().sep12(authToken: token)
        let response = try await sep12.get(id: "weird-status")
        // Unknown status string -> defaults to NEEDS_INFO.
        XCTAssertEqual(.neesdInfo, response.sep12Status)
    }

    func testSep12GetUnknownFieldTypeDefaultsToString() async throws {
        let token = try await authToken(for: fullAnchor())
        let sep12 = try await fullAnchor().sep12(authToken: token)
        let response = try await sep12.get(id: "weird-field-type")
        guard let fields = response.fields, let f = fields["mystery"] else {
            XCTFail("expected mystery field")
            return
        }
        // Unknown field type -> defaults to .string.
        XCTAssertEqual(.string, f.type)
    }

    // MARK: - Sep12 update / verify / delete error branches

    /// Anchor/auth/kyc mocks for the update / verify / delete error-branch tests,
    /// registered lazily so the suite's existing setUp is left untouched.
    var writeAnchorTomlMock: TomlResponseMock!
    var writeChallengeMock: WebAuthChallengeResponseMock!
    var writeSendChallengeMock: WebAuthSendChallengeResponseMock!
    var kycMock: Sep12WriteKycMock!

    private func registerWriteMocks() {
        guard kycMock == nil else { return }
        writeAnchorTomlMock = TomlResponseMock(host: Sep12WriteUtils.anchorDomain,
                                                 serverSigningKey: Sep12WriteUtils.serverAccountId,
                                                 authServer: Sep12WriteUtils.webAuthEndpoint,
                                                 kycServer: Sep12WriteUtils.kycServer)
        writeChallengeMock = WebAuthChallengeResponseMock(host: Sep12WriteUtils.apiHost,
                                                            serverKeyPair: Sep12WriteUtils.serverKeypair,
                                                            homeDomain: Sep12WriteUtils.anchorDomain)
        writeSendChallengeMock = WebAuthSendChallengeResponseMock(host: Sep12WriteUtils.apiHost)
        kycMock = Sep12WriteKycMock(host: Sep12WriteUtils.apiHost)
    }

    private func authToken() async throws -> AuthToken {
        registerWriteMocks()
        let anchor = wallet.anchor(homeDomain: Sep12WriteUtils.anchorDomain)
        let authKey = try SigningKeyPair(secretKey: Sep12WriteUtils.userSecretSeed)
        return try await anchor.sep10.authenticate(userKeyPair: authKey)
    }

    private func sep12() async throws -> Sep12 {
        let token = try await authToken()
        return try await wallet.anchor(homeDomain: Sep12WriteUtils.anchorDomain).sep12(authToken: token)
    }

    // MARK: - Sep12.update

    func testSep12UpdateSuccess() async throws {
        let sep12 = try await sep12()
        let response = try await sep12.update(id: "customer-id",
                                              sep9Info: [Sep9PersonKeys.firstName: "Jane"])
        XCTAssertEqual("customer-id", response.id)
    }

    func testSep12UpdateNotFound() async throws {
        let sep12 = try await sep12()
        kycMock.putStatusCode = 404
        do {
            _ = try await sep12.update(id: "missing-customer",
                                       sep9Info: [Sep9PersonKeys.firstName: "Jane"])
            XCTFail("expected KycServiceError.notFound")
        } catch KycServiceError.notFound {
            // expected: 404 with a JSON error body maps to notFound.
        }
    }

    func testSep12UpdateBadRequest() async throws {
        let sep12 = try await sep12()
        kycMock.putStatusCode = 400
        do {
            _ = try await sep12.update(id: "customer-id",
                                       sep9Info: [Sep9PersonKeys.firstName: "Jane"])
            XCTFail("expected KycServiceError.badRequest")
        } catch KycServiceError.badRequest {
            // expected: 400 with a JSON error body maps to badRequest.
        }
    }

    // MARK: - Sep12.verify failure

    func testSep12VerifyNotFound() async throws {
        let sep12 = try await sep12()
        kycMock.verifyStatusCode = 404
        do {
            _ = try await sep12.verify(id: "missing-customer",
                                       verificationFields: ["mobile_number_verification": "123456"])
            XCTFail("expected KycServiceError.notFound")
        } catch KycServiceError.notFound {
            // expected
        }
    }

    // MARK: - Sep12.delete failure

    func testSep12DeleteNotFound() async throws {
        let sep12 = try await sep12()
        kycMock.deleteStatusCode = 404
        let accountId = try KeyPair(secretSeed: Sep12WriteUtils.userSecretSeed).accountId
        do {
            try await sep12.delete(account: accountId)
            XCTFail("expected KycServiceError.notFound")
        } catch KycServiceError.notFound {
            // expected
        }
    }
}

class GetCustomerResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            return self?.accepted
        }
        
        return RequestMock(host: host,
                           path: "kyc/customer",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    let accepted = """
    {
       "id": "\(KYCTestUtils.customerId)",
       "status": "ACCEPTED",
       "provided_fields": {
          "first_name": {
             "description": "The customer's first name",
             "type": "string",
             "status": "ACCEPTED"
          },
          "last_name": {
             "description": "The customer's last name",
             "type": "string",
             "status": "ACCEPTED"
          },
          "email_address": {
             "description": "The customer's email address",
             "type": "string",
             "status": "ACCEPTED"
          }
       }
    }
    """
}

class AddCustomerResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            return self?.addSuccess
        }
        
        return RequestMock(host: host,
                           path: "kyc/customer",
                           httpMethod: "PUT",
                           mockHandler: handler)
    }
    
    let addSuccess = """
    {
        "id": "\(KYCTestUtils.customerId)"
    }
    """
}

class PutVerificationResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            return self?.success
        }
        
        return RequestMock(host: host,
                           path: "kyc/customer/verification",
                           httpMethod: "PUT",
                           mockHandler: handler)
    }
        
    let success = """
    {
       "id": "\(KYCTestUtils.customerId)",
       "status": "ACCEPTED",
       "provided_fields": {
          "mobile_number": {
             "description": "phone number of the customer",
             "type": "string",
             "status": "ACCEPTED"
          }
       }
    }
    """
}

class DeleteCustomerResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { mock, request in
            mock.statusCode = 200
            return nil
        }
        
        return RequestMock(host: host,
                           path: "kyc/customer/${variable}",
                           httpMethod: "DELETE",
                           mockHandler: handler)
    }
}

final class Sep12TestUtils {

    // Domain that resolves to a stellar.toml exposing SEP-24, SEP-10, KYC and quote services.
    static let fullAnchorDomain = "full.sep12test.com"
    // Domain whose stellar.toml only exposes a signing key (no services at all).
    static let emptyAnchorDomain = "empty.sep12test.com"

    static let apiHost = "api.sep12test.org"
    static let webAuthEndpoint = "https://\(apiHost)/auth"

    static let interactiveHost = "sep24.sep12test.org"
    static let quoteHost = "sep38.sep12test.org"
    static let kycHost = "sep12.sep12test.org"

    static let interactiveServer = "https://\(interactiveHost)"
    static let quoteServer = "http://\(quoteHost)/quotes-sep38"
    static let kycServer = "http://\(kycHost)/kyc"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"

    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)

    static let usdcAsset = try! IssuedAssetId(code: "USDC",
                                              issuer: "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM")
}

// MARK: - Namespaced mocks

/// Registers BOTH the GET and PUT handlers for /kyc/customer. ResponsesMock only
/// registers a single RequestMock per instance, so the PUT handler is registered
/// through a nested helper mock created from the same host.
class Sep12TestCustomerMock: ResponsesMock {
    var host: String
    private let putMock: Sep12TestCustomerPutMock

    var putStatusCode: Int {
        get { putMock.putStatusCode }
        set { putMock.putStatusCode = newValue }
    }

    init(host: String) {
        self.host = host
        self.putMock = Sep12TestCustomerPutMock(host: host)
        super.init()
    }

    override func requestMock() -> RequestMock {
        let getHandler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            let id = mock.variables["id"]
            switch id {
            case "does-not-exist":
                mock.statusCode = 404
                return "{\"error\": \"customer not found\"}"
            case "rejected-customer":
                mock.statusCode = 200
                return self.rejected
            case "weird-status":
                mock.statusCode = 200
                return self.weirdStatus
            case "weird-field-type":
                mock.statusCode = 200
                return self.weirdFieldType
            default:
                // no id -> auth-token-only NEEDS_INFO
                mock.statusCode = 200
                return self.needsInfo
            }
        }
        return RequestMock(host: host,
                           path: "/kyc/customer",
                           httpMethod: "GET",
                           mockHandler: getHandler)
    }

    let needsInfo = """
    {
      "status": "NEEDS_INFO",
      "fields": {
        "email_address": { "type": "string", "description": "email", "optional": true },
        "id_type": { "type": "string", "description": "type of id", "choices": ["passport", "drivers_license"] }
      }
    }
    """

    let rejected = """
    {
      "id": "rejected-customer",
      "status": "REJECTED",
      "message": "documents are not legible",
      "provided_fields": {
        "photo_id_front": { "type": "binary", "description": "front of id", "status": "REJECTED", "error": "the photo is too blurry" }
      }
    }
    """

    let weirdStatus = """
    { "status": "SOMETHING_UNEXPECTED" }
    """

    let weirdFieldType = """
    {
      "status": "NEEDS_INFO",
      "fields": { "mystery": { "type": "quantum", "description": "mystery field" } }
    }
    """
}

class Sep12TestCustomerPutMock: ResponsesMock {
    var host: String
    var putStatusCode = 200

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            mock.statusCode = self.putStatusCode
            if self.putStatusCode != 200 {
                return "{\"error\": \"invalid first_name\"}"
            }
            return "{ \"id\": \"new-customer-id\" }"
        }
        return RequestMock(host: host,
                           path: "/kyc/customer",
                           httpMethod: "PUT",
                           mockHandler: handler)
    }
}

// MARK: - Sep12 update / verify / delete mocks

final class Sep12WriteUtils {

    static let anchorDomain = "anchor.writesep12.example"
    static let apiHost = "api.writesep12.example"
    static let webAuthEndpoint = "https://\(apiHost)/auth"
    static let kycServer = "http://\(apiHost)/kyc"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"

    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)
}

/// Registers PUT /kyc/customer, PUT /kyc/customer/verification and
/// DELETE /kyc/customer/{account} handlers, each with a configurable status code.
class Sep12WriteKycMock: ResponsesMock {
    let host: String
    var putStatusCode = 200
    private let verifyMock: Sep12WriteKycVerifyMock
    private let deleteMock: Sep12WriteKycDeleteMock

    var verifyStatusCode: Int {
        get { verifyMock.statusCode }
        set { verifyMock.statusCode = newValue }
    }

    var deleteStatusCode: Int {
        get { deleteMock.statusCode }
        set { deleteMock.statusCode = newValue }
    }

    init(host: String) {
        self.host = host
        self.verifyMock = Sep12WriteKycVerifyMock(host: host)
        self.deleteMock = Sep12WriteKycDeleteMock(host: host)
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, _ in
            guard let self = self else { return nil }
            mock.statusCode = self.putStatusCode
            if self.putStatusCode != 200 {
                return "{\"error\": \"customer not found\"}"
            }
            return "{ \"id\": \"customer-id\" }"
        }
        return RequestMock(host: host,
                           path: "kyc/customer",
                           httpMethod: "PUT",
                           mockHandler: handler)
    }
}

class Sep12WriteKycVerifyMock: ResponsesMock {
    let host: String
    var statusCode = 200

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, _ in
            guard let self = self else { return nil }
            mock.statusCode = self.statusCode
            if self.statusCode != 200 {
                return "{\"error\": \"customer not found\"}"
            }
            return """
            {
               "id": "customer-id",
               "status": "ACCEPTED"
            }
            """
        }
        return RequestMock(host: host,
                           path: "kyc/customer/verification",
                           httpMethod: "PUT",
                           mockHandler: handler)
    }
}

class Sep12WriteKycDeleteMock: ResponsesMock {
    let host: String
    var statusCode = 200

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, _ in
            guard let self = self else { return nil }
            mock.statusCode = self.statusCode
            if self.statusCode != 200 {
                return "{\"error\": \"customer not found\"}"
            }
            return nil
        }
        return RequestMock(host: host,
                           path: "kyc/customer/${account}",
                           httpMethod: "DELETE",
                           mockHandler: handler)
    }
}
