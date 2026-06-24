//
//  Sep6CoverageTests.swift
//
//
//  Offline coverage for SEP-6 error / edge branches in anchor/Sep6.swift and the
//  SEP-6 response models (Sep6Info, Sep6Transaction, Sep6TransferResponse).
//
//  TransferTest covers the happy paths. This suite targets the branches that are
//  not exercised there: 4xx anchor errors, malformed / unparsable responses,
//  customer-info-needed / customer-info-status across every transfer endpoint,
//  the authentication_required failure, the fee endpoint, transfer-service
//  resolution failure, argument validation, and the response-model variants
//  (withdraw extra_info, deposit min/max/extra_info, charged fee details,
//  refund payments, empty /info, withdraw types with null fields, etc.).
//

import XCTest
import Foundation
import stellarsdk
@testable import stellar_wallet_sdk


final class Sep6CovUtils {

    // Distinct hosts so this suite never shares mock registrations with TransferTest.
    static let anchorHost = "place.sep6cov.com"
    static let anchorWebAuthHost = "api.sep6cov.org"
    static let webAuthEndpoint = "https://\(anchorWebAuthHost)/auth"
    static let anchorTransferHost = "sep6.sep6cov.org"

    // A second anchor whose stellar.toml advertises no TRANSFER_SERVER, used to
    // exercise the AnchorError.depositAndWithdrawalAPINotSupported branch.
    static let noSep6Host = "nosep6.sep6cov.com"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userAccountId = "GB4L7JUU5DENUXYH3ANTLVYQL66KQLDDJTN5SF7MWEDGWSGUA375V44V"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"

    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)
}

final class Sep6CoverageTests: XCTestCase {

    let wallet = Wallet.testNet

    var anchorTomlServerMock: TomlResponseMock!
    var noSep6TomlServerMock: TomlResponseMock!
    var challengeServerMock: WebAuthChallengeResponseMock!
    var sendChallengeServerMock: WebAuthSendChallengeResponseMock!

    var infoServerMock: Sep6CovInfoResponseMock!
    var depositServerMock: Sep6CovDepositResponseMock!
    var depositExchangeServerMock: Sep6CovDepositExchangeResponseMock!
    var withdrawServerMock: Sep6CovWithdrawResponseMock!
    var withdrawExchangeServerMock: Sep6CovWithdrawExchangeResponseMock!
    var feeServerMock: Sep6CovFeeResponseMock!
    var singleTxServerMock: Sep6CovSingleTxResponseMock!
    var multipleTxServerMock: Sep6CovMultipleTxResponseMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        anchorTomlServerMock = TomlResponseMock(host: Sep6CovUtils.anchorHost,
                                                serverSigningKey: Sep6CovUtils.serverAccountId,
                                                authServer: Sep6CovUtils.webAuthEndpoint,
                                                sep6TransferServer: "https://\(Sep6CovUtils.anchorTransferHost)")

        // No TRANSFER_SERVER -> services.sep6 == nil at the SDK layer.
        noSep6TomlServerMock = TomlResponseMock(host: Sep6CovUtils.noSep6Host,
                                                serverSigningKey: Sep6CovUtils.serverAccountId,
                                                authServer: Sep6CovUtils.webAuthEndpoint)

        challengeServerMock = WebAuthChallengeResponseMock(host: Sep6CovUtils.anchorWebAuthHost,
                                                           serverKeyPair: Sep6CovUtils.serverKeypair,
                                                           homeDomain: Sep6CovUtils.anchorHost)

        sendChallengeServerMock = WebAuthSendChallengeResponseMock(host: Sep6CovUtils.anchorWebAuthHost)

        infoServerMock = Sep6CovInfoResponseMock(host: Sep6CovUtils.anchorTransferHost)
        depositServerMock = Sep6CovDepositResponseMock(host: Sep6CovUtils.anchorTransferHost)
        depositExchangeServerMock = Sep6CovDepositExchangeResponseMock(host: Sep6CovUtils.anchorTransferHost)
        withdrawServerMock = Sep6CovWithdrawResponseMock(host: Sep6CovUtils.anchorTransferHost)
        withdrawExchangeServerMock = Sep6CovWithdrawExchangeResponseMock(host: Sep6CovUtils.anchorTransferHost)
        feeServerMock = Sep6CovFeeResponseMock(host: Sep6CovUtils.anchorTransferHost)
        singleTxServerMock = Sep6CovSingleTxResponseMock(host: Sep6CovUtils.anchorTransferHost)
        multipleTxServerMock = Sep6CovMultipleTxResponseMock(host: Sep6CovUtils.anchorTransferHost)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - helpers

