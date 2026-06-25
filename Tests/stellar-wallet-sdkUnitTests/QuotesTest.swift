//
//  QuotesTest.swift
//  
//
//  Created by Christian Rogobete on 18.02.25.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class QuotesTestUtils {

    static let anchorDomain = "place.anchor.com"
    static let apiHost = "api.anchor.org"
    static let webAuthEndpoint = "https://\(apiHost)/auth"
    static let serviceAddress = "http://\(apiHost)/quotes-sep38"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"
    static let jwtSuccess = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0"
    
    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)
}

final class QuotesTest: XCTestCase {
    
    let wallet = Wallet.testNet
    var anchorTomlServerMock: TomlResponseMock!
    var challengeServerMock: WebAuthChallengeResponseMock!
    var sendChallengeServerMock: WebAuthSendChallengeResponseMock!
    var sep38InfoMock: Sep38InfoResponseMock!
    var sep38PricesMock: Sep38PricesResponseMock!
    var sep38PriceMock: Sep38PriceResponseMock!
    var sep38RequestQuoteMock: Sep38RequestQuoteResponseMock!
    var sep38GetQuoteMock: Sep38GetQuoteResponseMock!

    var sep38vFullTomlMock: TomlResponseMock!
    var sep38vChallengeMock: WebAuthChallengeResponseMock!
    var sep38vSendChallengeMock: WebAuthSendChallengeResponseMock!
    var sep38vQuoteMock: Sep38TestQuoteMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)
        anchorTomlServerMock = TomlResponseMock(host: QuotesTestUtils.anchorDomain,
                                                       serverSigningKey: QuotesTestUtils.serverAccountId,
                                                       authServer: QuotesTestUtils.webAuthEndpoint,
                                                anchorQuoteServer: QuotesTestUtils.serviceAddress)

        challengeServerMock = WebAuthChallengeResponseMock(host: QuotesTestUtils.apiHost,
                                                           serverKeyPair: QuotesTestUtils.serverKeypair)

        sendChallengeServerMock = WebAuthSendChallengeResponseMock(host: QuotesTestUtils.apiHost)
        sep38InfoMock = Sep38InfoResponseMock(host:  QuotesTestUtils.apiHost)
        sep38PricesMock = Sep38PricesResponseMock(host: QuotesTestUtils.apiHost)
        sep38PriceMock = Sep38PriceResponseMock(host: QuotesTestUtils.apiHost)
        sep38RequestQuoteMock = Sep38RequestQuoteResponseMock(host: QuotesTestUtils.apiHost)
        sep38GetQuoteMock = Sep38GetQuoteResponseMock(host: QuotesTestUtils.apiHost)

        sep38vFullTomlMock = TomlResponseMock(host: Sep38TestUtils.fullAnchorDomain,
                                        serverSigningKey: Sep38TestUtils.serverAccountId,
                                        authServer: Sep38TestUtils.webAuthEndpoint,
                                        sep24TransferServer: Sep38TestUtils.interactiveServer,
                                        anchorQuoteServer: Sep38TestUtils.quoteServer,
                                        kycServer: Sep38TestUtils.kycServer)

        sep38vChallengeMock = WebAuthChallengeResponseMock(host: Sep38TestUtils.apiHost,
                                                     serverKeyPair: Sep38TestUtils.serverKeypair,
                                                     homeDomain: Sep38TestUtils.fullAnchorDomain)
        sep38vSendChallengeMock = WebAuthSendChallengeResponseMock(host: Sep38TestUtils.apiHost)

        sep38vQuoteMock = Sep38TestQuoteMock(host: Sep38TestUtils.quoteHost)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - Sep38Test helpers

    private func sep38vFullAnchor() -> Anchor {
        return wallet.anchor(homeDomain: Sep38TestUtils.fullAnchorDomain)
    }

    private func sep38vAuthToken(for anchor: Anchor) async throws -> AuthToken {
        let authKey = try SigningKeyPair(secretKey: Sep38TestUtils.userSecretSeed)
        return try await anchor.sep10.authenticate(userKeyPair: authKey)
    }

    // MARK: - Sep38.swift validation and error branches

    func testSep38PriceRequiresExactlyOneAmount() async throws {
        let sep38 = try await sep38vFullAnchor().sep38(authToken: nil)
        // both amounts -> error
        do {
            _ = try await sep38.price(context: "sep31",
                                      sellAsset: "iso4217:BRL",
                                      buyAsset: "stellar:USDC:G",
                                      sellAmount: "1",
                                      buyAmount: "1")
            XCTFail("expected invalidArgument for both amounts")
        } catch ValidationError.invalidArgument {
            // expected
        }
        // neither amount -> error
        do {
            _ = try await sep38.price(context: "sep31",
                                      sellAsset: "iso4217:BRL",
                                      buyAsset: "stellar:USDC:G")
            XCTFail("expected invalidArgument for no amount")
        } catch ValidationError.invalidArgument {
            // expected
        }
    }

    func testSep38RequestQuoteRequiresExactlyOneAmount() async throws {
        let token = try await sep38vAuthToken(for: sep38vFullAnchor())
        let sep38 = try await sep38vFullAnchor().sep38(authToken: token)
        do {
            _ = try await sep38.requestQuote(context: "sep31",
                                             sellAsset: "iso4217:BRL",
                                             buyAsset: "stellar:USDC:G",
                                             sellAmount: "1",
                                             buyAmount: "1")
            XCTFail("expected invalidArgument for both amounts")
        } catch ValidationError.invalidArgument {
            // expected
        }
    }

    func testSep38RequestQuoteRequiresAuth() async throws {
        // sep38 constructed without an auth token -> requestQuote rejected before any network call.
        let sep38 = try await sep38vFullAnchor().sep38(authToken: nil)
        do {
            _ = try await sep38.requestQuote(context: "sep31",
                                             sellAsset: "iso4217:BRL",
                                             buyAsset: "stellar:USDC:G",
                                             buyAmount: "100")
            XCTFail("expected invalidArgument for missing auth")
        } catch ValidationError.invalidArgument(let message) {
            XCTAssertTrue(message.contains("authentication"))
        }
    }

    func testSep38GetQuoteRequiresAuth() async throws {
        let sep38 = try await sep38vFullAnchor().sep38(authToken: nil)
        do {
            _ = try await sep38.getQuote(quoteId: "abc")
            XCTFail("expected invalidArgument for missing auth")
        } catch ValidationError.invalidArgument(let message) {
            XCTAssertTrue(message.contains("authentication"))
        }
    }

    func testSep38InfoPermissionDenied() async throws {
        let sep38 = try await sep38vFullAnchor().sep38(authToken: nil)
        sep38vQuoteMock.infoStatusCode = 403
        do {
            _ = try await sep38.info
            XCTFail("expected permissionDenied")
        } catch QuoteServiceError.permissionDenied {
            // expected
        }
    }

    func testSep38InfoMalformedJson() async throws {
        let sep38 = try await sep38vFullAnchor().sep38(authToken: nil)
        sep38vQuoteMock.infoMalformed = true
        do {
            _ = try await sep38.info
            XCTFail("expected parsingResponseFailed")
        } catch QuoteServiceError.parsingResponseFailed {
            // expected
        }
    }

    func testSep38PriceBadRequest() async throws {
        let sep38 = try await sep38vFullAnchor().sep38(authToken: nil)
        sep38vQuoteMock.priceStatusCode = 400
        do {
            _ = try await sep38.price(context: "sep31",
                                      sellAsset: "iso4217:BRL",
                                      buyAsset: "stellar:USDC:G",
                                      sellAmount: "100")
            XCTFail("expected badRequest")
        } catch QuoteServiceError.badRequest {
            // expected
        }
    }

    func testSep38GetQuoteNotFound() async throws {
        let token = try await sep38vAuthToken(for: sep38vFullAnchor())
        let sep38 = try await sep38vFullAnchor().sep38(authToken: token)
        sep38vQuoteMock.quoteStatusCode = 404
        do {
            _ = try await sep38.getQuote(quoteId: "missing-quote")
            XCTFail("expected notFound")
        } catch QuoteServiceError.notFound {
            // expected
        }
    }

    // MARK: - QuotesResponse parsing optional-field coverage

    func testSep38InfoOptionalFieldsAbsent() async throws {
        let sep38 = try await sep38vFullAnchor().sep38(authToken: nil)
        let info = try await sep38.info
        XCTAssertEqual(1, info.assets.count)
        let asset = info.assets[0]
        XCTAssertEqual("stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN", asset.asset)
        // No delivery methods / country codes in the minimal info mock.
        XCTAssertNil(asset.sellDeliveryMethods)
        XCTAssertNil(asset.buyDeliveryMethods)
        XCTAssertNil(asset.countryCodes)
    }

    func testSep38PriceFeeWithoutDetails() async throws {
        let sep38 = try await sep38vFullAnchor().sep38(authToken: nil)
        let price = try await sep38.price(context: "sep31",
                                          sellAsset: "iso4217:BRL",
                                          buyAsset: "stellar:USDC:G",
                                          sellAmount: "100")
        XCTAssertEqual("1.00", price.totalPrice)
        XCTAssertEqual("0.90", price.price)
        XCTAssertEqual("100", price.sellAmount)
        XCTAssertEqual("90", price.buyAmount)
        XCTAssertEqual("0.00", price.fee.total)
        XCTAssertEqual("stellar:USDC:G", price.fee.asset)
        // fee details absent in this mock.
        XCTAssertNil(price.fee.details)
    }

    func testAll() async throws {
        let anchor = wallet.anchor(homeDomain: QuotesTestUtils.anchorDomain)
        let sep10 = try await anchor.sep10
        let authKey = try SigningKeyPair(secretKey: AuthTestUtils.userSecretSeed)
        let authToken = try await sep10.authenticate(userKeyPair: authKey)
        let sep38 = try await anchor.sep38(authToken: authToken)
        try await infoTest(sep38: sep38)
        try await testGetPrices(sep38: sep38)
        try await testGetPrice(sep38: sep38)
        try await testRequestQuote(sep38: sep38)
        try await testGetQuote(sep38: sep38)
    }
    
    func infoTest(sep38:Sep38) async throws {
        let response = try await sep38.info
        
        XCTAssertEqual(3, response.assets.count)
        let assets = response.assets
        XCTAssertEqual("stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN", assets[0].asset)
        XCTAssertEqual("stellar:BRL:GDVKY2GU2DRXWTBEYJJWSFXIGBZV6AZNBVVSUHEPZI54LIS6BA7DVVSP", assets[1].asset)
        XCTAssertEqual("iso4217:BRL", assets[2].asset)
        XCTAssertNotNil(assets[2].countryCodes)
        XCTAssertEqual(1, assets[2].countryCodes?.count)
        XCTAssertEqual("BRA", assets[2].countryCodes?[0])
        XCTAssertNotNil(assets[2].sellDeliveryMethods)
        XCTAssertEqual(3, assets[2].sellDeliveryMethods?.count)
        XCTAssertEqual("cash", assets[2].sellDeliveryMethods?[0].name)
        XCTAssertEqual("Deposit cash BRL at one of our agent locations.", assets[2].sellDeliveryMethods?[0].description)
        XCTAssertEqual("ACH", assets[2].sellDeliveryMethods?[1].name)
        XCTAssertEqual("Send BRL directly to the Anchor's bank account.", assets[2].sellDeliveryMethods?[1].description)
        XCTAssertEqual("PIX", assets[2].sellDeliveryMethods?[2].name)
        XCTAssertEqual("Send BRL directly to the Anchor's bank account.", assets[2].sellDeliveryMethods?[2].description)
        XCTAssertNotNil(assets[2].buyDeliveryMethods)
        XCTAssertEqual(3, assets[2].buyDeliveryMethods?.count)
        XCTAssertEqual("ACH", assets[2].buyDeliveryMethods?[1].name)
        XCTAssertEqual("Have BRL sent directly to your bank account.", assets[2].buyDeliveryMethods?[1].description)
        XCTAssertEqual("PIX", assets[2].buyDeliveryMethods?[2].name)
        XCTAssertEqual("Have BRL sent directly to the account of your choice.", assets[2].buyDeliveryMethods?[2].description)
    }
    
    func testGetPrices(sep38:Sep38) async throws {
        let sellAsset = "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
        let sellAmount = "100"
        let countryCode = "BRA"
        let buyDeliveryMethod = "ACH"
        
        let response = try await sep38.prices(sellAsset: sellAsset,
                                              sellAmount: sellAmount,
                                              buyDeliveryMethod: buyDeliveryMethod,
                                              countryCode: countryCode)
        
        
        XCTAssertEqual(1, response.buyAssets.count)
        let buyAssets = response.buyAssets
        XCTAssertEqual(1, buyAssets.count)
        XCTAssertEqual("iso4217:BRL", buyAssets[0].asset)
        XCTAssertEqual("0.18", buyAssets[0].price)
        XCTAssertEqual(2, buyAssets[0].decimals)
    }
    
    func testGetPrice(sep38:Sep38) async throws {
        
        let sellAsset = "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
        let buyAsset = "iso4217:BRL"
        let buyAmount = "500"
        let buyDeliveryMethod = "PIX"
        let countryCode = "BRA"
        let context = "sep31"
        
        let response = try await sep38.price(context:context,
                                             sellAsset: sellAsset,
                                             buyAsset: buyAsset,
                                             buyAmount: buyAmount,
                                             buyDeliveryMethod: buyDeliveryMethod,
                                             countryCode: countryCode)
        
        XCTAssertEqual("0.20", response.totalPrice)
        XCTAssertEqual("0.18", response.price)
        XCTAssertEqual("100", response.sellAmount)
        XCTAssertEqual("500", response.buyAmount)
        XCTAssertNotNil(response.fee)
        let fee = response.fee
        XCTAssertEqual("10.00", fee.total)
        XCTAssertEqual("stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN", fee.asset)
        XCTAssertNotNil(fee.details)
        let feeDetails = fee.details
        XCTAssertEqual(2, feeDetails?.count)
        XCTAssertEqual("Service fee", feeDetails?[0].name)
        XCTAssertNil(feeDetails?[0].description)
        XCTAssertEqual("5.00", feeDetails?[0].amount)
        XCTAssertEqual("PIX fee", feeDetails?[1].name)
        XCTAssertEqual("Fee charged in order to process the outgoing BRL PIX transaction.", feeDetails?[1].description)
        XCTAssertEqual("5.00", feeDetails?[1].amount)
    }
    
    func testRequestQuote(sep38:Sep38) async throws {
        
        let sellAsset = "iso4217:BRL"
        let buyAsset = "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
        
        let response = try await sep38.requestQuote(context: "sep31",
                                                    sellAsset: sellAsset,
                                                    buyAsset: buyAsset,
                                                    buyAmount : "100",
                                                    expireAfter : Date(),
                                                    sellDeliveryMethod : "PIX",
                                                    countryCode : "BRA")
        XCTAssertEqual("de762cda-a193-4961-861e-57b31fed6eb3", response.id)
        XCTAssertEqual("5.42", response.totalPrice)
        XCTAssertEqual("5.00", response.price)
        XCTAssertEqual(sellAsset, response.sellAsset)
        XCTAssertEqual(buyAsset, response.buyAsset)
        XCTAssertEqual("542", response.sellAmount)
        XCTAssertEqual("100", response.buyAmount)
    }
    
    func testGetQuote(sep38:Sep38) async throws {
        
        let response = try await sep38.getQuote(quoteId: "de762cda-a193-4961-861e-57b31fed6eb3")
        XCTAssertEqual("de762cda-a193-4961-861e-57b31fed6eb3", response.id)
        XCTAssertEqual("5.42", response.totalPrice)
        XCTAssertEqual("5.00", response.price)
        XCTAssertEqual("iso4217:BRL", response.sellAsset)
        XCTAssertEqual("stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN", response.buyAsset)
        XCTAssertEqual("542", response.sellAmount)
        XCTAssertEqual("100", response.buyAmount)
    }
}

