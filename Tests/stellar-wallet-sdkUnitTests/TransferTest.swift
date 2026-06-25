//
//  TransferTest.swift
//  
//
//  Created by Christian Rogobete on 01.03.25.
//

import XCTest
import Foundation
import stellarsdk
@testable import stellar_wallet_sdk


final class TransferTestUtils {

    static let anchorHost = "place.anchor.com"
    static let anchorWebAuthHost = "api.anchor.org"
    static let webAuthEndpoint = "https://\(anchorWebAuthHost)/auth"
    static let anchorTransferHost = "sep6.anchor.org"

    static let serverAccountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
    static let serverSecretSeed = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
    static let userAccountId = "GB4L7JUU5DENUXYH3ANTLVYQL66KQLDDJTN5SF7MWEDGWSGUA375V44V"
    static let userSecretSeed = "SBAYNYLQFXVLVAHW4BXDQYNJLMDQMZ5NQDDOHVJD3PTBAUIJRNRK5LGX"
    
    static let serverKeypair = try! KeyPair(secretSeed: serverSecretSeed)
    static let userKeypair = try! KeyPair(secretSeed: userSecretSeed)
    
    static let existingTxId = "82fhs729f63dh0v4"
    static let extistingStellarTxId = "17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a"
    static let pendingTxId = "55fhs729f63dh0v5"
}

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

final class TransferTest: XCTestCase {

    let wallet = Wallet.testNet
    var anchorTomlServerMock: TomlResponseMock!
    var challengeServerMock: WebAuthChallengeResponseMock!
    var sendChallengeServerMock: WebAuthSendChallengeResponseMock!
    var infoServerMock: Sep6InfoResponseMock!
    var depositServerMock: Sep6DepositResponseMock!
    var withdrawServerMock: Sep6WithdrawResponseMock!
    var depositExchangeServerMock: Sep6DepositExchangeResponseMock!
    var withdrawExchangeServerMock: Sep6WithdrawExchangeResponseMock!
    var singleTxServerMock:Sep6SingleTxResponseMock!
    var multipeTxServerMock:Sep6MultipleTxResponseMock!

    var sep6AnchorTomlServerMock: TomlResponseMock!
    var sep6NoSep6TomlServerMock: TomlResponseMock!
    var sep6ChallengeServerMock: WebAuthChallengeResponseMock!
    var sep6SendChallengeServerMock: WebAuthSendChallengeResponseMock!

    var sep6InfoServerMock: Sep6CovInfoResponseMock!
    var sep6DepositServerMock: Sep6CovDepositResponseMock!
    var sep6DepositExchangeServerMock: Sep6CovDepositExchangeResponseMock!
    var sep6WithdrawServerMock: Sep6CovWithdrawResponseMock!
    var sep6WithdrawExchangeServerMock: Sep6CovWithdrawExchangeResponseMock!
    var sep6FeeServerMock: Sep6CovFeeResponseMock!
    var sep6SingleTxServerMock: Sep6CovSingleTxResponseMock!
    var sep6MultipleTxServerMock: Sep6CovMultipleTxResponseMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        anchorTomlServerMock = TomlResponseMock(host: TransferTestUtils.anchorHost,
                                                       serverSigningKey: TransferTestUtils.serverAccountId,
                                                       authServer: TransferTestUtils.webAuthEndpoint,
                                                       sep6TransferServer: "https://\(TransferTestUtils.anchorTransferHost)")

        challengeServerMock = WebAuthChallengeResponseMock(host: TransferTestUtils.anchorWebAuthHost,
                                                           serverKeyPair: TransferTestUtils.serverKeypair)

        sendChallengeServerMock = WebAuthSendChallengeResponseMock(host: TransferTestUtils.anchorWebAuthHost)

        infoServerMock = Sep6InfoResponseMock(host: TransferTestUtils.anchorTransferHost)
        depositServerMock = Sep6DepositResponseMock(host: TransferTestUtils.anchorTransferHost)
        withdrawServerMock = Sep6WithdrawResponseMock(host: TransferTestUtils.anchorTransferHost)
        depositExchangeServerMock = Sep6DepositExchangeResponseMock(host: TransferTestUtils.anchorTransferHost)
        withdrawExchangeServerMock = Sep6WithdrawExchangeResponseMock(host: TransferTestUtils.anchorTransferHost)
        singleTxServerMock = Sep6SingleTxResponseMock(host: TransferTestUtils.anchorTransferHost)
        multipeTxServerMock = Sep6MultipleTxResponseMock(host: TransferTestUtils.anchorTransferHost)

        sep6AnchorTomlServerMock = TomlResponseMock(host: Sep6CovUtils.anchorHost,
                                                serverSigningKey: Sep6CovUtils.serverAccountId,
                                                authServer: Sep6CovUtils.webAuthEndpoint,
                                                sep6TransferServer: "https://\(Sep6CovUtils.anchorTransferHost)")

        // No TRANSFER_SERVER -> services.sep6 == nil at the SDK layer.
        sep6NoSep6TomlServerMock = TomlResponseMock(host: Sep6CovUtils.noSep6Host,
                                                serverSigningKey: Sep6CovUtils.serverAccountId,
                                                authServer: Sep6CovUtils.webAuthEndpoint)

        sep6ChallengeServerMock = WebAuthChallengeResponseMock(host: Sep6CovUtils.anchorWebAuthHost,
                                                           serverKeyPair: Sep6CovUtils.serverKeypair,
                                                           homeDomain: Sep6CovUtils.anchorHost)

        sep6SendChallengeServerMock = WebAuthSendChallengeResponseMock(host: Sep6CovUtils.anchorWebAuthHost)

        sep6InfoServerMock = Sep6CovInfoResponseMock(host: Sep6CovUtils.anchorTransferHost)
        sep6DepositServerMock = Sep6CovDepositResponseMock(host: Sep6CovUtils.anchorTransferHost)
        sep6DepositExchangeServerMock = Sep6CovDepositExchangeResponseMock(host: Sep6CovUtils.anchorTransferHost)
        sep6WithdrawServerMock = Sep6CovWithdrawResponseMock(host: Sep6CovUtils.anchorTransferHost)
        sep6WithdrawExchangeServerMock = Sep6CovWithdrawExchangeResponseMock(host: Sep6CovUtils.anchorTransferHost)
        sep6FeeServerMock = Sep6CovFeeResponseMock(host: Sep6CovUtils.anchorTransferHost)
        sep6SingleTxServerMock = Sep6CovSingleTxResponseMock(host: Sep6CovUtils.anchorTransferHost)
        sep6MultipleTxServerMock = Sep6CovMultipleTxResponseMock(host: Sep6CovUtils.anchorTransferHost)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    func testAll() async throws {
        try await infoTest()
        try await depositBankPaymentTest()
        try await depositBTCTest()
        try await depositRippleTest()
        try await depositMXNTest()
        try await withdrawSuccessTest()
        try await depositExchangeTest()
        try await withdrawExchangeTest()
        try await depositCustomerInfoNeededTest()
        try await depositCustomerInfoStatusTest()
        try await getTransactionsForAssetTest()
        try await getTransactionTest()
        try await watchOneTransactionTest()
        try await watchOnAssetTest()
    }
    
