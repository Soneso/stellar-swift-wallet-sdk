//
//  AnchorPlatformIntegrationTests.swift
//  stellar-wallet-sdkIntegrationTests
//
//  Integration tests for Anchor Platform SEP protocols
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class AnchorPlatformIntegrationTests: XCTestCase {
    
    var wallet: Wallet!
    var stellar: Stellar!
    var anchor: Anchor!
    var accountKp: SigningKeyPair!
    
    override func setUp() {
        super.setUp()
        wallet = Wallet.testNet
        stellar = wallet.stellar
        // Initialize anchor service with live anchor platform
        anchor = wallet.anchor(homeDomain: TestConstants.anchorDomain)
    }
    
    override func tearDown() {
        anchor = nil
        accountKp = nil
        wallet = nil
        stellar = nil
        super.tearDown()
    }
    
    // MARK: - SEP-10 Authentication Tests
    
    func testSEP10BasicAuthentication() async throws {
        // Create and fund test account
        accountKp = try await createAndFundAccount()
        
        // Get SEP-10 auth service
        let sep10 = try await anchor.sep10
        
        // Authenticate and get token
        let authToken = try await sep10.authenticate(
            userKeyPair: accountKp,
            memoId: nil,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        XCTAssertNotNil(authToken.jwt)
        XCTAssertFalse(authToken.jwt.isEmpty)
        print("SEP-10 authentication successful. Token: \(authToken.jwt.prefix(50))...")
    }
    
    func testSEP10WithMemo() async throws {
        // Create and fund test account
        accountKp = try await createAndFundAccount()
        
        // Get SEP-10 auth service
        let sep10 = try await anchor.sep10
        
        // Authenticate with memo
        let memoId: UInt64 = 123456789
        let authToken = try await sep10.authenticate(
            userKeyPair: accountKp,
            memoId: memoId,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        XCTAssertNotNil(authToken.jwt)
        XCTAssertFalse(authToken.jwt.isEmpty)
        print("SEP-10 authentication with memo successful")
    }
    
    // MARK: - SEP-12 KYC Tests
    
    func testSEP12CustomerRegistration() async throws {
        // Create and fund test account
        accountKp = try await createAndFundAccount()
        
        // Get SEP-10 auth token first
        let sep10 = try await anchor.sep10
        let authToken = try await sep10.authenticate(
            userKeyPair: accountKp,
            memoId: nil,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        // Get SEP-12 service
        let sep12 = try await anchor.sep12(authToken: authToken)
        
        // Add customer information
        let sep9Fields: [String: String] = [
            "first_name": TestConstants.Sep12TestData.firstName,
            "last_name": TestConstants.Sep12TestData.lastName,
            "email_address": TestConstants.Sep12TestData.emailAddress,
            "bank_number": TestConstants.Sep12TestData.bankNumber,
            "bank_account_number": TestConstants.Sep12TestData.bankAccountNumber
        ]
        
        let addResponse = try await sep12.add(sep9Info: sep9Fields)
        
        XCTAssertNotNil(addResponse.id)
        print("SEP-12 customer created with ID: \(addResponse.id)")
        
        // Get customer info
        let getResponse = try await sep12.get(id: addResponse.id)
        XCTAssertNotNil(getResponse.id)
        XCTAssertEqual(getResponse.id, addResponse.id)
        
        print("SEP-12 customer retrieved successfully")
    }
    
    // MARK: - SEP-6 Transfer Tests
    
    func testSEP6DepositFlow() async throws {
        // Create and fund test account
        accountKp = try await createAndFundAccount()
        
        // Add USDC trustline using TxBuilder
        let txBuilder = try await stellar.transaction(sourceAddress: accountKp)
        let tx = try txBuilder
            .addAssetSupport(asset: IssuedAssetId(code: TestConstants.Assets.usdcAssetCode, 
                                                 issuer: TestConstants.Assets.usdcIssuer))
            .build()
        
        stellar.sign(tx: tx, keyPair: accountKp)
        _ = try await stellar.submitTransaction(signedTransaction: tx)
        
        print("USDC trustline added")
        
        // Get SEP-10 auth token
        let sep10 = try await anchor.sep10
        let authToken = try await sep10.authenticate(
            userKeyPair: accountKp,
            memoId: nil,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        // Get SEP-12 service and add KYC info
        let sep12 = try await anchor.sep12(authToken: authToken)
        let sep9Fields: [String: String] = TestConstants.Sep12TestData.sep9Info
        let customerResponse = try await sep12.add(sep9Info: sep9Fields)
        
        print("Customer created with ID: \(customerResponse.id)")
        
        // Get SEP-6 service
        let sep6 = anchor.sep6
        
        // Initiate deposit
        let depositParams = Sep6DepositParams(
            assetCode: TestConstants.Assets.usdcAssetCode,
            account: accountKp.address,
            type: "SEPA"
        )
        let depositResponse = try await sep6.deposit(params: depositParams, authToken: authToken)
        
        switch depositResponse {
        case .depositSuccess(_, let id, _, _, _, _, _, _, _):
            XCTAssertNotNil(id)
            print("SEP-6 deposit initiated with ID: \(id ?? "unknown")")
            
            // Get transaction info if we have an ID
            if let transactionId = id {
                let transactionInfo = try await sep6.getTransactionBy(authToken: authToken, transactionId: transactionId)
                XCTAssertNotNil(transactionInfo)
                XCTAssertEqual(transactionInfo.id, transactionId)
                
                print("Transaction status: \(transactionInfo.transactionStatus.rawValue)")
            }
        case .missingKYC(let fields):
            print("KYC required. Fields: \(fields)")
        case .pending(let status, _, _):
            print("Deposit pending: \(status)")
        default:
            XCTFail("Unexpected deposit response")
        }
    }
    
    func testSEP6WithdrawFlow() async throws {
        // Create and fund test account
        accountKp = try await createAndFundAccount()
        
        // Get SEP-10 auth token
        let sep10 = try await anchor.sep10
        let authToken = try await sep10.authenticate(
            userKeyPair: accountKp,
            memoId: nil,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        // Get SEP-12 service and add KYC info
        let sep12 = try await anchor.sep12(authToken: authToken)
        let sep9Fields: [String: String] = TestConstants.Sep12TestData.sep9Info
        let customerResponse = try await sep12.add(sep9Info: sep9Fields)
        
        print("Customer created with ID: \(customerResponse.id)")
        
        // Get SEP-6 service
        let sep6 = anchor.sep6
        
        // Initiate withdrawal
        let withdrawParams = Sep6WithdrawParams(
            assetCode: TestConstants.Assets.usdcAssetCode,
            type: "bank_account",
            dest: "123",
            destExtra: "12345",
            account: accountKp.address
        )
        let withdrawResponse = try await sep6.withdraw(params: withdrawParams, authToken: authToken)
        
        switch withdrawResponse {
        case .withdrawSuccess(_, _, _, let id, _, _, _, _, _, _):
            XCTAssertNotNil(id)
            print("SEP-6 withdrawal initiated with ID: \(id ?? "unknown")")
        case .missingKYC(let fields):
            print("KYC required. Fields: \(fields)")
        case .pending(let status, _, _):
            print("Withdrawal pending: \(status)")
        default:
            XCTFail("Unexpected withdrawal response")
        }
    }
    
    // MARK: - SEP-24 Interactive Tests
    
    func testSEP24InteractiveDeposit() async throws {
        // Create and fund test account
        accountKp = try await createAndFundAccount()
        
        // Get SEP-10 auth token
        let sep10 = try await anchor.sep10
        let authToken = try await sep10.authenticate(
            userKeyPair: accountKp,
            memoId: nil,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        // Get SEP-24 service
        let sep24 = anchor.sep24
        
        // Initiate deposit
        let usdcAsset = try IssuedAssetId(code: TestConstants.Assets.usdcAssetCode, issuer: TestConstants.Assets.usdcIssuer)
        let depositResponse = try await sep24.deposit(
            assetId: usdcAsset,
            authToken: authToken,
            extraFields: ["account": accountKp.address]
        )
        
        XCTAssertNotNil(depositResponse.id)
        XCTAssertNotNil(depositResponse.url)
        print("SEP-24 deposit initiated:")
        print("  Transaction ID: \(depositResponse.id)")
        print("  Interactive URL: \(depositResponse.url)")
        
        // Get transaction info
        let transactionInfo = try await sep24.getTransactionBy(authToken: authToken, transactionId: depositResponse.id)
        
        XCTAssertNotNil(transactionInfo)
        XCTAssertEqual(transactionInfo.id, depositResponse.id)
        print("Transaction status: \(transactionInfo.transactionStatus.rawValue)")
    }
    
    func testSEP24InteractiveWithdraw() async throws {
        // Create and fund test account
        accountKp = try await createAndFundAccount()
        
        // Get SEP-10 auth token
        let sep10 = try await anchor.sep10
        let authToken = try await sep10.authenticate(
            userKeyPair: accountKp,
            memoId: nil,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        // Get SEP-24 service
        let sep24 = anchor.sep24
        
        // Initiate withdrawal
        let usdcAsset2 = try IssuedAssetId(code: TestConstants.Assets.usdcAssetCode, issuer: TestConstants.Assets.usdcIssuer)
        let withdrawResponse = try await sep24.withdraw(
            assetId: usdcAsset2,
            authToken: authToken,
            extraFields: ["account": accountKp.address]
        )
        
        XCTAssertNotNil(withdrawResponse.id)
        XCTAssertNotNil(withdrawResponse.url)
        print("SEP-24 withdrawal initiated:")
        print("  Transaction ID: \(withdrawResponse.id)")
        print("  Interactive URL: \(withdrawResponse.url)")
    }
    
    // MARK: - SEP-38 Quote Tests
    
    func testSEP38GetPrices() async throws {
        // Get SEP-38 quote service (no auth required for prices)
        let sep38 = try await anchor.sep38(authToken: nil)
        
        // Get prices for USDC
        let prices = try await sep38.prices(
            sellAsset: "stellar:USDC:\(TestConstants.Assets.usdcIssuer)",
            sellAmount: "100",
            sellDeliveryMethod: nil,
            buyDeliveryMethod: nil,
            countryCode: nil
        )
        
        XCTAssertNotNil(prices.buyAssets)
        XCTAssertGreaterThan(prices.buyAssets.count, 0)
        
        print("SEP-38 prices retrieved:")
        for asset in prices.buyAssets {
            print("  Asset: \(asset.asset)")
            print("  Price: \(asset.price)")
            print("  Decimals: \(asset.decimals)")
        }
    }
    
    func testSEP38CreateQuote() async throws {
        // Create and fund test account
        accountKp = try await createAndFundAccount()
        
        // Get SEP-10 auth token
        let sep10 = try await anchor.sep10
        let authToken = try await sep10.authenticate(
            userKeyPair: accountKp,
            memoId: nil,
            clientDomain: nil,
            clientDomainSigner: nil
        )
        
        // Get SEP-38 quote service
        let sep38 = try await anchor.sep38(authToken: authToken)
        
        // Create a quote
        let quoteResponse = try await sep38.requestQuote(
            context: "sep6",
            sellAsset: "stellar:USDC:\(TestConstants.Assets.usdcIssuer)",
            buyAsset: "iso4217:USD",
            sellAmount: "10"
        )
        
        XCTAssertNotNil(quoteResponse.id)
        XCTAssertNotNil(quoteResponse.expiresAt)
        XCTAssertEqual(quoteResponse.sellAsset, "stellar:USDC:\(TestConstants.Assets.usdcIssuer)")
        XCTAssertEqual(quoteResponse.buyAsset, "iso4217:USD")
        
        print("SEP-38 quote created:")
        print("  Quote ID: \(quoteResponse.id)")
        print("  Sell: \(quoteResponse.sellAmount) \(quoteResponse.sellAsset)")
        print("  Buy: \(quoteResponse.buyAmount) \(quoteResponse.buyAsset)")
        print("  Price: \(quoteResponse.price)")
        print("  Expires: \(quoteResponse.expiresAt)")
        
        // Get the quote by ID
        let retrievedQuote = try await sep38.getQuote(quoteId: quoteResponse.id)
        
        XCTAssertEqual(retrievedQuote.id, quoteResponse.id)
        XCTAssertEqual(retrievedQuote.sellAsset, quoteResponse.sellAsset)
        XCTAssertEqual(retrievedQuote.buyAsset, quoteResponse.buyAsset)
        
        print("Quote retrieved successfully by ID")
    }
    
    /// Create and fund a test account
    func createAndFundAccount() async throws -> SigningKeyPair {
        let accountKp = stellar.account.createKeyPair()
        
        // Fund account using friendbot
        try await fundAccount(accountId: accountKp.address)
        
        // Verify account exists
        let exists = try await stellar.account.accountExists(accountAddress: accountKp.address)
        if (!exists) {
            throw IntegrationTestError.fundingFailed(accountKp.address)
        }
        
        return accountKp
    }
    
    /// Fund an account using Stellar testnet friendbot
    func fundAccount(accountId: String) async throws {
        try await stellar.fundTestNetAccount(address: accountId)
        
        // Wait a bit for the transaction to be included
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
}