class Sep38InfoResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.success
        }
        
        return RequestMock(host: host,
                           path: "/quotes-sep38/info",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    let success = """
    {
      "assets":  [
        {
          "asset": "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
        },
        {
          "asset": "stellar:BRL:GDVKY2GU2DRXWTBEYJJWSFXIGBZV6AZNBVVSUHEPZI54LIS6BA7DVVSP"
        },
        {
          "asset": "iso4217:BRL",
          "country_codes": ["BRA"],
          "sell_delivery_methods": [
            {
              "name": "cash",
              "description": "Deposit cash BRL at one of our agent locations."
            },
            {
              "name": "ACH",
              "description": "Send BRL directly to the Anchor's bank account."
            },
            {
              "name": "PIX",
              "description": "Send BRL directly to the Anchor's bank account."
            }
          ],
          "buy_delivery_methods": [
            {
              "name": "cash",
              "description": "Pick up cash BRL at one of our payout locations."
            },
            {
              "name": "ACH",
              "description": "Have BRL sent directly to your bank account."
            },
            {
              "name": "PIX",
              "description": "Have BRL sent directly to the account of your choice."
            }
          ]
        }
      ]
    }
    """
    
}

class Sep38PricesResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.success
        }
        
        return RequestMock(host: host,
                           path: "/quotes-sep38/prices",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    let success = """
    {
      "buy_assets": [
        {
          "asset": "iso4217:BRL",
          "price": "0.18",
          "decimals": 2
        }
      ]
    }
    """
}

