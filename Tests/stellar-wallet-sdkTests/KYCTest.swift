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

    override func setUp() {
        super.setUp()
                
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