    func infoTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        do {
            let info = try await anchor.sep6.info()
            guard let deposit = info.deposit else {
                XCTFail("depost not found")
                return
            }
            XCTAssertEqual(2, deposit.count)
            
            guard let depositInfoUSD = deposit["USD"] else {
                XCTFail("depost USD not found")
                return
            }
            XCTAssertTrue(depositInfoUSD.enabled)
            XCTAssertTrue(depositInfoUSD.authenticationRequired ?? false)
            XCTAssertNil(depositInfoUSD.feeFixed)
            XCTAssertNil(depositInfoUSD.feePercent)
            XCTAssertEqual(0.1, depositInfoUSD.minAmount)
            XCTAssertEqual(1000.0, depositInfoUSD.maxAmount)
 
            guard let USDfieldsInfo = depositInfoUSD.fieldsInfo else {
                XCTFail("USD fieldsInfo not found")
                return
            }
            
            XCTAssertEqual(4, USDfieldsInfo.count)
            guard let USDfieldsInfoEmail = USDfieldsInfo["email_address"]else {
                XCTFail("USD fieldsInfo email not found")
                return
            }
            XCTAssertEqual("your email address for transaction status updates", USDfieldsInfoEmail.description)
            XCTAssertTrue(USDfieldsInfoEmail.optional ?? false)
            
            guard let USDfieldsInfoCountryCode = USDfieldsInfo["country_code"] else {
                XCTFail("USD fieldsInfo country_code not found")
                return
            }
            guard let USDfieldsInfoCountryCodeChoices = USDfieldsInfoCountryCode.choices else {
                XCTFail("USD fieldsInfo country_code choices not found")
                return
            }
            XCTAssertTrue(USDfieldsInfoCountryCodeChoices.contains("USA"))
            
            guard let USDfieldsInfoType = USDfieldsInfo["type"] else {
                XCTFail("USD fieldsInfo type not found")
                return
            }
            guard let USDfieldsInfoTypeChoices = USDfieldsInfoType.choices else {
                XCTFail("USD fieldsInfo type choices not found")
                return
            }
            XCTAssertTrue(USDfieldsInfoTypeChoices.contains("SWIFT"))
            
            guard let withdraw = info.withdraw else {
                XCTFail("withdraw not found")
                return
            }
            XCTAssertEqual(2, withdraw.count)
            
            guard let withdrawInfoUSD = withdraw["USD"] else {
                XCTFail("withdraw USD not found")
                return
            }
            XCTAssertTrue(withdrawInfoUSD.enabled)
            XCTAssertTrue(withdrawInfoUSD.authenticationRequired ?? false)
            XCTAssertNil(withdrawInfoUSD.feeFixed)
            XCTAssertNil(withdrawInfoUSD.feePercent)
            XCTAssertEqual(0.1, withdrawInfoUSD.minAmount)
            XCTAssertEqual(1000.0, withdrawInfoUSD.maxAmount)
            
            
            guard let USDfieldTypes = withdrawInfoUSD.types else {
                XCTFail("USD withdraw types not found")
                return
            }
            
            XCTAssertEqual(2, USDfieldTypes.count)
            
            guard let bankAccountFields = USDfieldTypes["bank_account"], bankAccountFields != nil else {
                XCTFail("USD withdraw bank_account not found")
                return
            }
            
            guard let bankAccountCountryCode = bankAccountFields!["country_code"] else {
                XCTFail("USD withdraw bank_account country code not found")
                return
            }
            guard let bankAccountCountryCodeChoices = bankAccountCountryCode.choices else {
                XCTFail("USD withdraw bank_account country code choices not found")
                return
            }
            XCTAssertTrue(bankAccountCountryCodeChoices.contains("PRI"))
            
            guard let cashFields = USDfieldTypes["cash"], cashFields != nil else {
                XCTFail("USD withdraw cash not found")
                return
            }
            guard let cashDest = cashFields!["dest"] else {
                XCTFail("USD withdraw cash dest not found")
                return
            }
            XCTAssertTrue(cashDest.optional ?? false)
            
            guard let withdrawInfoETH = withdraw["ETH"] else {
                XCTFail("withdraw ETH not found")
                return
            }
            XCTAssertFalse(withdrawInfoETH.enabled)
            
            guard let withdrawExchange = info.withdrawExchange else {
                XCTFail("withdraw exchange not found")
                return
            }
            XCTAssertEqual(1, withdrawExchange.count)
            
            guard let withdrawExchangeInfoUSD = withdrawExchange["USD"] else {
                XCTFail("withdraw exchange USD not found")
                return
            }
            XCTAssertFalse(withdrawExchangeInfoUSD.enabled)
            XCTAssertTrue(withdrawExchangeInfoUSD.authenticationRequired ?? false)
            
            guard let weUSDfieldTypes = withdrawExchangeInfoUSD.types else {
                XCTFail("USD withdraw exchange types not found")
                return
            }
            
            XCTAssertEqual(2, weUSDfieldTypes.count)
            
            guard let weBankAccountFields = weUSDfieldTypes["bank_account"], weBankAccountFields != nil else {
                XCTFail("USD withdraw exchange bank_account not found")
                return
            }
            
            guard let weBankAccountCountryCode = weBankAccountFields!["country_code"] else {
                XCTFail("USD withdraw exchange bank_account country code not found")
                return
            }
            guard let weBankAccountCountryCodeChoices = weBankAccountCountryCode.choices else {
                XCTFail("USD withdraw exchange bank_account country code choices not found")
                return
            }
            XCTAssertTrue(weBankAccountCountryCodeChoices.contains("PRI"))
            
            
            guard let feeEndpointInfo = info.fee else {
                XCTFail("Fee endpoint info not found")
                return
            }
            XCTAssertFalse(feeEndpointInfo.enabled)
            
            guard let transactionEndpointInfo = info.transaction else {
                XCTFail("Transaction endpoint info not found")
                return
            }
            XCTAssertFalse(transactionEndpointInfo.enabled)
            XCTAssertTrue(transactionEndpointInfo.authenticationRequired ?? false)
            
            guard let transactionsEndpointInfo = info.transactions else {
                XCTFail("Transactions endpoint info not found")
                return
            }
            XCTAssertTrue(transactionsEndpointInfo.enabled)
            XCTAssertTrue(transactionsEndpointInfo.authenticationRequired ?? false)
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func depositBankPaymentTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let depositParams = Sep6DepositParams(assetCode: "USD",
                                                  account: TransferTestUtils.userAccountId,
                                                  amount: "123.123")
            let depositResponse = try await anchor.sep6.deposit(params: depositParams, authToken: authToken)
            switch depositResponse {
            //case .depositSuccess(let how, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo, let instructions):
            case .depositSuccess(let how, let id, _, _, _, let feeFixed, _, _, let instructions):
                XCTAssertEqual("Make a payment to Bank: 121122676 Account: 13719713158835300", how)
                XCTAssertEqual("9421871e-0623-4356-b7b5-5996da122f3e", id)
                XCTAssertNil(feeFixed)
                guard let instructions = instructions else {
                    XCTFail("no instructions found")
                    return
                }
                guard let bankNumber = instructions["\(Sep9OrganizationKeys.prefix).\(Sep9FinancialKeys.bankNumber)"] else {
                    XCTFail("no bank number found")
                    return
                }
                XCTAssertEqual("121122676", bankNumber.value)
                XCTAssertEqual("US bank routing number", bankNumber.description)
                
                guard let bankAccountNumber = instructions["\(Sep9OrganizationKeys.prefix).\(Sep9FinancialKeys.bankAccountNumber)"] else {
                    XCTFail("no bank account number found")
                    return
                }
                XCTAssertEqual("13719713158835300", bankAccountNumber.value)
                XCTAssertEqual("US bank account number", bankAccountNumber.description)
                break
            default:
                XCTFail("wrong deposit response")
            }
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func depositBTCTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let depositParams = Sep6DepositParams(assetCode: "BTC",
                                                  account: TransferTestUtils.userAccountId,
                                                  amount: "3.123")
            let depositResponse = try await anchor.sep6.deposit(params: depositParams, authToken: authToken)
            switch depositResponse {
            //case .depositSuccess(let how, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo, let instructions):
            case .depositSuccess(let how, let id, _, _, _, let feeFixed, _, _, let instructions):
                XCTAssertEqual("Make a payment to Bitcoin address 1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB", how)
                XCTAssertEqual("9421871e-0623-4356-b7b5-5996da122f3e", id)
                XCTAssertEqual(0.0002, feeFixed)
                guard let instructions = instructions else {
                    XCTFail("no instructions found")
                    return
                }
                guard let cryptoAddress = instructions["\(Sep9OrganizationKeys.prefix).\(Sep9FinancialKeys.cryptoAddress)"] else {
                    XCTFail("no crypto address found")
                    return
                }
                XCTAssertEqual("1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB", cryptoAddress.value)
                XCTAssertEqual("Bitcoin address", cryptoAddress.description)
                
                break
            default:
                XCTFail("wrong deposit response")
            }
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func depositRippleTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let depositParams = Sep6DepositParams(assetCode: "XRP",
                                                  account: TransferTestUtils.userAccountId,
                                                  amount: "300.0")
            let depositResponse = try await anchor.sep6.deposit(params: depositParams, authToken: authToken)
            switch depositResponse {
            //case .depositSuccess(let how, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo, let instructions):
            case .depositSuccess(let how, let id, let eta, _, _, _, let feePercent, let extraInfo, let instructions):
                XCTAssertEqual("Make a payment to Ripple address rNXEkKCxvfLcM1h4HJkaj2FtmYuAWrHGbf with tag 88", how)
                XCTAssertEqual("9421871e-0623-4356-b7b5-5996da122f3e", id)
                XCTAssertEqual(60, eta)
                XCTAssertEqual(0.1, feePercent)
                
                guard let extraInfo = extraInfo else {
                    XCTFail("no extra Info found")
                    return
                }
                XCTAssertEqual("You must include the tag. If the amount is more than 1000 XRP, deposit will take 24h to complete.", extraInfo.message)
                
                guard let instructions = instructions else {
                    XCTFail("no instructions found")
                    return
                }
                guard let cryptoAddress = instructions["\(Sep9OrganizationKeys.prefix).\(Sep9FinancialKeys.cryptoAddress)"] else {
                    XCTFail("no crypto address found")
                    return
                }
                XCTAssertEqual("rNXEkKCxvfLcM1h4HJkaj2FtmYuAWrHGbf", cryptoAddress.value)
                XCTAssertEqual("Ripple address", cryptoAddress.description)
                
                guard let cryptoMemo = instructions["\(Sep9OrganizationKeys.prefix).\(Sep9FinancialKeys.cryptoMemo)"] else {
                    XCTFail("no crypto memo found")
                    return
                }
                
                XCTAssertEqual("88", cryptoMemo.value)
                XCTAssertEqual("Ripple tag", cryptoMemo.description)
                
                break
            default:
                XCTFail("wrong deposit response")
            }
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func depositMXNTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let depositParams = Sep6DepositParams(assetCode: "MXN",
                                                  account: TransferTestUtils.userAccountId,
                                                  amount: "120.0")
            let depositResponse = try await anchor.sep6.deposit(params: depositParams, authToken: authToken)
            switch depositResponse {
            //case .depositSuccess(let how, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo, let instructions):
            case .depositSuccess(let how, let id, let eta, _, _, _, _, _, let instructions):
                XCTAssertEqual("Make a payment to Bank: STP Account: 646180111803859359", how)
                XCTAssertEqual("9421871e-0623-4356-b7b5-5996da122f3e", id)
                XCTAssertEqual(1800, eta)
                
                guard let instructions = instructions else {
                    XCTFail("no instructions found")
                    return
                }
                guard let clabeNumber = instructions["\(Sep9OrganizationKeys.prefix).\(Sep9FinancialKeys.clabeNumber)"] else {
                    XCTFail("no clabe Number found")
                    return
                }
                XCTAssertEqual("646180111803859359", clabeNumber.value)
                XCTAssertEqual("CLABE number", clabeNumber.description)
                
                break
            default:
                XCTFail("wrong deposit response")
            }
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func withdrawSuccessTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let withdrawParams = Sep6WithdrawParams(assetCode: "XLM",
                                                    type: "crypto",
                                                    dest: "GCTTGO5ABSTHABXWL2FMHPZ2XFOZDXJYJN5CKFRKXMPAAWZW3Y3JZ3JK",
                                                    account: TransferTestUtils.userAccountId,
                                                    amount: "120.0")
            
            let withdrawResponse = try await anchor.sep6.withdraw(params: withdrawParams, authToken: authToken)
            
            switch withdrawResponse {
            //case .withdrawSuccess(let account, let memoType, let memo, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo):
            case .withdrawSuccess(let account, let memoType, let memo, let id, _, _, _, _, _, _):
                XCTAssertEqual("GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ", account)
                XCTAssertEqual("id", memoType)
                XCTAssertEqual("123", memo)
                XCTAssertEqual("9421871e-0623-4356-b7b5-5996da122f3e", id)
                break
            default:
                XCTFail("wrong withdrawal response")
            }
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func depositExchangeTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let params = Sep6DepositExchangeParams(destinationAssetCode: "XYZ",
                                                   sourceAssetId: FiatAssetId(id: "USD"),
                                                   amount: "100",
                                                   account: "GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ",
                                                   quoteId: "282837",
                                                   locationId: "999")
            
            let depositExchangeResponse = try await anchor.sep6.depositExchange(params: params, authToken: authToken)
            
            switch depositExchangeResponse {
            //case .depositSuccess(let how, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo, let instructions):
            case .depositSuccess(let how, let id, _, _, _, let feeFixed, _, _, let instructions):
                XCTAssertEqual("Make a payment to Bank: 121122676 Account: 13719713158835300", how)
                XCTAssertEqual("9421871e-0623-4356-b7b5-5996da122f3e", id)
                XCTAssertNil(feeFixed)
                guard let instructions = instructions else {
                    XCTFail("no instructions found")
                    return
                }
                guard let bankNumber = instructions["\(Sep9OrganizationKeys.prefix).\(Sep9FinancialKeys.bankNumber)"] else {
                    XCTFail("no bank number found")
                    return
                }
                XCTAssertEqual("121122676", bankNumber.value)
                XCTAssertEqual("US bank routing number", bankNumber.description)
                
                guard let bankAccountNumber = instructions["\(Sep9OrganizationKeys.prefix).\(Sep9FinancialKeys.bankAccountNumber)"] else {
                    XCTFail("no bank account number found")
                    return
                }
                XCTAssertEqual("13719713158835300", bankAccountNumber.value)
                XCTAssertEqual("US bank account number", bankAccountNumber.description)
                break
            default:
                XCTFail("wrong deposit exchange response")
            }
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func withdrawExchangeTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let params = Sep6WithdrawExchangeParams(sourceAssetCode: "XYZ",
                                                    destinationAssetId: FiatAssetId(id: "USD"),
                                                    amount: "700",
                                                    type: "bank_account",
                                                    quoteId: "282837",
                                                    locationId: "999")
            
            let withdrawExchangeResponse = try await anchor.sep6.withdrawExchange(params: params, authToken: authToken)
            
            switch withdrawExchangeResponse {
            //case .withdrawSuccess(let account, let memoType, let memo, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo):
            case .withdrawSuccess(let account, let memoType, let memo, let id, _, _, _, _, _, _):
                XCTAssertEqual("GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ", account)
                XCTAssertEqual("id", memoType)
                XCTAssertEqual("123", memo)
                XCTAssertEqual("9421871e-0623-4356-b7b5-5996da122f3e", id)
                break
            default:
                XCTFail("wrong withdrawal response")
            }
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func depositCustomerInfoNeededTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let depositParams = Sep6DepositParams(assetCode: "MXN",
                                                  account: TransferTestUtils.userAccountId,
                                                  amount: "130.0")
            let depositResponse = try await anchor.sep6.deposit(params: depositParams, authToken: authToken)
            switch depositResponse {
            case .missingKYC(let fields):
                XCTAssertTrue(fields.contains("family_name"))
                break
            default:
                XCTFail("wrong deposit response")
            }
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func depositCustomerInfoStatusTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            
            let depositParams = Sep6DepositParams(assetCode: "MXN",
                                                  account: TransferTestUtils.userAccountId,
                                                  amount: "140.0")
            let depositResponse = try await anchor.sep6.deposit(params: depositParams, authToken: authToken)
            switch depositResponse {
            case .pending(let status, _, _):
                XCTAssertEqual("denied", status)
                break
            default:
                XCTFail("wrong deposit response")
            }
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func getTransactionsForAssetTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            let txs = try await anchor.sep6.getTransactionsForAsset(authToken: authToken,
                                                                     assetCode: "XLM")
        
            XCTAssertEqual(6, txs.count)
            var tx = txs[0]
            XCTAssertEqual(TransferTestUtils.existingTxId, tx.id)
            XCTAssertEqual(TransactionKind.deposit.rawValue, tx.kind)
            XCTAssertEqual(TransactionStatus.pendingExternal, tx.transactionStatus)
            XCTAssertEqual(3600, tx.statusEta)
            XCTAssertEqual("2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093", tx.externalTransactionId)
            XCTAssertEqual("18.34", tx.amountIn)
            XCTAssertEqual("18.24", tx.amountOut)
            XCTAssertEqual("0.1", tx.amountFee)
            
            tx = txs[1]
            XCTAssertEqual("52fys79f63dh3v2", tx.id)
            XCTAssertEqual(TransactionKind.depositExchange.rawValue, tx.kind)
            XCTAssertEqual(TransactionStatus.pendingAnchor, tx.transactionStatus)
            XCTAssertEqual(3600, tx.statusEta)
            XCTAssertEqual("2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093", tx.externalTransactionId)
            XCTAssertEqual("500", tx.amountIn)
            XCTAssertEqual("iso4217:BRL", tx.amountInAsset)
            XCTAssertEqual("100", tx.amountOut)
            XCTAssertEqual("stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN", tx.amountOutAsset)
            XCTAssertEqual("0.1", tx.amountFee)
            XCTAssertEqual("iso4217:BRL", tx.amountFeeAsset)
            
            tx = txs[2]
            XCTAssertEqual("82fhs729f63dh0v4", tx.id)
            XCTAssertEqual(TransactionKind.withdrawal.rawValue, tx.kind)
            XCTAssertEqual(TransactionStatus.completed, tx.transactionStatus)
            XCTAssertNil(tx.statusEta)
            XCTAssertEqual("510", tx.amountIn)
            XCTAssertNil(tx.amountInAsset)
            XCTAssertEqual("490", tx.amountOut)
            XCTAssertNil(tx.amountOutAsset)
            XCTAssertEqual("5", tx.amountFee)
            XCTAssertNil(tx.amountFeeAsset)
            XCTAssertEqual("17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a", tx.stellarTransactionId)
            XCTAssertEqual("1238234", tx.externalTransactionId)
            XCTAssertEqual("GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL", tx.withdrawAnchorAccount)
            XCTAssertEqual("186384", tx.withdrawMemo)
            XCTAssertEqual("id", tx.withdrawMemoType)
            
            let refunds = tx.refunds!
            XCTAssertEqual("10", refunds.amountRefunded)
            XCTAssertEqual("5", refunds.amountFee)
            let payments = refunds.payments!
            XCTAssertEqual(1, payments.count)
            XCTAssertEqual("b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020", payments.first?.id)
            XCTAssertEqual("stellar", payments.first?.idType)
            XCTAssertEqual("10", payments.first?.amount)
            XCTAssertEqual("5", payments.first?.fee)
            
            tx = txs[4]
            XCTAssertEqual("We were unable to send funds to the provided bank account. Bank error: 'Account does not exist'. Please provide the correct bank account address.", tx.requiredInfoMessage)
            let requiredInfoUpdates = tx.requiredInfoUpdates!
            XCTAssertEqual(2, requiredInfoUpdates.count)
            let dest = requiredInfoUpdates["dest"]!
            XCTAssertEqual("your bank account number", dest.description)
            let destExtra = requiredInfoUpdates["dest_extra"]!
            XCTAssertEqual("your routing number", destExtra.description)
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func getTransactionTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            let tx = try await anchor.sep6.getTransactionBy(authToken: authToken, transactionId:TransferTestUtils.existingTxId)
            XCTAssertEqual(TransferTestUtils.existingTxId, tx.id)
            XCTAssertEqual("18.34", tx.amountIn)
            XCTAssertEqual("18.24", tx.amountOut)
            XCTAssertEqual("0.1", tx.amountFee)
            XCTAssertEqual(TransactionStatus.completed, tx.transactionStatus)
            XCTAssertEqual("2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093", tx.externalTransactionId)
            
            let tx2 = try await anchor.sep6.getTransactionBy(authToken: authToken,
                                                              stellarTransactionId: TransferTestUtils.extistingStellarTxId)
            XCTAssertEqual(TransferTestUtils.existingTxId, tx2.id)
            
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func watchOneTransactionTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            let watcher = anchor.sep6.watcher()
            let result = watcher.watchOneTransaction(authToken: authToken,
                                                     id: TransferTestUtils.pendingTxId)
            let txObserver = TxObserver()
            NotificationCenter.default.addObserver(txObserver,
                                                   selector: #selector(txObserver.handleEvent(_:)),
                                                   name: result.notificationName,
                                                   object: nil)
            
            try! await Task.sleep(nanoseconds: UInt64(20 * Double(NSEC_PER_SEC)))
            result.stop()
            XCTAssertEqual(1, txObserver.successCount)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }
    