class Sep38PriceResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.success
        }
        
        return RequestMock(host: host,
                           path: "/quotes-sep38/price",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    let success = """
    {
      "total_price": "0.20",
      "price": "0.18",
      "sell_amount": "100",
      "buy_amount": "500",
      "fee": {
        "total": "10.00",
        "asset": "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN",
        "details": [
          {
            "name": "Service fee",
            "amount": "5.00"
          },
          {
            "name": "PIX fee",
            "description": "Fee charged in order to process the outgoing BRL PIX transaction.",
            "amount": "5.00"
          }
        ]
      }
    }
    """
}

class Sep38RequestQuoteResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let data = request.httpBodyStream?.readfully() {
                let body = String(decoding: data, as: UTF8.self)
                print(body)
            }
            mock.statusCode = 200
            return self?.success
        }
        
        return RequestMock(host: host,
                           path: "/quotes-sep38/quote",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
    
    let success = """
    {
      "id": "de762cda-a193-4961-861e-57b31fed6eb3",
      "expires_at": "2021-04-30T07:42:23",
      "total_price": "5.42",
      "price": "5.00",
      "sell_asset": "iso4217:BRL",
      "sell_amount": "542",
      "buy_asset": "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN",
      "buy_amount": "100",
      "fee": {
        "total": "42.00",
        "asset": "iso4217:BRL",
        "details": [
          {
            "name": "PIX fee",
            "description": "Fee charged in order to process the outgoing PIX transaction.",
            "amount": "12.00"
          },
          {
            "name": "Brazilian conciliation fee",
            "description": "Fee charged in order to process conciliation costs with intermediary banks.",
            "amount": "15.00"
          },
          {
            "name": "Service fee",
            "amount": "15.00"
          }
        ]
      }
    }
    """
    
}

