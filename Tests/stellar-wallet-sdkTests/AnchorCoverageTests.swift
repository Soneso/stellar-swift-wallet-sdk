//
//  AnchorCoverageTests.swift
//
//
//  Offline coverage for anchor / quote / customer error branches and
//  response-parsing edge cases that are not exercised by the happy-path
//  suites (InteractiveFlowTest / QuotesTest / KYCTest).
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class AnchorCovUtils {

    // Domain that resolves to a stellar.toml exposing SEP-24, SEP-10, KYC and quote services.
    static let fullAnchorDomain = "full.anchorcov.com"
    // Domain whose stellar.toml only exposes a signing key (no services at all).
    static let emptyAnchorDomain = "empty.anchorcov.com"

    static let apiHost = "api.anchorcov.org"
    static let webAuthEndpoint = "https://\(apiHost)/auth"

    static let interactiveHost = "sep24.anchorcov.org"
    static let quoteHost = "sep38.anchorcov.org"
    static let kycHost = "sep12.anchorcov.org"

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

final class AnchorCoverageTests: XCTestCase {

    let wallet = Wallet.testNet
    var fullTomlMock: TomlResponseMock!
    var emptyTomlMock: TomlResponseMock!
    var challengeMock: WebAuthChallengeResponseMock!
    var sendChallengeMock: WebAuthSendChallengeResponseMock!
    var interactiveInfoMock: AnchorCovInteractiveInfoMock!
    var interactiveInitMock: AnchorCovInteractiveInitMock!
    var interactiveTxMock: AnchorCovInteractiveTxMock!
    var interactiveTxsMock: AnchorCovInteractiveTxsMock!
    var quoteMock: AnchorCovQuoteMock!
    var customerMock: AnchorCovCustomerMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        fullTomlMock = TomlResponseMock(host: AnchorCovUtils.fullAnchorDomain,
                                        serverSigningKey: AnchorCovUtils.serverAccountId,
                                        authServer: AnchorCovUtils.webAuthEndpoint,
                                        sep24TransferServer: AnchorCovUtils.interactiveServer,
                                        anchorQuoteServer: AnchorCovUtils.quoteServer,
                                        kycServer: AnchorCovUtils.kycServer)

        // No service URLs, only a signing key -> all services unavailable.
        emptyTomlMock = TomlResponseMock(host: AnchorCovUtils.emptyAnchorDomain,
                                         serverSigningKey: AnchorCovUtils.serverAccountId)

        challengeMock = WebAuthChallengeResponseMock(host: AnchorCovUtils.apiHost,
                                                     serverKeyPair: AnchorCovUtils.serverKeypair,
                                                     homeDomain: AnchorCovUtils.fullAnchorDomain)
        sendChallengeMock = WebAuthSendChallengeResponseMock(host: AnchorCovUtils.apiHost)

        interactiveInfoMock = AnchorCovInteractiveInfoMock(host: AnchorCovUtils.interactiveHost)
        interactiveInitMock = AnchorCovInteractiveInitMock(host: AnchorCovUtils.interactiveHost)
        interactiveTxMock = AnchorCovInteractiveTxMock(host: AnchorCovUtils.interactiveHost)
        interactiveTxsMock = AnchorCovInteractiveTxsMock(host: AnchorCovUtils.interactiveHost)
        quoteMock = AnchorCovQuoteMock(host: AnchorCovUtils.quoteHost)
        customerMock = AnchorCovCustomerMock(host: AnchorCovUtils.kycHost)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - helpers

    private func fullAnchor() -> Anchor {
        return wallet.anchor(homeDomain: AnchorCovUtils.fullAnchorDomain)
    }

    private func authToken(for anchor: Anchor) async throws -> AuthToken {
        let authKey = try SigningKeyPair(secretKey: AnchorCovUtils.userSecretSeed)
        return try await anchor.sep10.authenticate(userKeyPair: authKey)
    }

    // MARK: - Anchor.swift service-discovery error branches

    func testSep10NotSupportedWhenNoWebAuth() async throws {
        let anchor = wallet.anchor(homeDomain: AnchorCovUtils.emptyAnchorDomain)
        do {
            _ = try await anchor.sep10
            XCTFail("expected AnchorAuthError.notSupported")
        } catch AnchorAuthError.notSupported {
            // expected
        }
    }

    func testSep38QuoteServerNotFound() async throws {
        let anchor = wallet.anchor(homeDomain: AnchorCovUtils.emptyAnchorDomain)
        do {
            _ = try await anchor.sep38(authToken: nil)
            XCTFail("expected AnchorError.quoteServerNotFound")
        } catch AnchorError.quoteServerNotFound {
            // expected
        }
    }

    func testSep12KycServerNotFound() async throws {
        let anchor = wallet.anchor(homeDomain: AnchorCovUtils.emptyAnchorDomain)
        let token = try await fullAnchor().sep10.authenticate(
            userKeyPair: try SigningKeyPair(secretKey: AnchorCovUtils.userSecretSeed))
        do {
            _ = try await anchor.sep12(authToken: token)
            XCTFail("expected AnchorError.kycServerNotFound")
        } catch AnchorError.kycServerNotFound {
            // expected
        }
    }

    func testTomlInfoServicesAndHasAuth() async throws {
        let info = try await fullAnchor().info
        XCTAssertTrue(info.hasAuth)
        let services = info.services
        XCTAssertNotNil(services.sep10)
        XCTAssertEqual(AnchorCovUtils.webAuthEndpoint, services.sep10?.webAuthEndpoint)
        XCTAssertEqual(AnchorCovUtils.serverAccountId, services.sep10?.signingKey)
        XCTAssertNotNil(services.sep24)
        XCTAssertTrue(services.sep24?.hasAuth ?? false)
        XCTAssertEqual(AnchorCovUtils.interactiveServer, services.sep24?.transferServerSep24)
        XCTAssertNotNil(services.sep12)
        XCTAssertEqual(AnchorCovUtils.kycServer, services.sep12?.kycServer)
        // sep6 transfer server and sep31 direct payment server are not configured here.
        XCTAssertNil(services.sep6)
        XCTAssertNil(services.sep31)

        // currencies parsed from [[CURRENCIES]] entries with assetId resolution.
        guard let currencies = info.currencies else {
            XCTFail("currencies expected")
            return
        }
        XCTAssertEqual(2, currencies.count)
        let usdc = currencies.first { $0.code == "USDC" }
        XCTAssertNotNil(usdc)
        XCTAssertEqual(2, usdc?.displayDecimals)
        let usdcAssetId = try usdc!.assetId
        XCTAssertTrue(usdcAssetId is IssuedAssetId)
        XCTAssertEqual("USDC", (usdcAssetId as! IssuedAssetId).code)
    }

    func testEmptyTomlServicesAllNil() async throws {
        let info = try await wallet.anchor(homeDomain: AnchorCovUtils.emptyAnchorDomain).info
        XCTAssertFalse(info.hasAuth)
        let services = info.services
        XCTAssertNil(services.sep6)
        XCTAssertNil(services.sep10)
        XCTAssertNil(services.sep12)
        XCTAssertNil(services.sep24)
        XCTAssertNil(services.sep31)
    }

    // MARK: - Sep24.swift validation / not-supported branches

    func testSep24DepositInteractiveFlowNotSupported() async throws {
        let anchor = wallet.anchor(homeDomain: AnchorCovUtils.emptyAnchorDomain)
        let token = try await authToken(for: fullAnchor())
        do {
            _ = try await anchor.sep24.deposit(assetId: AnchorCovUtils.usdcAsset, authToken: token)
            XCTFail("expected interactiveFlowNotSupported")
        } catch AnchorError.interactiveFlowNotSupported {
            // expected
        }
    }

    func testSep24WithdrawInteractiveFlowNotSupported() async throws {
        let anchor = wallet.anchor(homeDomain: AnchorCovUtils.emptyAnchorDomain)
        let token = try await authToken(for: fullAnchor())
        do {
            _ = try await anchor.sep24.withdraw(assetId: AnchorCovUtils.usdcAsset, authToken: token)
            XCTFail("expected interactiveFlowNotSupported")
        } catch AnchorError.interactiveFlowNotSupported {
            // expected
        }
    }

    func testSep24DepositAssetNotAccepted() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        // EUR is not present in the interactive info mock -> not accepted for deposit.
        let eur = try IssuedAssetId(code: "EUR", issuer: AnchorCovUtils.usdcAsset.issuer)
        do {
            _ = try await anchor.sep24.deposit(assetId: eur, authToken: token)
            XCTFail("expected assetNotAcceptedForDeposit")
        } catch InteractiveFlowError.assetNotAcceptedForDeposit(let assetId) {
            XCTAssertEqual("EUR", (assetId as? IssuedAssetId)?.code)
        }
    }

    func testSep24DepositAssetNotEnabled() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        // BTC is present but disabled for deposit in the interactive info mock.
        let btc = try IssuedAssetId(code: "BTC", issuer: AnchorCovUtils.usdcAsset.issuer)
        do {
            _ = try await anchor.sep24.deposit(assetId: btc, authToken: token)
            XCTFail("expected assetNotEnabledForDeposit")
        } catch InteractiveFlowError.assetNotEnabledForDeposit(let assetId) {
            XCTAssertEqual("BTC", (assetId as? IssuedAssetId)?.code)
        }
    }

    func testSep24WithdrawAssetNotAccepted() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        let eur = try IssuedAssetId(code: "EUR", issuer: AnchorCovUtils.usdcAsset.issuer)
        do {
            _ = try await anchor.sep24.withdraw(assetId: eur, authToken: token)
            XCTFail("expected assetNotAcceptedForWithdrawal")
        } catch InteractiveFlowError.assetNotAcceptedForWithdrawal(let assetId) {
            XCTAssertEqual("EUR", (assetId as? IssuedAssetId)?.code)
        }
    }

    func testSep24WithdrawAssetNotEnabled() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        // BTC is present but disabled for withdrawal in the interactive info mock.
        let btc = try IssuedAssetId(code: "BTC", issuer: AnchorCovUtils.usdcAsset.issuer)
        do {
            _ = try await anchor.sep24.withdraw(assetId: btc, authToken: token)
            XCTFail("expected assetNotEnabledForWithdrawal")
        } catch InteractiveFlowError.assetNotEnabledForWithdrawal(let assetId) {
            XCTAssertEqual("BTC", (assetId as? IssuedAssetId)?.code)
        }
    }

    func testSep24GetTransactionByRequiresAnId() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token)
            XCTFail("expected ValidationError.invalidArgument")
        } catch ValidationError.invalidArgument(let message) {
            XCTAssertTrue(message.contains("transactionId"))
        }
    }

    func testSep24DepositServerError() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        // USDC deposit is enabled in info but the init endpoint returns a 400 anchor error.
        do {
            _ = try await anchor.sep24.deposit(assetId: AnchorCovUtils.usdcAsset, authToken: token)
            XCTFail("expected InteractiveServiceError.anchorError")
        } catch InteractiveServiceError.anchorError(let message) {
            XCTAssertEqual("deposit temporarily disabled", message)
        }
    }

    func testSep24WithdrawServerNotFound() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        interactiveInitMock.withdrawStatusCode = 404
        do {
            _ = try await anchor.sep24.withdraw(assetId: AnchorCovUtils.usdcAsset, authToken: token)
            XCTFail("expected InteractiveServiceError.notFound")
        } catch InteractiveServiceError.notFound {
            // expected
        }
    }

    // MARK: - InteractiveFlowTransaction.fromTx parsing edge cases

    func testGetTransactionInvalidStatus() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "bad-status")
            XCTFail("expected invalidAnchorResponse for invalid status")
        } catch AnchorError.invalidAnchorResponse(let message) {
            XCTAssertTrue(message.contains("status"))
        }
    }

    func testGetTransactionInvalidKind() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "bad-kind")
            XCTFail("expected invalidAnchorResponse for invalid kind")
        } catch AnchorError.invalidAnchorResponse(let message) {
            XCTAssertTrue(message.contains("kind"))
        }
    }

    func testGetTransactionUnsupportedKind() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        // kind "deposit-exchange" is a valid TransactionKind but unsupported by fromTx (default branch).
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "exchange-kind")
            XCTFail("expected invalidAnchorResponse for unsupported kind")
        } catch AnchorError.invalidAnchorResponse(let message) {
            XCTAssertTrue(message.contains("kind"))
        }
    }

    func testGetIncompleteDepositTransaction() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "incomplete-deposit")
        XCTAssertEqual("incomplete-deposit", tx.id)
        XCTAssertEqual(.incomplete, tx.transactionStatus)
        guard let incomplete = tx as? IncompleteDepositTransaction else {
            XCTFail("expected IncompleteDepositTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual("GDESTINATIONACCOUNT", incomplete.to)
        XCTAssertEqual("https://anchor.example/more", incomplete.moreInfoUrl)
    }

    func testGetIncompleteWithdrawalTransaction() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "incomplete-withdrawal")
        XCTAssertEqual(.incomplete, tx.transactionStatus)
        guard let incomplete = tx as? IncompleteWithdrawalTransaction else {
            XCTFail("expected IncompleteWithdrawalTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual("GSOURCEACCOUNT", incomplete.from)
    }

    func testGetErrorDepositTransaction() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "error-deposit")
        XCTAssertEqual(.error, tx.transactionStatus)
        guard let errorTx = tx as? ErrorTransaction else {
            XCTFail("expected ErrorTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual(.deposit, errorTx.kind)
        XCTAssertEqual("something went wrong", errorTx.message)
        XCTAssertEqual(true, errorTx.refunded)
        XCTAssertEqual("18.34", errorTx.amountIn)
        XCTAssertEqual("GDEPOSITTO", errorTx.to)
        XCTAssertEqual("memodeposit", errorTx.depositMemo)
        XCTAssertEqual("text", errorTx.depositMemoType)
        XCTAssertEqual("balance-id-xyz", errorTx.claimableBalanceId)
    }

    func testGetErrorWithdrawalTransaction() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "error-withdrawal")
        guard let errorTx = tx as? ErrorTransaction else {
            XCTFail("expected ErrorTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual(.withdrawal, errorTx.kind)
        XCTAssertEqual("GANCHORACCOUNT", errorTx.withdrawAnchorAccount)
        XCTAssertEqual("777", errorTx.withdrawalMemo)
        XCTAssertEqual("id", errorTx.withdrawalMemoType)
    }

    func testGetDepositTransactionWithRefunds() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "deposit-complete")
        guard let deposit = tx as? DepositTransaction else {
            XCTFail("expected DepositTransaction, got \(type(of: tx))")
            return
        }
        XCTAssertEqual(.completed, deposit.transactionStatus)
        XCTAssertEqual("GFROMADDR", deposit.from)
        XCTAssertEqual("GTOADDR", deposit.to)
        XCTAssertEqual("dmemo", deposit.depositMemo)
        XCTAssertEqual("text", deposit.depositMemoType)
        XCTAssertEqual(true, deposit.kycVerified)
        XCTAssertEqual("stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN", deposit.amountInAsset)
        guard let refunds = deposit.refunds else {
            XCTFail("expected refunds")
            return
        }
        XCTAssertEqual("10", refunds.amountRefunded)
        XCTAssertEqual("5", refunds.amountFee)
        XCTAssertEqual(2, refunds.payments.count)
        XCTAssertEqual("p1", refunds.payments[0].id)
        XCTAssertEqual("stellar", refunds.payments[0].idType)
        XCTAssertEqual("external", refunds.payments[1].idType)
    }

    func testGetDepositTransactionWithoutRefunds() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        let tx = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "deposit-norefund")
        guard let deposit = tx as? DepositTransaction else {
            XCTFail("expected DepositTransaction, got \(type(of: tx))")
            return
        }
        // refunds object absent -> nil (Refunds.fromSep24Refund returns nil).
        XCTAssertNil(deposit.refunds)
        XCTAssertNil(deposit.amountInAsset)
        XCTAssertNil(deposit.kycVerified)
        XCTAssertEqual(.pendingAnchor, deposit.transactionStatus)
    }

    func testGetTransactionMalformedJson() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        do {
            _ = try await anchor.sep24.getTransactionBy(authToken: token, transactionId: "malformed")
            XCTFail("expected parsingResponseFailed")
        } catch InteractiveServiceError.parsingResponseFailed {
            // expected
        }
    }

    func testGetTransactionsForAssetNotSupported() async throws {
        let anchor = wallet.anchor(homeDomain: AnchorCovUtils.emptyAnchorDomain)
        let token = try await authToken(for: fullAnchor())
        do {
            _ = try await anchor.sep24.getTransactionsForAsset(authToken: token, asset: AnchorCovUtils.usdcAsset)
            XCTFail("expected interactiveFlowNotSupported")
        } catch AnchorError.interactiveFlowNotSupported {
            // expected
        }
    }

    func testGetTransactionsForAssetMixedKinds() async throws {
        let anchor = fullAnchor()
        let token = try await authToken(for: anchor)
        let txs = try await anchor.sep24.getTransactionsForAsset(authToken: token, asset: AnchorCovUtils.usdcAsset)
        XCTAssertEqual(2, txs.count)
        XCTAssertTrue(txs[0] is DepositTransaction)
        XCTAssertTrue(txs[1] is WithdrawalTransaction)
    }

    // MARK: - Sep24Info parsing edge cases

    func testSep24InfoDefaultsWhenFeeAndFeaturesMissing() async throws {
        let anchor = fullAnchor()
        interactiveInfoMock.useMinimalInfo = true
        let info = try await anchor.sep24.info
        // No fee block -> Sep24ServiceFee disabled default.
        XCTAssertFalse(info.fee.enabled)
        XCTAssertFalse(info.fee.authenticationRequired)
        // No features block -> features nil.
        XCTAssertNil(info.features)
        // Empty deposit/withdraw maps.
        XCTAssertTrue(info.deposit.isEmpty)
        XCTAssertTrue(info.withdraw.isEmpty)
    }

    func testSep24InfoMalformedJson() async throws {
        let anchor = fullAnchor()
        interactiveInfoMock.malformed = true
        do {
            _ = try await anchor.sep24.info
            XCTFail("expected parsingResponseFailed")
        } catch InteractiveServiceError.parsingResponseFailed {
            // expected
        }
    }

    func testSep24InfoServiceAssetLookup() async throws {
        let anchor = fullAnchor()
        let info = try await anchor.sep24.info
        XCTAssertNotNil(info.depositServiceAsset(assetId: AnchorCovUtils.usdcAsset))
        XCTAssertNotNil(info.withdrawServiceAsset(assetId: AnchorCovUtils.usdcAsset))
        let native = NativeAssetId()
        XCTAssertNotNil(info.depositServiceAsset(assetId: native))
        let unknown = try IssuedAssetId(code: "EUR", issuer: AnchorCovUtils.usdcAsset.issuer)
        XCTAssertNil(info.depositServiceAsset(assetId: unknown))
    }

    // MARK: - Sep38.swift validation and error branches

    func testSep38PriceRequiresExactlyOneAmount() async throws {
        let sep38 = try await fullAnchor().sep38(authToken: nil)
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
        let token = try await authToken(for: fullAnchor())
        let sep38 = try await fullAnchor().sep38(authToken: token)
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
        let sep38 = try await fullAnchor().sep38(authToken: nil)
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
        let sep38 = try await fullAnchor().sep38(authToken: nil)
        do {
            _ = try await sep38.getQuote(quoteId: "abc")
            XCTFail("expected invalidArgument for missing auth")
        } catch ValidationError.invalidArgument(let message) {
            XCTAssertTrue(message.contains("authentication"))
        }
    }

    func testSep38InfoPermissionDenied() async throws {
        let sep38 = try await fullAnchor().sep38(authToken: nil)
        quoteMock.infoStatusCode = 403
        do {
            _ = try await sep38.info
            XCTFail("expected permissionDenied")
        } catch QuoteServiceError.permissionDenied {
            // expected
        }
    }

    func testSep38InfoMalformedJson() async throws {
        let sep38 = try await fullAnchor().sep38(authToken: nil)
        quoteMock.infoMalformed = true
        do {
            _ = try await sep38.info
            XCTFail("expected parsingResponseFailed")
        } catch QuoteServiceError.parsingResponseFailed {
            // expected
        }
    }

    func testSep38PriceBadRequest() async throws {
        let sep38 = try await fullAnchor().sep38(authToken: nil)
        quoteMock.priceStatusCode = 400
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
        let token = try await authToken(for: fullAnchor())
        let sep38 = try await fullAnchor().sep38(authToken: token)
        quoteMock.quoteStatusCode = 404
        do {
            _ = try await sep38.getQuote(quoteId: "missing-quote")
            XCTFail("expected notFound")
        } catch QuoteServiceError.notFound {
            // expected
        }
    }

    // MARK: - QuotesResponse parsing optional-field coverage

    func testSep38InfoOptionalFieldsAbsent() async throws {
        let sep38 = try await fullAnchor().sep38(authToken: nil)
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
        let sep38 = try await fullAnchor().sep38(authToken: nil)
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
        customerMock.putStatusCode = 400
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
}