    private func authToken() async throws -> AuthToken {
        let anchor = wallet.anchor(homeDomain: Sep6CovUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: Sep6CovUtils.userSecretSeed)
        let token = try await anchor.sep10.authenticate(userKeyPair: authKey)
        XCTAssertEqual(AuthTestUtils.jwtSuccess, token.jwt)
        return token
    }

    private func anchor() -> Anchor {
        return wallet.anchor(homeDomain: Sep6CovUtils.anchorHost)
    }

    /// Asserts the thrown error is a TransferServerError.anchorError carrying the given message.
    private func assertAnchorError(_ error: Error, expectedMessage: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let tse = error as? TransferServerError else {
            XCTFail("expected TransferServerError, got \(error)", file: file, line: line)
            return
        }
        switch tse {
        case .anchorError(let message):
            XCTAssertEqual(expectedMessage, message, file: file, line: line)
        default:
            XCTFail("expected .anchorError, got \(tse)", file: file, line: line)
        }
    }

    private func assertParsingFailed(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        guard let tse = error as? TransferServerError else {
            XCTFail("expected TransferServerError, got \(error)", file: file, line: line)
            return
        }
        switch tse {
        case .parsingResponseFailed:
            break
        default:
            XCTFail("expected .parsingResponseFailed, got \(tse)", file: file, line: line)
        }
    }

    // MARK: - transfer service resolution

    func testTransferServiceNotSupported() async throws {
        let anchor = wallet.anchor(homeDomain: Sep6CovUtils.noSep6Host)
        do {
            _ = try await anchor.sep6.info()
            XCTFail("expected depositAndWithdrawalAPINotSupported")
        } catch let error as AnchorError {
            switch error {
            case .depositAndWithdrawalAPINotSupported:
                break
            default:
                XCTFail("wrong AnchorError: \(error)")
            }
        }
    }

    // MARK: - info

    /// Empty /info response. Exercises the all-nil branches in Sep6Info.init(response:)
    /// (no deposit / deposit-exchange / withdraw / withdraw-exchange / fee /
    /// transaction / transactions / features).
    func testInfoEmpty() async throws {
        let info = try await anchor().sep6.info()
        XCTAssertNil(info.deposit)
        XCTAssertNil(info.depositExchange)
        XCTAssertNil(info.withdraw)
        XCTAssertNil(info.withdrawExchange)
        XCTAssertNil(info.fee)
        XCTAssertNil(info.transaction)
        XCTAssertNil(info.transactions)
        XCTAssertNil(info.features)
    }

    /// Rich /info that exercises model fields not covered in TransferTest:
    /// deposit fee_fixed/fee_percent, withdraw types where one type has no fields
    /// (null -> types[key] == nil), fee endpoint description, and feature flags
    /// with non-default values.
    func testInfoVariants() async throws {
        // language is forwarded; uses the lang query branch in the SDK.
        let info = try await anchor().sep6.info(language: "en")

        guard let deposit = info.deposit, let depositUSD = deposit["USD"] else {
            XCTFail("deposit USD missing"); return
        }
        XCTAssertTrue(depositUSD.enabled)
        XCTAssertEqual(0.5, depositUSD.feeFixed)
        XCTAssertEqual(1.5, depositUSD.feePercent)
        XCTAssertEqual(1.0, depositUSD.minAmount)
        XCTAssertEqual(5000.0, depositUSD.maxAmount)
        // authentication_required absent -> defaults to false.
        XCTAssertFalse(depositUSD.authenticationRequired ?? true)

        guard let depositExchange = info.depositExchange, let deUSD = depositExchange["USD"] else {
            XCTFail("deposit-exchange USD missing"); return
        }
        XCTAssertTrue(deUSD.enabled)
        XCTAssertTrue(deUSD.authenticationRequired ?? false)

        guard let withdraw = info.withdraw, let withdrawUSD = withdraw["USD"] else {
            XCTFail("withdraw USD missing"); return
        }
        XCTAssertEqual(2.0, withdrawUSD.feeFixed)
        XCTAssertEqual(0.25, withdrawUSD.feePercent)
        guard let types = withdrawUSD.types else {
            XCTFail("withdraw types missing"); return
        }
        // "cash" type is present with explicit null fields -> mapped to a nil value.
        XCTAssertTrue(types.keys.contains("cash"))
        if let cash = types["cash"] {
            XCTAssertNil(cash)
        } else {
            XCTFail("cash type key not present")
        }
        // "bank_account" carries field info.
        guard let bankAccount = types["bank_account"], let bankAccount = bankAccount else {
            XCTFail("withdraw bank_account fields missing"); return
        }
        XCTAssertNotNil(bankAccount["dest"])

        guard let we = info.withdrawExchange, let weUSD = we["USD"] else {
            XCTFail("withdraw-exchange USD missing"); return
        }
        XCTAssertTrue(weUSD.enabled)

        guard let fee = info.fee else { XCTFail("fee info missing"); return }
        XCTAssertTrue(fee.enabled)
        // fee.description is intentionally not asserted: the underlying iOS SDK does
        // not yet decode the SEP-6 fee `description` field, so it is always nil here.
        // Tracked in plans/todo.md.

        guard let features = info.features else { XCTFail("features missing"); return }
        XCTAssertFalse(features.accountCreation)
        XCTAssertTrue(features.claimableBalances)
    }