class Sep38GetQuoteResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.success
        }
        
        return RequestMock(host: host,
                           path: "/quotes-sep38/quote/de762cda-a193-4961-861e-57b31fed6eb3",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    let success = """
    {
      "id": "de762cda-a193-4961-861e-57b31fed6eb3",
      "expires_at": "2021-04-30T07:42:23",
      "total_price": "5.42",
      "price": "5.00",
      "sell_asset": "iso4217:BRL",
      "sell_amount": "542",
      "buy_asset": "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN",
      "buy_amount": "100",
      "fee": {
        "total": "42.00",
        "asset": "iso4217:BRL",
        "details": [
          {
            "name": "PIX fee",
            "description": "Fee charged in order to process the outgoing PIX transaction.",
            "amount": "12.00"
          },
          {
            "name": "Brazilian conciliation fee",
            "description": "Fee charged in order to process conciliation costs with intermediary banks.",
            "amount": "15.00"
          },
          {
            "name": "Service fee",
            "amount": "15.00"
          }
        ]
      }
    }
    """
}

final class Sep38TestUtils {

    // Domain that resolves to a stellar.toml exposing SEP-24, SEP-10, KYC and quote services.
    static let fullAnchorDomain = "full.sep38test.com"
    // Domain whose stellar.toml only exposes a signing key (no services at all).
    static let emptyAnchorDomain = "empty.sep38test.com"