// MARK: - Namespaced mocks

class AnchorCovInteractiveInfoMock: ResponsesMock {
    var host: String
    var malformed = false
    var useMinimalInfo = false

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            if self.malformed {
                mock.statusCode = 200
                return "{ this is not json "
            }
            mock.statusCode = 200
            return self.useMinimalInfo ? self.minimalInfo : self.fullInfo
        }
        return RequestMock(host: host,
                           path: "/info",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    // USDC enabled for deposit and withdraw, BTC present but disabled, native enabled.
    let fullInfo = """
    {
      "deposit": {
        "USDC": { "enabled": true, "fee_fixed": 5, "fee_percent": 1, "min_amount": 0.1, "max_amount": 1000 },
        "BTC": { "enabled": false },
        "native": { "enabled": true }
      },
      "withdraw": {
        "USDC": { "enabled": true, "fee_minimum": 5, "fee_percent": 0.5 },
        "BTC": { "enabled": false },
        "native": { "enabled": true }
      },
      "fee": { "enabled": false },
      "features": { "account_creation": true, "claimable_balances": false }
    }
    """

    let minimalInfo = """
    {
      "deposit": {},
      "withdraw": {}
    }
    """
}

class AnchorCovInteractiveInitMock: ResponsesMock {
    var host: String
    // deposit always returns a 400 anchor error for coverage of the failure mapping.
    var withdrawStatusCode = 200

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            if request.url?.path.contains("withdraw") ?? false {
                mock.statusCode = self.withdrawStatusCode
                if self.withdrawStatusCode == 404 {
                    return "{\"error\": \"not found\"}"
                }
                return "{ \"type\": \"completed\", \"url\": \"https://anchor.example/flow\", \"id\": \"wid\" }"
            }
            // deposit
            mock.statusCode = 400
            return "{\"error\": \"deposit temporarily disabled\"}"
        }
        return RequestMock(host: host,
                           path: "/transactions/*/interactive",
                           httpMethod: "POST",
                           mockHandler: handler)
    }
}

class AnchorCovInteractiveTxMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            let id = mock.variables["id"] ?? ""
            switch id {
            case "bad-status":
                mock.statusCode = 200
                return self.tx(id: id, kind: "deposit", status: "totally_invalid")
            case "bad-kind":
                mock.statusCode = 200
                return self.tx(id: id, kind: "nonsense", status: "completed")
            case "exchange-kind":
                mock.statusCode = 200
                return self.tx(id: id, kind: "deposit-exchange", status: "completed")
            case "incomplete-deposit":
                mock.statusCode = 200
                return self.incompleteDeposit
            case "incomplete-withdrawal":
                mock.statusCode = 200
                return self.incompleteWithdrawal
            case "error-deposit":
                mock.statusCode = 200
                return self.errorDeposit
            case "error-withdrawal":
                mock.statusCode = 200
                return self.errorWithdrawal
            case "deposit-complete":
                mock.statusCode = 200
                return self.depositComplete
            case "deposit-norefund":
                mock.statusCode = 200
                return self.depositNoRefund
            case "malformed":
                mock.statusCode = 200
                return "{ not valid json"
            default:
                mock.statusCode = 404
                return "{\"error\": \"not found\"}"
            }
        }
        return RequestMock(host: host,
                           path: "/transaction",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    private func tx(id: String, kind: String, status: String) -> String {
        return """
        { "transaction": { "id": "\(id)", "kind": "\(kind)", "status": "\(status)", "started_at": "2017-03-20T17:00:02Z" } }
        """
    }

    let incompleteDeposit = """
    { "transaction": { "id": "incomplete-deposit", "kind": "deposit", "status": "incomplete",
      "started_at": "2017-03-20T17:00:02Z", "more_info_url": "https://anchor.example/more", "to": "GDESTINATIONACCOUNT" } }
    """

    let incompleteWithdrawal = """
    { "transaction": { "id": "incomplete-withdrawal", "kind": "withdrawal", "status": "incomplete",
      "started_at": "2017-03-20T17:00:02Z", "from": "GSOURCEACCOUNT" } }
    """

    let errorDeposit = """
    { "transaction": { "id": "error-deposit", "kind": "deposit", "status": "error",
      "started_at": "2017-03-20T17:00:02Z", "message": "something went wrong", "refunded": true,
      "amount_in": "18.34", "amount_out": "18.24", "amount_fee": "0.1",
      "to": "GDEPOSITTO", "deposit_memo": "memodeposit", "deposit_memo_type": "text",
      "claimable_balance_id": "balance-id-xyz" } }
    """

    let errorWithdrawal = """
    { "transaction": { "id": "error-withdrawal", "kind": "withdrawal", "status": "error",
      "started_at": "2017-03-20T17:00:02Z", "message": "withdraw failed",
      "withdraw_anchor_account": "GANCHORACCOUNT", "withdraw_memo": "777", "withdraw_memo_type": "id" } }
    """

    let depositComplete = """
    { "transaction": { "id": "deposit-complete", "kind": "deposit", "status": "completed",
      "started_at": "2017-03-20T17:00:02Z", "completed_at": "2017-03-20T17:09:58Z",
      "kyc_verified": true, "from": "GFROMADDR", "to": "GTOADDR",
      "deposit_memo": "dmemo", "deposit_memo_type": "text",
      "amount_in": "18.34", "amount_in_asset": "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN",
      "amount_out": "18.24", "amount_fee": "0.1",
      "refunds": { "amount_refunded": "10", "amount_fee": "5", "payments": [
        { "id": "p1", "id_type": "stellar", "amount": "6", "fee": "3" },
        { "id": "p2", "id_type": "external", "amount": "4", "fee": "2" }
      ] } } }
    """

    let depositNoRefund = """
    { "transaction": { "id": "deposit-norefund", "kind": "deposit", "status": "pending_anchor",
      "started_at": "2017-03-20T17:00:02Z", "amount_in": "18.34", "amount_out": "18.24", "amount_fee": "0.1" } }
    """
}

class AnchorCovInteractiveTxsMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.success
        }
        return RequestMock(host: host,
                           path: "/transactions",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    let success = """
    { "transactions": [
      { "id": "d1", "kind": "deposit", "status": "completed", "started_at": "2017-03-20T17:00:02Z",
        "amount_in": "10", "amount_out": "9", "amount_fee": "1" },
      { "id": "w1", "kind": "withdrawal", "status": "pending_anchor", "started_at": "2017-03-20T17:00:02Z",
        "amount_in": "10", "amount_out": "9", "amount_fee": "1", "from": "GFROM" }
    ] }
    """
}

class AnchorCovQuoteMock: ResponsesMock {
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

/// Registers BOTH the GET and PUT handlers for /kyc/customer. ResponsesMock only
/// registers a single RequestMock per instance, so the PUT handler is registered
/// through a nested helper mock created from the same host.
class AnchorCovCustomerMock: ResponsesMock {
    var host: String
    private let putMock: AnchorCovCustomerPutMock

    var putStatusCode: Int {
        get { putMock.putStatusCode }
        set { putMock.putStatusCode = newValue }
    }

    init(host: String) {
        self.host = host
        self.putMock = AnchorCovCustomerPutMock(host: host)
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

class AnchorCovCustomerPutMock: ResponsesMock {
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