    func testInfoAnchorError() async throws {
        do {
            _ = try await wallet.anchor(homeDomain: Sep6CovUtils.anchorHost).sep6.info(language: "de")
            XCTFail("expected anchor error")
        } catch {
            // "de" triggers the 400 error response in the mock.
            assertAnchorError(error, expectedMessage: "info not available")
        }
    }

    func testInfoMalformedJson() async throws {
        do {
            _ = try await wallet.anchor(homeDomain: Sep6CovUtils.anchorHost).sep6.info(language: "fr")
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }

    // MARK: - deposit

    /// Deposit success carrying min/max amount and extra_info but no instructions.
    /// Exercises the extraInfo non-nil branch and instructions == nil branch in
    /// Sep6TransferResponse.fromDepositSuccessResponse.
    func testDepositSuccessWithExtraInfoNoInstructions() async throws {
        let token = try await authToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "10.0")
        let response = try await anchor().sep6.deposit(params: params, authToken: token)
        switch response {
        case .depositSuccess(let how, let id, _, let minAmount, let maxAmount, _, _, let extraInfo, let instructions):
            XCTAssertEqual("Send funds to bank.", how)
            XCTAssertEqual("dep-1", id)
            XCTAssertEqual(1.0, minAmount)
            XCTAssertEqual(2000.0, maxAmount)
            XCTAssertEqual("Deposits over 1000 take 24h.", extraInfo?.message)
            XCTAssertNil(instructions)
        default:
            XCTFail("wrong deposit response: \(response)")
        }
    }