    func watchOnAssetTest() async throws {
        let anchor = wallet.anchor(homeDomain: TransferTestUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: TransferTestUtils.userSecretSeed)
        do {
            let authToken = try await anchor.sep10.authenticate(userKeyPair: authKey)
            XCTAssertEqual(AuthTestUtils.jwtSuccess, authToken.jwt)
            let watcher = anchor.sep6.watcher()
            let result = watcher.watchAsset(authToken: authToken,
                                            asset: try IssuedAssetId(code: "ETH",
                                                                     issuer: "GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U"))
            let txObserver = TxObserver()
            NotificationCenter.default.addObserver(txObserver,
                                                   selector: #selector(txObserver.handleEvent(_:)),
                                                   name: result.notificationName,
                                                   object: nil)
            
            try! await Task.sleep(nanoseconds: UInt64(25 * Double(NSEC_PER_SEC)))
            result.stop()
            XCTAssertEqual(3, txObserver.successCount)
        } catch (let e) {
            XCTFail(e.localizedDescription)
        }
    }

    // MARK: - helpers

    private func sep6AuthToken() async throws -> AuthToken {
        let anchor = wallet.anchor(homeDomain: Sep6CovUtils.anchorHost)
        let authKey = try SigningKeyPair(secretKey: Sep6CovUtils.userSecretSeed)
        let token = try await anchor.sep10.authenticate(userKeyPair: authKey)
        XCTAssertEqual(AuthTestUtils.jwtSuccess, token.jwt)
        return token
    }

