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
    
    override func setUp() {
        super.setUp()
                
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
