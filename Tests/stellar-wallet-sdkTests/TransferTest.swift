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
    
    override func setUp() {
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