    func testDepositCustomerInfoNeeded() async throws {
        let token = try await authToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "20.0")
        let response = try await anchor().sep6.deposit(params: params, authToken: token)
        switch response {
        case .missingKYC(let fields):
            XCTAssertEqual(["first_name", "last_name", "email_address"], fields)
        default:
            XCTFail("wrong deposit response: \(response)")
        }
    }

    /// customer_info_status carrying more_info_url and eta. Exercises
    /// Sep6TransferResponse.fromCustomerInformationStatusResponse fully.
    func testDepositCustomerInfoStatus() async throws {
        let token = try await authToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "30.0")
        let response = try await anchor().sep6.deposit(params: params, authToken: token)
        switch response {
        case .pending(let status, let moreInfoUrl, let eta):
            XCTAssertEqual("pending", status)
            XCTAssertEqual("https://anchor.example.com/kyc?id=1", moreInfoUrl)
            XCTAssertEqual(3600, eta)
        default:
            XCTFail("wrong deposit response: \(response)")
        }
    }

    /// 403 with type=authentication_required maps to .authenticationRequired,
    /// which is rethrown (the default branch of the deposit failure switch).
    func testDepositAuthenticationRequired() async throws {
        let token = try await authToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "40.0")
        do {
            _ = try await anchor().sep6.deposit(params: params, authToken: token)
            XCTFail("expected authentication required error")
        } catch let error as TransferServerError {
            switch error {
            case .authenticationRequired:
                break
            default:
                XCTFail("expected .authenticationRequired, got \(error)")
            }
        }
    }

    /// 403 with an unrecognized type cannot be mapped to an informationNeeded
    /// variant, so it surfaces as .parsingResponseFailed and is rethrown.
    func testDepositForbiddenUnknownType() async throws {
        let token = try await authToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "50.0")
        do {
            _ = try await anchor().sep6.deposit(params: params, authToken: token)
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }

    func testDepositAnchorError() async throws {
        let token = try await authToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "999.0")
        do {
            _ = try await anchor().sep6.deposit(params: params, authToken: token)
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "deposit not supported for this asset")
        }
    }

    func testDepositMalformedJson() async throws {
        let token = try await authToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "11.0")
        do {
            _ = try await anchor().sep6.deposit(params: params, authToken: token)
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }

    // MARK: - deposit-exchange

    func testDepositExchangeCustomerInfoNeeded() async throws {
        let token = try await authToken()
        let params = Sep6DepositExchangeParams(destinationAssetCode: "XYZ",
                                               sourceAssetId: FiatAssetId(id: "USD"),
                                               amount: "20",
                                               account: Sep6CovUtils.userAccountId)
        let response = try await anchor().sep6.depositExchange(params: params, authToken: token)
        switch response {
        case .missingKYC(let fields):
            XCTAssertEqual(["first_name"], fields)
        default:
            XCTFail("wrong deposit-exchange response: \(response)")
        }
    }

    func testDepositExchangeCustomerInfoStatus() async throws {
        let token = try await authToken()
        let params = Sep6DepositExchangeParams(destinationAssetCode: "XYZ",
                                               sourceAssetId: FiatAssetId(id: "USD"),
                                               amount: "30",
                                               account: Sep6CovUtils.userAccountId)
        let response = try await anchor().sep6.depositExchange(params: params, authToken: token)
        switch response {
        case .pending(let status, _, _):
            XCTAssertEqual("denied", status)
        default:
            XCTFail("wrong deposit-exchange response: \(response)")
        }
    }

    func testDepositExchangeAnchorError() async throws {
        let token = try await authToken()
        let params = Sep6DepositExchangeParams(destinationAssetCode: "XYZ",
                                               sourceAssetId: FiatAssetId(id: "USD"),
                                               amount: "999",
                                               account: Sep6CovUtils.userAccountId)
        do {
            _ = try await anchor().sep6.depositExchange(params: params, authToken: token)
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "exchange not available")
        }
    }

    // MARK: - withdraw

    /// Withdraw success carrying extra_info. Exercises the extraInfo non-nil branch
    /// in Sep6TransferResponse.fromWithdrawSuccessResponse (TransferTest's withdraw
    /// success has none).
    func testWithdrawSuccessWithExtraInfo() async throws {
        let token = try await authToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "100.0")
        let response = try await anchor().sep6.withdraw(params: params, authToken: token)
        switch response {
        case .withdrawSuccess(let account, let memoType, let memo, let id, let eta, _, _, let feeFixed, _, let extraInfo):
            XCTAssertEqual("GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ", account)
            XCTAssertEqual("text", memoType)
            XCTAssertEqual("wd-memo", memo)
            XCTAssertEqual("wd-1", id)
            XCTAssertEqual(900, eta)
            XCTAssertEqual(1.0, feeFixed)
            XCTAssertEqual("Funds arrive within 1 business day.", extraInfo?.message)
        default:
            XCTFail("wrong withdraw response: \(response)")
        }
    }

    func testWithdrawCustomerInfoNeeded() async throws {
        let token = try await authToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "200.0")
        let response = try await anchor().sep6.withdraw(params: params, authToken: token)
        switch response {
        case .missingKYC(let fields):
            XCTAssertEqual(["bank_account_number"], fields)
        default:
            XCTFail("wrong withdraw response: \(response)")
        }
    }

    func testWithdrawCustomerInfoStatus() async throws {
        let token = try await authToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "300.0")
        let response = try await anchor().sep6.withdraw(params: params, authToken: token)
        switch response {
        case .pending(let status, let moreInfoUrl, _):
            XCTAssertEqual("pending", status)
            XCTAssertNil(moreInfoUrl)
        default:
            XCTFail("wrong withdraw response: \(response)")
        }
    }

    func testWithdrawAnchorError() async throws {
        let token = try await authToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "999.0")
        do {
            _ = try await anchor().sep6.withdraw(params: params, authToken: token)
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "withdraw not supported")
        }
    }

    func testWithdrawMalformedJson() async throws {
        let token = try await authToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "111.0")
        do {
            _ = try await anchor().sep6.withdraw(params: params, authToken: token)
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }

    // MARK: - withdraw-exchange

    func testWithdrawExchangeCustomerInfoNeeded() async throws {
        let token = try await authToken()
        let params = Sep6WithdrawExchangeParams(sourceAssetCode: "XYZ",
                                                destinationAssetId: FiatAssetId(id: "USD"),
                                                amount: "200",
                                                type: "bank_account")
        let response = try await anchor().sep6.withdrawExchange(params: params, authToken: token)
        switch response {
        case .missingKYC(let fields):
            XCTAssertEqual(["tax_id"], fields)
        default:
            XCTFail("wrong withdraw-exchange response: \(response)")
        }
    }

    func testWithdrawExchangeCustomerInfoStatus() async throws {
        let token = try await authToken()
        let params = Sep6WithdrawExchangeParams(sourceAssetCode: "XYZ",
                                                destinationAssetId: FiatAssetId(id: "USD"),
                                                amount: "300",
                                                type: "bank_account")
        let response = try await anchor().sep6.withdrawExchange(params: params, authToken: token)
        switch response {
        case .pending(let status, _, let eta):
            XCTAssertEqual("pending", status)
            XCTAssertEqual(120, eta)
        default:
            XCTFail("wrong withdraw-exchange response: \(response)")
        }
    }

    func testWithdrawExchangeAnchorError() async throws {
        let token = try await authToken()
        let params = Sep6WithdrawExchangeParams(sourceAssetCode: "XYZ",
                                                destinationAssetId: FiatAssetId(id: "USD"),
                                                amount: "999",
                                                type: "bank_account")
        do {
            _ = try await anchor().sep6.withdrawExchange(params: params, authToken: token)
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "withdraw exchange unavailable")
        }
    }

    // MARK: - fee

    func testFeeSuccess() async throws {
        let token = try await authToken()
        let fee = try await anchor().sep6.fee(assetCode: "USD",
                                              amount: 100.0,
                                              operation: "deposit",
                                              type: "bank_account",
                                              authToken: token)
        XCTAssertEqual(5.0, fee)
    }

    func testFeeAnchorError() async throws {
        let token = try await authToken()
        do {
            _ = try await anchor().sep6.fee(assetCode: "USD",
                                            amount: 999.0,
                                            operation: "withdraw",
                                            authToken: token)
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "fee endpoint disabled")
        }
    }

    // MARK: - single transaction

    /// getTransactionBy with none of the id parameters set -> ValidationError before
    /// any network call.
    func testGetTransactionByMissingArgument() async throws {
        let token = try await authToken()
        do {
            _ = try await anchor().sep6.getTransactionBy(authToken: token)
            XCTFail("expected validation error")
        } catch let error as ValidationError {
            switch error {
            case .invalidArgument(let message):
                XCTAssertTrue(message.contains("transactionId"))
            }
        }
    }

    /// Single transaction with the richer fields not covered by TransferTest:
    /// fee_details (charged fee + detail rows), quote_id, from/to, deposit memo,
    /// claimable_balance_id, more_info_url, updated_at, completed_at,
    /// user_action_required_by, and a refund whose payment id_type is "external".
    func testGetTransactionRichFields() async throws {
        let token = try await authToken()
        let tx = try await anchor().sep6.getTransactionBy(authToken: token,
                                                          transactionId: "rich-1")
        XCTAssertEqual("rich-1", tx.id)
        XCTAssertEqual(TransactionKind.deposit.rawValue, tx.kind)
        XCTAssertEqual(TransactionStatus.completed, tx.transactionStatus)
        XCTAssertEqual("quote-9", tx.quoteId)
        XCTAssertEqual("BTC-source-addr", tx.from)
        XCTAssertEqual(Sep6CovUtils.userAccountId, tx.to)
        XCTAssertEqual("deposit-memo", tx.depositMemo)
        XCTAssertEqual("text", tx.depositMemoType)
        XCTAssertEqual("claimable-123", tx.claimableBalanceId)
        XCTAssertEqual("https://anchor.example.com/tx/rich-1", tx.moreInfoUrl)
        XCTAssertNotNil(tx.updatedAt)
        XCTAssertNotNil(tx.completedAt)
        XCTAssertNotNil(tx.userActionRequiredBy)

        guard let fee = tx.chargedFeeInfo else { XCTFail("charged fee missing"); return }
        XCTAssertEqual("1.5", fee.total)
        XCTAssertEqual("iso4217:USD", fee.asset)
        guard let details = fee.details, details.count == 2 else {
            XCTFail("fee details missing"); return
        }
        XCTAssertEqual("Service fee", details[0].name)
        XCTAssertEqual("1.0", details[0].amount)
        XCTAssertEqual("Charged per transaction.", details[0].description)
        XCTAssertEqual("Network fee", details[1].name)
        XCTAssertNil(details[1].description)

        guard let refunds = tx.refunds else { XCTFail("refunds missing"); return }
        XCTAssertEqual("2", refunds.amountRefunded)
        XCTAssertEqual("0.5", refunds.amountFee)
        guard let payments = refunds.payments, let payment = payments.first else {
            XCTFail("refund payments missing"); return
        }
        XCTAssertEqual("ext-ref-1", payment.id)
        XCTAssertEqual("external", payment.idType)
        XCTAssertEqual("2", payment.amount)
        XCTAssertEqual("0.5", payment.fee)
    }

    func testGetTransactionByExternalId() async throws {
        let token = try await authToken()
        let tx = try await anchor().sep6.getTransactionBy(authToken: token,
                                                          externalTransactionId: "ext-77")
        XCTAssertEqual("by-external-1", tx.id)
        XCTAssertEqual(TransactionStatus.pendingExternal, tx.transactionStatus)
    }

    func testGetTransactionNotFound() async throws {
        let token = try await authToken()
        do {
            _ = try await anchor().sep6.getTransactionBy(authToken: token,
                                                         transactionId: "does-not-exist")
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "transaction not found")
        }
    }

    /// A single transaction missing the required started_at field cannot be decoded
    /// by the underlying SDK and surfaces as .parsingResponseFailed.
    func testGetTransactionMalformed() async throws {
        let token = try await authToken()
        do {
            _ = try await anchor().sep6.getTransactionBy(authToken: token,
                                                         transactionId: "malformed-1")
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }

    // MARK: - transactions list

    /// Transaction list with optional filters set (noOlderThan, limit, kind, pagingId).
    /// Exercises the optional query-parameter branches and a withdrawal-exchange tx
    /// carrying amount assets.
    func testGetTransactionsForAssetWithFilters() async throws {
        let token = try await authToken()
        let txs = try await anchor().sep6.getTransactionsForAsset(authToken: token,
                                                                  assetCode: "USD",
                                                                  noOlderThan: Date(timeIntervalSince1970: 1_600_000_000),
                                                                  limit: 10,
                                                                  kind: .withdrawalExchange,
                                                                  pagingId: "page-1")
        XCTAssertEqual(1, txs.count)
        let tx = txs[0]
        XCTAssertEqual("we-1", tx.id)
        XCTAssertEqual(TransactionKind.withdrawalExchange.rawValue, tx.kind)
        XCTAssertEqual(TransactionStatus.pendingAnchor, tx.transactionStatus)
        XCTAssertEqual("stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN", tx.amountInAsset)
        XCTAssertEqual("iso4217:BRL", tx.amountOutAsset)
    }

    func testGetTransactionsForAssetAnchorError() async throws {
        let token = try await authToken()
        do {
            _ = try await anchor().sep6.getTransactionsForAsset(authToken: token,
                                                                assetCode: "NOPE")
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "asset not supported")
        }
    }

    func testGetTransactionsForAssetMalformed() async throws {
        let token = try await authToken()
        do {
            _ = try await anchor().sep6.getTransactionsForAsset(authToken: token,
                                                                assetCode: "BAD")
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }
}