    static let apiHost = "api.sep38test.org"
    static let webAuthEndpoint = "https://\(apiHost)/auth"

    static let interactiveHost = "sep24.sep38test.org"
    static let quoteHost = "sep38.sep38test.org"
    static let kycHost = "sep12.sep38test.org"

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

class Sep38TestQuoteMock: ResponsesMock {
    var host: String
    var infoStatusCode = 200
    var infoMalformed = false
    var priceStatusCode = 200
    var quoteStatusCode = 200

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            let path = request.url?.path ?? ""
            if path.hasSuffix("/info") {
                if self.infoMalformed {
                    mock.statusCode = 200
                    return "{ not json"
                }
                mock.statusCode = self.infoStatusCode
                if self.infoStatusCode != 200 {
                    return "{\"error\": \"forbidden\"}"
                }
                return self.info
            } else if path.hasSuffix("/price") {
                mock.statusCode = self.priceStatusCode
                if self.priceStatusCode != 200 {
                    return "{\"error\": \"bad request\"}"
                }
                return self.price
            } else if path.contains("/quote") {
                mock.statusCode = self.quoteStatusCode
                if self.quoteStatusCode != 200 {
                    return "{\"error\": \"not found\"}"
                }
                return self.quote
            }
            mock.statusCode = 404
            return "{\"error\": \"not found\"}"
        }
        // Matches /quotes-sep38/info, /quotes-sep38/price, /quotes-sep38/quote, /quotes-sep38/quote/{id}
        return RequestMock(host: host,
                           path: "*",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    // Minimal info: single asset, no optional arrays.
    let info = """
    {
      "assets": [
        { "asset": "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN" }
      ]
    }
    """

    // Price with a fee that has no details array.
    let price = """
    {
      "total_price": "1.00",
      "price": "0.90",
      "sell_amount": "100",
      "buy_amount": "90",
      "fee": { "total": "0.00", "asset": "stellar:USDC:G" }
    }
    """

    let quote = """
    {
      "id": "q1",
      "expires_at": "2021-04-30T07:42:23",
      "total_price": "1.00",
      "price": "0.90",
      "sell_asset": "iso4217:BRL",
      "sell_amount": "100",
      "buy_asset": "stellar:USDC:G",
      "buy_amount": "90",
      "fee": { "total": "0.00", "asset": "iso4217:BRL" }
    }
    """
}