    private func sep6Anchor() -> Anchor {
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
        let info = try await sep6Anchor().sep6.info()
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
        let info = try await sep6Anchor().sep6.info(language: "en")

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
        let token = try await sep6AuthToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "10.0")
        let response = try await sep6Anchor().sep6.deposit(params: params, authToken: token)
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
        let token = try await sep6AuthToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "20.0")
        let response = try await sep6Anchor().sep6.deposit(params: params, authToken: token)
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
        let token = try await sep6AuthToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "30.0")
        let response = try await sep6Anchor().sep6.deposit(params: params, authToken: token)
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
        let token = try await sep6AuthToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "40.0")
        do {
            _ = try await sep6Anchor().sep6.deposit(params: params, authToken: token)
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
        let token = try await sep6AuthToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "50.0")
        do {
            _ = try await sep6Anchor().sep6.deposit(params: params, authToken: token)
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }

    func testDepositAnchorError() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "999.0")
        do {
            _ = try await sep6Anchor().sep6.deposit(params: params, authToken: token)
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "deposit not supported for this asset")
        }
    }

    func testDepositMalformedJson() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6DepositParams(assetCode: "USD",
                                       account: Sep6CovUtils.userAccountId,
                                       amount: "11.0")
        do {
            _ = try await sep6Anchor().sep6.deposit(params: params, authToken: token)
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }

    // MARK: - deposit-exchange

    func testDepositExchangeCustomerInfoNeeded() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6DepositExchangeParams(destinationAssetCode: "XYZ",
                                               sourceAssetId: FiatAssetId(id: "USD"),
                                               amount: "20",
                                               account: Sep6CovUtils.userAccountId)
        let response = try await sep6Anchor().sep6.depositExchange(params: params, authToken: token)
        switch response {
        case .missingKYC(let fields):
            XCTAssertEqual(["first_name"], fields)
        default:
            XCTFail("wrong deposit-exchange response: \(response)")
        }
    }

    func testDepositExchangeCustomerInfoStatus() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6DepositExchangeParams(destinationAssetCode: "XYZ",
                                               sourceAssetId: FiatAssetId(id: "USD"),
                                               amount: "30",
                                               account: Sep6CovUtils.userAccountId)
        let response = try await sep6Anchor().sep6.depositExchange(params: params, authToken: token)
        switch response {
        case .pending(let status, _, _):
            XCTAssertEqual("denied", status)
        default:
            XCTFail("wrong deposit-exchange response: \(response)")
        }
    }

    func testDepositExchangeAnchorError() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6DepositExchangeParams(destinationAssetCode: "XYZ",
                                               sourceAssetId: FiatAssetId(id: "USD"),
                                               amount: "999",
                                               account: Sep6CovUtils.userAccountId)
        do {
            _ = try await sep6Anchor().sep6.depositExchange(params: params, authToken: token)
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
        let token = try await sep6AuthToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "100.0")
        let response = try await sep6Anchor().sep6.withdraw(params: params, authToken: token)
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
        let token = try await sep6AuthToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "200.0")
        let response = try await sep6Anchor().sep6.withdraw(params: params, authToken: token)
        switch response {
        case .missingKYC(let fields):
            XCTAssertEqual(["bank_account_number"], fields)
        default:
            XCTFail("wrong withdraw response: \(response)")
        }
    }

    func testWithdrawCustomerInfoStatus() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "300.0")
        let response = try await sep6Anchor().sep6.withdraw(params: params, authToken: token)
        switch response {
        case .pending(let status, let moreInfoUrl, _):
            XCTAssertEqual("pending", status)
            XCTAssertNil(moreInfoUrl)
        default:
            XCTFail("wrong withdraw response: \(response)")
        }
    }

    func testWithdrawAnchorError() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "999.0")
        do {
            _ = try await sep6Anchor().sep6.withdraw(params: params, authToken: token)
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "withdraw not supported")
        }
    }

    func testWithdrawMalformedJson() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6WithdrawParams(assetCode: "USD",
                                        type: "bank_account",
                                        amount: "111.0")
        do {
            _ = try await sep6Anchor().sep6.withdraw(params: params, authToken: token)
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }

    // MARK: - withdraw-exchange

    func testWithdrawExchangeCustomerInfoNeeded() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6WithdrawExchangeParams(sourceAssetCode: "XYZ",
                                                destinationAssetId: FiatAssetId(id: "USD"),
                                                amount: "200",
                                                type: "bank_account")
        let response = try await sep6Anchor().sep6.withdrawExchange(params: params, authToken: token)
        switch response {
        case .missingKYC(let fields):
            XCTAssertEqual(["tax_id"], fields)
        default:
            XCTFail("wrong withdraw-exchange response: \(response)")
        }
    }

    func testWithdrawExchangeCustomerInfoStatus() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6WithdrawExchangeParams(sourceAssetCode: "XYZ",
                                                destinationAssetId: FiatAssetId(id: "USD"),
                                                amount: "300",
                                                type: "bank_account")
        let response = try await sep6Anchor().sep6.withdrawExchange(params: params, authToken: token)
        switch response {
        case .pending(let status, _, let eta):
            XCTAssertEqual("pending", status)
            XCTAssertEqual(120, eta)
        default:
            XCTFail("wrong withdraw-exchange response: \(response)")
        }
    }

    func testWithdrawExchangeAnchorError() async throws {
        let token = try await sep6AuthToken()
        let params = Sep6WithdrawExchangeParams(sourceAssetCode: "XYZ",
                                                destinationAssetId: FiatAssetId(id: "USD"),
                                                amount: "999",
                                                type: "bank_account")
        do {
            _ = try await sep6Anchor().sep6.withdrawExchange(params: params, authToken: token)
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "withdraw exchange unavailable")
        }
    }

    // MARK: - fee

    func testFeeSuccess() async throws {
        let token = try await sep6AuthToken()
        let fee = try await sep6Anchor().sep6.fee(assetCode: "USD",
                                              amount: 100.0,
                                              operation: "deposit",
                                              type: "bank_account",
                                              authToken: token)
        XCTAssertEqual(5.0, fee)
    }

    func testFeeAnchorError() async throws {
        let token = try await sep6AuthToken()
        do {
            _ = try await sep6Anchor().sep6.fee(assetCode: "USD",
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
        let token = try await sep6AuthToken()
        do {
            _ = try await sep6Anchor().sep6.getTransactionBy(authToken: token)
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
        let token = try await sep6AuthToken()
        let tx = try await sep6Anchor().sep6.getTransactionBy(authToken: token,
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
        let token = try await sep6AuthToken()
        let tx = try await sep6Anchor().sep6.getTransactionBy(authToken: token,
                                                          externalTransactionId: "ext-77")
        XCTAssertEqual("by-external-1", tx.id)
        XCTAssertEqual(TransactionStatus.pendingExternal, tx.transactionStatus)
    }

    func testGetTransactionNotFound() async throws {
        let token = try await sep6AuthToken()
        do {
            _ = try await sep6Anchor().sep6.getTransactionBy(authToken: token,
                                                         transactionId: "does-not-exist")
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "transaction not found")
        }
    }

    /// A single transaction missing the required started_at field cannot be decoded
    /// by the underlying SDK and surfaces as .parsingResponseFailed.
    func testGetTransactionMalformed() async throws {
        let token = try await sep6AuthToken()
        do {
            _ = try await sep6Anchor().sep6.getTransactionBy(authToken: token,
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
        let token = try await sep6AuthToken()
        let txs = try await sep6Anchor().sep6.getTransactionsForAsset(authToken: token,
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
        let token = try await sep6AuthToken()
        do {
            _ = try await sep6Anchor().sep6.getTransactionsForAsset(authToken: token,
                                                                assetCode: "NOPE")
            XCTFail("expected anchor error")
        } catch {
            assertAnchorError(error, expectedMessage: "asset not supported")
        }
    }

    func testGetTransactionsForAssetMalformed() async throws {
        let token = try await sep6AuthToken()
        do {
            _ = try await sep6Anchor().sep6.getTransactionsForAsset(authToken: token,
                                                                assetCode: "BAD")
            XCTFail("expected parsing failure")
        } catch {
            assertParsingFailed(error)
        }
    }
}

class Sep6InfoResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 200
            return self?.requestSuccess()
        }
        
        return RequestMock(host: host,
                           path: "/info",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestSuccess() -> String {
        return "{  \"deposit\": {    \"USD\": {      \"enabled\": true,      \"authentication_required\": true,      \"min_amount\": 0.1,      \"max_amount\": 1000,      \"fields\": {        \"email_address\" : {          \"description\": \"your email address for transaction status updates\",          \"optional\": true        },        \"amount\" : {          \"description\": \"amount in USD that you plan to deposit\"        },        \"country_code\": {          \"description\": \"The ISO 3166-1 alpha-3 code of the user's current address\",          \"choices\": [\"USA\", \"PRI\"]        },        \"type\" : {          \"description\": \"type of deposit to make\",          \"choices\": [\"SEPA\", \"SWIFT\", \"cash\"]        }      }    },    \"ETH\": {      \"enabled\": true,      \"authentication_required\": false    }  },  \"deposit-exchange\": {    \"USD\": {      \"authentication_required\": true,      \"fields\": {        \"email_address\" : {          \"description\": \"your email address for transaction status updates\",          \"optional\": true        },        \"amount\" : {          \"description\": \"amount in USD that you plan to deposit\"        },        \"country_code\": {          \"description\": \"The ISO 3166-1 alpha-3 code of the user's current address\",          \"choices\": [\"USA\", \"PRI\"]        },        \"type\" : {          \"description\": \"type of deposit to make\",          \"choices\": [\"SEPA\", \"SWIFT\", \"cash\"]        }      }    }  },  \"withdraw\": {    \"USD\": {      \"enabled\": true,      \"authentication_required\": true,      \"min_amount\": 0.1,      \"max_amount\": 1000,      \"types\": {        \"bank_account\": {          \"fields\": {              \"dest\": {\"description\": \"your bank account number\" },              \"dest_extra\": { \"description\": \"your routing number\" },              \"bank_branch\": { \"description\": \"address of your bank branch\" },              \"phone_number\": { \"description\": \"your phone number in case there's an issue\" },              \"country_code\": {                \"description\": \"The ISO 3166-1 alpha-3 code of the user's current address\",                \"choices\": [\"USA\", \"PRI\"]              }          }        },        \"cash\": {          \"fields\": {            \"dest\": {              \"description\": \"your email address. Your cashout PIN will be sent here. If not provided, your account's default email will be used\",              \"optional\": true            }          }        }      }    },    \"ETH\": {      \"enabled\": false    }  },  \"withdraw-exchange\": {    \"USD\": {      \"authentication_required\": true,      \"min_amount\": 0.1,      \"max_amount\": 1000,      \"types\": {        \"bank_account\": {          \"fields\": {              \"dest\": {\"description\": \"your bank account number\" },              \"dest_extra\": { \"description\": \"your routing number\" },              \"bank_branch\": { \"description\": \"address of your bank branch\" },              \"phone_number\": { \"description\": \"your phone number in case there's an issue\" },              \"country_code\": {                \"description\": \"The ISO 3166-1 alpha-3 code of the user's current address\",                \"choices\": [\"USA\", \"PRI\"]              }          }        },        \"cash\": {          \"fields\": {            \"dest\": {              \"description\": \"your email address. Your cashout PIN will be sent here. If not provided, your account's default email will be used\",              \"optional\": true            }          }        }      }    }  },  \"fee\": {    \"enabled\": false,    \"description\": \"Fees vary from 3 to 7 percent based on the the assets transacted and method by which funds are delivered to or collected by the anchor.\"  },  \"transactions\": {    \"enabled\": true,    \"authentication_required\": true  },  \"transaction\": {    \"enabled\": false,    \"authentication_required\": true  },  \"features\": {    \"account_creation\": true,    \"claimable_balances\": true  }}"
    }
}

class Sep6DepositResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let assetCode = mock.variables["asset_code"], assetCode == "USD" {
                if let amount = mock.variables["amount"], amount == "123.123"  {
                    mock.statusCode = 200
                    return self?.requestBankDeposit()
                }
            } else if let assetCode = mock.variables["asset_code"], assetCode == "BTC" {
                if let amount = mock.variables["amount"], amount == "3.123"  {
                    mock.statusCode = 200
                    return self?.requestBTCDeposit()
                }
            } else if let assetCode = mock.variables["asset_code"], assetCode == "XRP" {
                if let amount = mock.variables["amount"], amount == "300.0"  {
                    mock.statusCode = 200
                    return self?.requestRippleDeposit()
                }
            } else if let assetCode = mock.variables["asset_code"], assetCode == "MXN" {
                if let amount = mock.variables["amount"], amount == "120.0"  {
                    mock.statusCode = 200
                    return self?.requestMXNDeposit()
                }
                if let amount = mock.variables["amount"], amount == "130.0"  {
                    mock.statusCode = 403
                    return self?.requestCustomerInformationNeeded()
                }
                if let amount = mock.variables["amount"], amount == "140.0"  {
                    mock.statusCode = 403
                    return self?.requestCustomerInformationStatus()
                }
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/deposit",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestBankDeposit() -> String {
        return "{  \"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\",  \"instructions\": {    \"organization.bank_number\": {      \"value\": \"121122676\",      \"description\": \"US bank routing number\"    },    \"organization.bank_account_number\": {      \"value\": \"13719713158835300\",      \"description\": \"US bank account number\"    }  },  \"how\": \"Make a payment to Bank: 121122676 Account: 13719713158835300\"}"
    }
    
    func requestBTCDeposit() -> String {
        return "{  \"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\",  \"instructions\": {    \"organization.crypto_address\": {      \"value\": \"1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB\",      \"description\": \"Bitcoin address\"    }  },  \"how\": \"Make a payment to Bitcoin address 1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB\",  \"fee_fixed\": 0.0002}"
    }
    
    func requestRippleDeposit() -> String {
        return "{  \"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\",  \"instructions\": {    \"organization.crypto_address\": {      \"value\": \"rNXEkKCxvfLcM1h4HJkaj2FtmYuAWrHGbf\",      \"description\": \"Ripple address\"    },    \"organization.crypto_memo\": {      \"value\": \"88\",      \"description\": \"Ripple tag\"    }  },  \"how\": \"Make a payment to Ripple address rNXEkKCxvfLcM1h4HJkaj2FtmYuAWrHGbf with tag 88\",  \"eta\": 60,  \"fee_percent\": 0.1,  \"extra_info\": {    \"message\": \"You must include the tag. If the amount is more than 1000 XRP, deposit will take 24h to complete.\"  }}"
    }
    
    func requestMXNDeposit() -> String {
        return "{  \"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\",  \"instructions\": {    \"organization.clabe_number\": {      \"value\": \"646180111803859359\",      \"description\": \"CLABE number\"    }  },  \"how\": \"Make a payment to Bank: STP Account: 646180111803859359\",  \"eta\": 1800}"
    }
    
    func requestCustomerInformationNeeded() -> String {
        return "{\"type\": \"non_interactive_customer_info_needed\",\"fields\" : [\"family_name\", \"given_name\", \"address\", \"tax_id\"]}"
    }
    
    func requestCustomerInformationStatus() -> String {
        return "{\"type\": \"customer_info_status\",\"status\": \"denied\",\"more_info_url\": \"https://api.example.com/kycstatus?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI\"}"
    }
}

class Sep6WithdrawResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let assetCode = mock.variables["asset_code"], assetCode == "XLM" {
                if let amount = mock.variables["amount"], amount == "120.0"  {
                    mock.statusCode = 200
                    return self?.requestWithdrawSuccess()
                }
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/withdraw",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestWithdrawSuccess() -> String {
        return "{\"account_id\": \"GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ\",\"memo_type\": \"id\",\"memo\": \"123\",\"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\"}"
    }
}

class Sep6DepositExchangeResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let destAssetCode = mock.variables["destination_asset"], destAssetCode == "XYZ",
                let sourceAsset = mock.variables["source_asset"], sourceAsset == "iso4217:USD"  {
                
                if let amount = mock.variables["amount"], amount == "100",
                    let quoteId =  mock.variables["quote_id"], quoteId == "282837",
                    let account = mock.variables["account"], account == "GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ",
                    let locationId = mock.variables["location_id"], locationId == "999" {
                    
                    mock.statusCode = 200
                    return self?.requestBankDeposit()
                }
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/deposit-exchange",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestBankDeposit() -> String {
        return "{  \"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\",  \"instructions\": {    \"organization.bank_number\": {      \"value\": \"121122676\",      \"description\": \"US bank routing number\"    },    \"organization.bank_account_number\": {      \"value\": \"13719713158835300\",      \"description\": \"US bank account number\"    }  },  \"how\": \"Make a payment to Bank: 121122676 Account: 13719713158835300\"}"
    }
}

class Sep6WithdrawExchangeResponseMock: ResponsesMock {
    var host: String
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let destAssetCode = mock.variables["destination_asset"], destAssetCode == "iso4217:USD",
                let sourceAsset = mock.variables["source_asset"], sourceAsset == "XYZ"  {
                
                if let amount = mock.variables["amount"], amount == "700",
                    let quoteId =  mock.variables["quote_id"], quoteId == "282837",
                    let type =  mock.variables["type"], type == "bank_account",
                    let locationId = mock.variables["location_id"], locationId == "999" {
                    
                    mock.statusCode = 200
                    return self?.requestWithdrawSuccess()
                }
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/withdraw-exchange",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestWithdrawSuccess() -> String {
        return "{\"account_id\": \"GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ\",\"memo_type\": \"id\",\"memo\": \"123\",\"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\"}"
    }
}

class Sep6SingleTxResponseMock: ResponsesMock {
    var host: String
    var pendingCount = 0
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let txId = mock.variables["id"], txId == TransferTestUtils.existingTxId {
                mock.statusCode = 200
                return self?.requestSuccess(txId: txId)
            } else if let stellarTransactionId = mock.variables["stellar_transaction_id"],
                        stellarTransactionId == TransferTestUtils.extistingStellarTxId {
                mock.statusCode = 200
                return self?.requestSuccess(txId: TransferTestUtils.existingTxId)
            } else if let txId = mock.variables["id"], txId == TransferTestUtils.pendingTxId {
                mock.statusCode = 200
                if let count = self?.pendingCount, count < 2  {
                    self?.pendingCount += 1
                    return self?.requestPendingTx()
                    
                }
                return self?.requestSuccess(txId: txId)
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/transaction",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestSuccess(txId:String) -> String {
        return "{  \"transaction\": {    \"id\": \"\(txId)\",    \"kind\": \"deposit\",    \"status\": \"completed\",    \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",    \"amount_in\": \"18.34\",    \"amount_out\": \"18.24\",    \"amount_fee\": \"0.1\",    \"started_at\": \"2017-03-20T17:05:32Z\"  }}";
    }
    
    func requestPendingTx() -> String {
        return "{  \"transaction\": {    \"id\": \"55fhs729f63dh0v5\",    \"kind\": \"deposit\",    \"status\": \"pending_external\",    \"status_eta\": 3600,    \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31094\",    \"amount_in\": \"18.34\",    \"amount_out\": \"18.24\",    \"amount_fee\": \"0.1\",    \"started_at\": \"2017-03-20T17:05:32Z\"  }}"
        
    }
}

class Sep6MultipleTxResponseMock: ResponsesMock {
    var host: String
    var pendingCount = 0
    
    init(host:String) {
        self.host = host
        super.init()
    }
    
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            if let assetCode =  mock.variables["asset_code"], assetCode == "XLM" {
                mock.statusCode = 200
                return self?.requestTransactions()
            } else if let assetCode =  mock.variables["asset_code"], assetCode == "ETH" {
                mock.statusCode = 200
                self?.pendingCount += 1
                if let count = self?.pendingCount {
                    if (count == 1) {
                        return self?.requestPendingTransactions1()
                    } else if (count == 2) {
                        return self?.requestPendingTransactions2()
                    } else if (count == 3) {
                        return self?.requestPendingTransactions3()
                    }
                }
                return self?.requestPendingTransactionsCompleted()
            }
            mock.statusCode = 404
            return """
                {"error": "not found"}
            """
        }
        
        return RequestMock(host: host,
                           path: "/transactions",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
    
    func requestTransactions() -> String {
        return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },    {      \"id\": \"52fys79f63dh3v2\",      \"kind\": \"deposit-exchange\",      \"status\": \"pending_anchor\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"500\",      \"amount_in_asset\": \"iso4217:BRL\",      \"amount_out\": \"100\",      \"amount_out_asset\": \"stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN\",      \"amount_fee\": \"0.1\",      \"amount_fee_asset\": \"iso4217:BRL\",      \"started_at\": \"2021-06-11T17:05:32Z\"    },    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"completed_at\": \"2017-03-20T17:09:58Z\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1238234\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"72fhs729f63dh0v1\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"completed_at\": \"2017-03-20T17:09:58Z\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1238234\",      \"from\": \"AJ3845SAD\",      \"to\": \"GBITQ4YAFKD2372TNAMNHQ4JV5VS3BYKRK4QQR6FOLAR7XAHC3RVGVVJ\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"104201\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"52fys79f63dh3v1\",      \"kind\": \"withdrawal\",      \"status\": \"pending_transaction_info_update\",      \"amount_in\": \"750.00\",      \"amount_out\": null,      \"amount_fee\": null,      \"started_at\": \"2017-03-20T17:00:02Z\",      \"required_info_message\": \"We were unable to send funds to the provided bank account. Bank error: 'Account does not exist'. Please provide the correct bank account address.\",      \"required_info_updates\": {        \"transaction\": {          \"dest\": {\"description\": \"your bank account number\" },          \"dest_extra\": { \"description\": \"your routing number\" }        }      }    },    {      \"id\": \"52fys79f63dh3v2\",      \"kind\": \"withdrawal-exchange\",      \"status\": \"pending_anchor\",      \"status_eta\": 3600,      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"amount_in\": \"100\",      \"amount_in_asset\": \"stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN\",      \"amount_out\": \"500\",      \"amount_out_asset\": \"iso4217:BRL\",      \"amount_fee\": \"0.1\",      \"amount_fee_asset\": \"stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN\",      \"started_at\": \"2021-06-11T17:05:32Z\"    }  ]}"
    }
    
    func requestPendingTransactions1() -> String {
        return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },   {      \"id\": \"82fhs729f63dh0v5\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31094\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },  {      \"id\": \"82fhs729f63dh0v6\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31095\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    }]}"
    }
    
    func requestPendingTransactions2() -> String {
        return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",     \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },   {      \"id\": \"82fhs729f63dh0v5\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31094\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },  {      \"id\": \"82fhs729f63dh0v6\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31095\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    }]}"
        
    }
    
    func requestPendingTransactions3() -> String {
        return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",     \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },   {      \"id\": \"82fhs729f63dh0v5\",      \"kind\": \"deposit\",      \"status\": \"completed\",   \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31094\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },  {      \"id\": \"82fhs729f63dh0v6\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31095\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    }]}"
    }
    
    func requestPendingTransactionsCompleted() -> String {
        return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",     \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },   {      \"id\": \"82fhs729f63dh0v5\",      \"kind\": \"deposit\",      \"status\": \"completed\",   \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31094\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },  {      \"id\": \"82fhs729f63dh0v6\",      \"kind\": \"deposit\",      \"status\": \"completed\",    \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31095\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    }]}"
    }
}

// MARK: - SEP-6 coverage mocks

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