// MARK: - Mocks

class Sep6CovInfoResponseMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            let lang = mock.variables["lang"]
            if lang == "de" {
                mock.statusCode = 400
                return "{\"error\": \"info not available\"}"
            }
            if lang == "fr" {
                mock.statusCode = 200
                return "{ this is not valid json "
            }
            if lang == "en" {
                mock.statusCode = 200
                return self?.variantsInfo()
            }
            mock.statusCode = 200
            return self?.emptyInfo()
        }

        return RequestMock(host: host,
                           path: "/info",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    func emptyInfo() -> String {
        return "{}"
    }

    func variantsInfo() -> String {
        return """
        {
          "deposit": {
            "USD": {
              "enabled": true,
              "fee_fixed": 0.5,
              "fee_percent": 1.5,
              "min_amount": 1.0,
              "max_amount": 5000
            }
          },
          "deposit-exchange": {
            "USD": {
              "enabled": true,
              "authentication_required": true
            }
          },
          "withdraw": {
            "USD": {
              "enabled": true,
              "authentication_required": true,
              "fee_fixed": 2.0,
              "fee_percent": 0.25,
              "types": {
                "bank_account": {
                  "fields": {
                    "dest": { "description": "your bank account number" }
                  }
                },
                "cash": {}
              }
            }
          },
          "withdraw-exchange": {
            "USD": {
              "enabled": true,
              "authentication_required": true,
              "types": {
                "bank_account": {
                  "fields": {
                    "dest": { "description": "your bank account number" }
                  }
                }
              }
            }
          },
          "fee": {
            "enabled": true,
            "description": "Flat fee schedule."
          },
          "transaction": {
            "enabled": true,
            "authentication_required": true
          },
          "transactions": {
            "enabled": true,
            "authentication_required": true
          },
          "features": {
            "account_creation": false,
            "claimable_balances": true
          }
        }
        """
    }
}

class Sep6CovDepositResponseMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            let amount = mock.variables["amount"]
            switch amount {
            case "10.0":
                mock.statusCode = 200
                return self?.depositWithExtraInfo()
            case "20.0":
                mock.statusCode = 403
                return self?.customerInfoNeeded()
            case "30.0":
                mock.statusCode = 403
                return self?.customerInfoStatus()
            case "40.0":
                mock.statusCode = 403
                return self?.authenticationRequired()
            case "50.0":
                mock.statusCode = 403
                return self?.forbiddenUnknownType()
            case "11.0":
                mock.statusCode = 200
                return "{ malformed json"
            default:
                mock.statusCode = 400
                return "{\"error\": \"deposit not supported for this asset\"}"
            }
        }

        return RequestMock(host: host,
                           path: "/deposit",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    func depositWithExtraInfo() -> String {
        return """
        {
          "how": "Send funds to bank.",
          "id": "dep-1",
          "min_amount": 1.0,
          "max_amount": 2000,
          "extra_info": { "message": "Deposits over 1000 take 24h." }
        }
        """
    }

    func customerInfoNeeded() -> String {
        return "{\"type\": \"non_interactive_customer_info_needed\", \"fields\": [\"first_name\", \"last_name\", \"email_address\"]}"
    }

    func customerInfoStatus() -> String {
        return "{\"type\": \"customer_info_status\", \"status\": \"pending\", \"more_info_url\": \"https://anchor.example.com/kyc?id=1\", \"eta\": 3600}"
    }

    func authenticationRequired() -> String {
        return "{\"type\": \"authentication_required\"}"
    }

    func forbiddenUnknownType() -> String {
        return "{\"type\": \"some_unknown_type\"}"
    }
}

class Sep6CovDepositExchangeResponseMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            let amount = mock.variables["amount"]
            switch amount {
            case "20":
                mock.statusCode = 403
                return "{\"type\": \"non_interactive_customer_info_needed\", \"fields\": [\"first_name\"]}"
            case "30":
                mock.statusCode = 403
                return "{\"type\": \"customer_info_status\", \"status\": \"denied\"}"
            default:
                mock.statusCode = 400
                return "{\"error\": \"exchange not available\"}"
            }
        }

        return RequestMock(host: host,
                           path: "/deposit-exchange",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
}

class Sep6CovWithdrawResponseMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            let amount = mock.variables["amount"]
            switch amount {
            case "100.0":
                mock.statusCode = 200
                return self?.withdrawWithExtraInfo()
            case "200.0":
                mock.statusCode = 403
                return "{\"type\": \"non_interactive_customer_info_needed\", \"fields\": [\"bank_account_number\"]}"
            case "300.0":
                mock.statusCode = 403
                return "{\"type\": \"customer_info_status\", \"status\": \"pending\"}"
            case "111.0":
                mock.statusCode = 200
                return "{ malformed"
            default:
                mock.statusCode = 400
                return "{\"error\": \"withdraw not supported\"}"
            }
        }

        return RequestMock(host: host,
                           path: "/withdraw",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    func withdrawWithExtraInfo() -> String {
        return """
        {
          "account_id": "GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ",
          "memo_type": "text",
          "memo": "wd-memo",
          "id": "wd-1",
          "eta": 900,
          "fee_fixed": 1.0,
          "extra_info": { "message": "Funds arrive within 1 business day." }
        }
        """
    }
}

class Sep6CovWithdrawExchangeResponseMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            let amount = mock.variables["amount"]
            switch amount {
            case "200":
                mock.statusCode = 403
                return "{\"type\": \"non_interactive_customer_info_needed\", \"fields\": [\"tax_id\"]}"
            case "300":
                mock.statusCode = 403
                return "{\"type\": \"customer_info_status\", \"status\": \"pending\", \"eta\": 120}"
            default:
                mock.statusCode = 400
                return "{\"error\": \"withdraw exchange unavailable\"}"
            }
        }

        return RequestMock(host: host,
                           path: "/withdraw-exchange",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
}

class Sep6CovFeeResponseMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            let amount = mock.variables["amount"]
            if amount == "100.0" {
                mock.statusCode = 200
                return "{\"fee\": 5.0}"
            }
            mock.statusCode = 400
            return "{\"error\": \"fee endpoint disabled\"}"
        }

        return RequestMock(host: host,
                           path: "/fee",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
}

class Sep6CovSingleTxResponseMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let id = mock.variables["id"] {
                switch id {
                case "rich-1":
                    mock.statusCode = 200
                    return self?.richTransaction()
                case "malformed-1":
                    mock.statusCode = 200
                    return self?.malformedTransaction()
                case "does-not-exist":
                    mock.statusCode = 404
                    return "{\"error\": \"transaction not found\"}"
                default:
                    mock.statusCode = 404
                    return "{\"error\": \"transaction not found\"}"
                }
            }
            if let extId = mock.variables["external_transaction_id"], extId == "ext-77" {
                mock.statusCode = 200
                return self?.byExternalTransaction()
            }
            mock.statusCode = 404
            return "{\"error\": \"transaction not found\"}"
        }

        return RequestMock(host: host,
                           path: "/transaction",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    func richTransaction() -> String {
        return """
        {
          "transaction": {
            "id": "rich-1",
            "kind": "deposit",
            "status": "completed",
            "amount_in": "100",
            "amount_out": "98.5",
            "amount_fee": "1.5",
            "quote_id": "quote-9",
            "from": "BTC-source-addr",
            "to": "\(Sep6CovUtils.userAccountId)",
            "deposit_memo": "deposit-memo",
            "deposit_memo_type": "text",
            "claimable_balance_id": "claimable-123",
            "more_info_url": "https://anchor.example.com/tx/rich-1",
            "started_at": "2021-06-11T17:00:00Z",
            "updated_at": "2021-06-11T17:05:00Z",
            "completed_at": "2021-06-11T17:10:00Z",
            "user_action_required_by": "2021-06-12T17:00:00Z",
            "fee_details": {
              "total": "1.5",
              "asset": "iso4217:USD",
              "details": [
                { "name": "Service fee", "amount": "1.0", "description": "Charged per transaction." },
                { "name": "Network fee", "amount": "0.5" }
              ]
            },
            "refunds": {
              "amount_refunded": "2",
              "amount_fee": "0.5",
              "payments": [
                { "id": "ext-ref-1", "id_type": "external", "amount": "2", "fee": "0.5" }
              ]
            }
          }
        }
        """
    }

    func byExternalTransaction() -> String {
        return """
        {
          "transaction": {
            "id": "by-external-1",
            "kind": "deposit",
            "status": "pending_external",
            "amount_in": "50",
            "amount_out": "49",
            "amount_fee": "1",
            "external_transaction_id": "ext-77",
            "started_at": "2021-06-11T17:00:00Z"
          }
        }
        """
    }

    func malformedTransaction() -> String {
        // Missing required "started_at" -> AnchorTransaction decode fails.
        return """
        {
          "transaction": {
            "id": "malformed-1",
            "kind": "deposit",
            "status": "completed",
            "amount_in": "10"
          }
        }
        """
    }
}

class Sep6CovMultipleTxResponseMock: ResponsesMock {
    var host: String

    init(host: String) {
        self.host = host
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            let assetCode = mock.variables["asset_code"]
            switch assetCode {
            case "USD":
                mock.statusCode = 200
                return self?.withdrawExchangeTransactions()
            case "BAD":
                mock.statusCode = 200
                return "{ not valid json"
            default:
                mock.statusCode = 400
                return "{\"error\": \"asset not supported\"}"
            }
        }

        return RequestMock(host: host,
                           path: "/transactions",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    func withdrawExchangeTransactions() -> String {
        return """
        {
          "transactions": [
            {
              "id": "we-1",
              "kind": "withdrawal-exchange",
              "status": "pending_anchor",
              "status_eta": 3600,
              "amount_in": "100",
              "amount_in_asset": "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN",
              "amount_out": "500",
              "amount_out_asset": "iso4217:BRL",
              "amount_fee": "0.1",
              "started_at": "2021-06-11T17:05:32Z"
            }
          ]
        }
        """
    }
}
