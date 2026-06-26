//
//  StellarTest.swift
//
//
//  Offline, fully mocked unit tests for the Horizon layer of the wallet SDK:
//  TxBuilder / CommonTxBuilder / SponsoringBuilder, Stellar, AccountService,
//  AccountKeyPair (SigningKeyPair / PublicKeyPair) and the Transaction /
//  FeeBumpTransaction envelope encoding extensions.
//
//  All Horizon traffic is intercepted by ServerMock (a URLProtocol). No network
//  access happens during these tests.
//

import XCTest
import Foundation
import stellarsdk
@testable import stellar_wallet_sdk

final class StellarTest: XCTestCase {

    static let horizonHost = "horizon-testnet.stellar.org"

    let wallet = Wallet.testNet

    /// Source account that exists on the (mocked) network and is used to build transactions.
    var sourceKp: SigningKeyPair!
    /// A second, also-existing account, used as payment / merge / sponsorship destination.
    var destinationKp: SigningKeyPair!
    /// An account that does NOT exist on the (mocked) network (served a 404).
    var missingKp: SigningKeyPair!
    /// Asset issuer.
    var issuerKp: SigningKeyPair!
    /// USDC issued asset, issued by issuerKp.
    var usdc: IssuedAssetId!

    var sourceAccountMock: StellarUnitHorizonAccountMock!
    var destinationAccountMock: StellarUnitHorizonAccountMock!
    var notFoundMock: StellarUnitHorizonNotFoundMock!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        sourceKp = wallet.stellar.account.createKeyPair()
        destinationKp = wallet.stellar.account.createKeyPair()
        missingKp = wallet.stellar.account.createKeyPair()
        issuerKp = wallet.stellar.account.createKeyPair()
        usdc = try! IssuedAssetId(code: "USDC", issuer: issuerKp.address)

        // Specific /accounts/{id} mocks first, wildcard 404 fallback last.
        sourceAccountMock = StellarUnitHorizonAccountMock(
            accountId: sourceKp.address,
            sequence: "4233721387843585",
            signers: [StellarUnitHorizonSigner(key: sourceKp.address, weight: 1)])
        destinationAccountMock = StellarUnitHorizonAccountMock(
            accountId: destinationKp.address,
            sequence: "100",
            signers: [StellarUnitHorizonSigner(key: destinationKp.address, weight: 1)])

        notFoundMock = StellarUnitHorizonNotFoundMock()
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Builds a fresh TxBuilder for the (existing) source account via the mocked Horizon load.
    private func sourceTxBuilder(timeout: UInt32? = nil,
                                 baseFee: UInt32? = nil,
                                 memo: stellarsdk.Memo? = nil) async throws -> TxBuilder {
        return try await wallet.stellar.transaction(sourceAddress: sourceKp,
                                                    timeout: timeout,
                                                    baseFee: baseFee,
                                                    memo: memo)
    }

    // MARK: - AccountKeyPair

    func testSigningKeyPairFromRandomAndAddress() throws {
        let kp = SigningKeyPair.random
        XCTAssertTrue(kp.address.hasPrefix("G"))
        XCTAssertTrue(kp.secretKey.hasPrefix("S"))
        XCTAssertEqual(kp.address, kp.keyPair.accountId)
        XCTAssertEqual(kp.publicKey.accountId, kp.address)
    }

    func testSigningKeyPairFromSecretKey() throws {
        let original = SigningKeyPair.random
        let restored = try SigningKeyPair(secretKey: original.secretKey)
        XCTAssertEqual(original.address, restored.address)
        XCTAssertEqual(original.secretKey, restored.secretKey)
    }

    func testSigningKeyPairFromInvalidSecretKeyThrows() throws {
        XCTAssertThrowsError(try SigningKeyPair(secretKey: "not-a-secret")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testSigningKeyPairFromPublicOnlyKeyPairThrows() throws {
        // A KeyPair built from an account id only has no secret seed and must not become a SigningKeyPair.
        let publicOnly = try KeyPair(accountId: SigningKeyPair.random.address)
        XCTAssertThrowsError(try SigningKeyPair(keyPair: publicOnly)) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testPublicKeyPairFromAccountId() throws {
        let signing = SigningKeyPair.random
        let pub = try PublicKeyPair(accountId: signing.address)
        XCTAssertEqual(signing.address, pub.address)
        XCTAssertEqual(signing.publicKey.accountId, pub.publicKey.accountId)
    }

    func testPublicKeyPairFromInvalidAccountIdThrows() throws {
        XCTAssertThrowsError(try PublicKeyPair(accountId: "GINVALID")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testToPublicKeyPair() throws {
        let signing = SigningKeyPair.random
        let pub = signing.toPublicKeyPair()
        XCTAssertEqual(signing.address, pub.address)
    }

    func testSigningKeyPairSignTransactionAddsSignature() async throws {
        let tx = try (await sourceTxBuilder())
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        XCTAssertEqual(0, tx.transactionXDR.signatures.count)
        sourceKp.sign(transaction: tx, network: Network.testnet)
        XCTAssertEqual(1, tx.transactionXDR.signatures.count)
    }

    // MARK: - AccountService

    func testCreateKeyPair() throws {
        let kp = wallet.stellar.account.createKeyPair()
        XCTAssertTrue(kp.address.hasPrefix("G"))
        XCTAssertNotNil(try? SigningKeyPair(secretKey: kp.secretKey))
    }

    func testGetInfoReturnsAccountDetails() async throws {
        let info = try await wallet.stellar.account.getInfo(accountAddress: sourceKp.address)
        XCTAssertEqual(sourceKp.address, info.accountId)
        // sequence 4233721387843585 from the mock.
        XCTAssertEqual(Int64(4233721387843585), info.sequenceNumber)
        XCTAssertEqual(1, info.signers.count)
        XCTAssertEqual(sourceKp.address, info.signers.first?.key)
    }

    func testGetInfoForMissingAccountThrowsNotFound() async throws {
        do {
            _ = try await wallet.stellar.account.getInfo(accountAddress: missingKp.address)
            XCTFail("expected getInfo to throw for a non-existing account")
        } catch let error as HorizonRequestError {
            guard case .notFound = error else {
                return XCTFail("expected HorizonRequestError.notFound, got \(error)")
            }
        }
    }

    func testAccountExistsTrue() async throws {
        let exists = try await wallet.stellar.account.accountExists(accountAddress: sourceKp.address)
        XCTAssertTrue(exists)
    }

    func testAccountExistsFalse() async throws {
        let exists = try await wallet.stellar.account.accountExists(accountAddress: missingKp.address)
        XCTAssertFalse(exists)
    }

    // MARK: - Stellar.transaction / TxBuilder defaults

    func testTransactionLoadsSourceAccountAndDefaults() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertEqual(sourceKp.address, builder.sourceAccount.keyPair.accountId)
        // default base fee from the testnet config is 100.
        XCTAssertEqual(UInt32(100), builder.baseFee)
        XCTAssertNotNil(builder.timebounds)
        XCTAssertNil(builder.memo)
    }

    func testTransactionForMissingSourceAccountThrows() async throws {
        do {
            _ = try await wallet.stellar.transaction(sourceAddress: missingKp)
            XCTFail("expected transaction(sourceAddress:) to throw for a non-existing source account")
        } catch let error as HorizonRequestError {
            guard case .notFound = error else {
                return XCTFail("expected HorizonRequestError.notFound, got \(error)")
            }
        }
    }

    func testTransactionAppliesBaseFeeMemoAndTimeout() async throws {
        let memo = try stellarsdk.Memo(text: "hello")
        let builder = try await sourceTxBuilder(timeout: 600, baseFee: 250, memo: memo)
        XCTAssertEqual(UInt32(250), builder.baseFee)
        XCTAssertEqual(memo, builder.memo)
        XCTAssertNotNil(builder.timebounds)
    }

    func testBuildWithoutOperationsThrows() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertThrowsError(try builder.build()) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testBuildTransactionUsesIncrementedSequenceAndFee() async throws {
        let tx = try (await sourceTxBuilder(baseFee: 200))
            .createAccount(newAccount: destinationKp, startingBalance: Decimal(5))
            .build()
        // The tx sequence is the account sequence + 1.
        XCTAssertEqual(Int64(4233721387843586), tx.transactionXDR.seqNum)
        // 1 operation * baseFee 200.
        XCTAssertEqual(UInt32(200), tx.fee)
        XCTAssertEqual(sourceKp.address, tx.sourceAccount.keyPair.accountId)
    }

    func testSetBaseFeeChaining() async throws {
        let builder = (try await sourceTxBuilder()).setBaseFee(baseFeeInStoops: 999)
        XCTAssertEqual(UInt32(999), builder.baseFee)
    }

    func testSetMemoAndSetTimeboundsChaining() async throws {
        let memo = stellarsdk.Memo.id(42)
        let tb = TimeBounds(minTime: 0, maxTime: 12345)
        let builder = (try await sourceTxBuilder())
            .setMemo(memo: memo)
            .setTimebounds(timebounds: tb)
        XCTAssertEqual(memo, builder.memo)
        XCTAssertEqual(UInt64(12345), builder.timebounds?.maxTime)
    }

    // MARK: - TxBuilder operations

    func testCreateAccount() async throws {
        let tx = try (await sourceTxBuilder())
            .createAccount(newAccount: destinationKp, startingBalance: Decimal(10))
            .build()
        XCTAssertEqual(1, tx.operations.count)
        let op = try XCTUnwrap(tx.operations.first as? CreateAccountOperation)
        XCTAssertEqual(destinationKp.address, op.destination.accountId)
        XCTAssertEqual(Decimal(10), op.startBalance)
        XCTAssertEqual(sourceKp.address, op.sourceAccountId)
    }

    func testCreateAccountTooLowBalanceThrows() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertThrowsError(try builder.createAccount(newAccount: destinationKp, startingBalance: Decimal(0.5))) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testTransferNative() async throws {
        let tx = try (await sourceTxBuilder())
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(25))
            .build()
        XCTAssertEqual(1, tx.operations.count)
        let op = try XCTUnwrap(tx.operations.first as? PaymentOperation)
        XCTAssertEqual(destinationKp.address, op.destinationAccountId)
        XCTAssertEqual(Decimal(25), op.amount)
        XCTAssertEqual(AssetType.ASSET_TYPE_NATIVE, op.asset.type)
        XCTAssertEqual(sourceKp.address, op.sourceAccountId)
    }

    func testTransferIssuedAsset() async throws {
        let tx = try (await sourceTxBuilder())
            .transfer(destinationAddress: destinationKp.address, assetId: usdc, amount: Decimal(7))
            .build()
        let op = try XCTUnwrap(tx.operations.first as? PaymentOperation)
        XCTAssertEqual("USDC", op.asset.code)
        XCTAssertEqual(issuerKp.address, op.asset.issuer?.accountId)
        XCTAssertEqual(Decimal(7), op.amount)
    }

    func testTransferZeroAmountThrows() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertThrowsError(try builder.transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(0))) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testTransferInvalidDestinationThrows() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertThrowsError(try builder.transfer(destinationAddress: "GBROKEN", assetId: NativeAssetId(), amount: Decimal(1))) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testAddAssetSupportDefaultLimit() async throws {
        let tx = try (await sourceTxBuilder())
            .addAssetSupport(asset: usdc)
            .build()
        let op = try XCTUnwrap(tx.operations.first as? ChangeTrustOperation)
        XCTAssertEqual("USDC", op.asset.code)
        XCTAssertEqual(issuerKp.address, op.asset.issuer?.accountId)
        // No explicit limit -> defaults to nil (max trust).
        XCTAssertNil(op.limit)
        XCTAssertEqual(sourceKp.address, op.sourceAccountId)
    }

    func testAddAssetSupportWithLimit() async throws {
        let tx = try (await sourceTxBuilder())
            .addAssetSupport(asset: usdc, limit: Decimal(500))
            .build()
        let op = try XCTUnwrap(tx.operations.first as? ChangeTrustOperation)
        XCTAssertEqual(Decimal(500), op.limit)
    }

    func testRemoveAssetSupportSetsZeroLimit() async throws {
        let tx = try (await sourceTxBuilder())
            .removeAssetSupport(asset: usdc)
            .build()
        let op = try XCTUnwrap(tx.operations.first as? ChangeTrustOperation)
        XCTAssertEqual(Decimal(0), op.limit)
    }

    func testSetThreshold() async throws {
        let tx = try (await sourceTxBuilder())
            .setThreshold(low: 1, medium: 2, high: 3)
            .build()
        let op = try XCTUnwrap(tx.operations.first as? SetOptionsOperation)
        XCTAssertEqual(UInt32(1), op.lowThreshold)
        XCTAssertEqual(UInt32(2), op.mediumThreshold)
        XCTAssertEqual(UInt32(3), op.highThreshold)
        XCTAssertEqual(sourceKp.address, op.sourceAccountId)
    }

    func testAddAccountSigner() async throws {
        let signerKp = wallet.stellar.account.createKeyPair()
        let tx = try (await sourceTxBuilder())
            .addAccountSigner(signerAddress: signerKp, signerWeight: 10)
            .build()
        let op = try XCTUnwrap(tx.operations.first as? SetOptionsOperation)
        XCTAssertEqual(UInt32(10), op.signerWeight)
        let signerKey = try XCTUnwrap(op.signer)
        XCTAssertEqual(signerKp.address, StellarTest.ed25519AccountId(signerKey))
    }

    func testRemoveAccountSignerSetsWeightZero() async throws {
        let signerKp = wallet.stellar.account.createKeyPair()
        let tx = try (await sourceTxBuilder())
            .removeAccountSigner(signerAddress: signerKp)
            .build()
        let op = try XCTUnwrap(tx.operations.first as? SetOptionsOperation)
        XCTAssertEqual(UInt32(0), op.signerWeight)
        let signerKey = try XCTUnwrap(op.signer)
        XCTAssertEqual(signerKp.address, StellarTest.ed25519AccountId(signerKey))
    }

    func testRemoveAccountSignerForMasterKeyThrows() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertThrowsError(try builder.removeAccountSigner(signerAddress: sourceKp)) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testLockAccountMasterKey() async throws {
        let tx = try (await sourceTxBuilder())
            .lockAccountMasterKey()
            .build()
        let op = try XCTUnwrap(tx.operations.first as? SetOptionsOperation)
        XCTAssertEqual(UInt32(0), op.masterKeyWeight)
    }

    func testAccountMerge() async throws {
        let tx = try (await sourceTxBuilder())
            .accountMerge(destinationAddress: destinationKp.address)
            .build()
        let op = try XCTUnwrap(tx.operations.first as? AccountMergeOperation)
        XCTAssertEqual(destinationKp.address, op.destinationAccountId)
        XCTAssertEqual(sourceKp.address, op.sourceAccountId)
    }

    func testAccountMergeWithExplicitSource() async throws {
        let tx = try (await sourceTxBuilder())
            .accountMerge(destinationAddress: destinationKp.address, sourceAddress: issuerKp.address)
            .build()
        let op = try XCTUnwrap(tx.operations.first as? AccountMergeOperation)
        XCTAssertEqual(issuerKp.address, op.sourceAccountId)
    }

    func testAccountMergeInvalidDestinationThrows() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertThrowsError(try builder.accountMerge(destinationAddress: "GBROKEN")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testAccountMergeInvalidExplicitSourceThrows() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertThrowsError(try builder.accountMerge(destinationAddress: destinationKp.address, sourceAddress: "GBROKEN")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testAddOperation() async throws {
        let manageData = ManageDataOperation(sourceAccountId: sourceKp.address, name: "key", data: "value".data(using: .utf8))
        let tx = try (await sourceTxBuilder())
            .addOperation(operation: manageData)
            .build()
        XCTAssertEqual(1, tx.operations.count)
        let op = try XCTUnwrap(tx.operations.first as? ManageDataOperation)
        XCTAssertEqual("key", op.name)
    }

    func testStrictSend() async throws {
        let tx = try (await sourceTxBuilder())
            .strictSend(sendAssetId: NativeAssetId(),
                        sendAmount: Decimal(100),
                        destinationAddress: destinationKp.address,
                        destinationAssetId: usdc,
                        destinationMinAmount: Decimal(95))
            .build()
        let op = try XCTUnwrap(tx.operations.first as? PathPaymentStrictSendOperation)
        XCTAssertEqual(AssetType.ASSET_TYPE_NATIVE, op.sendAsset.type)
        XCTAssertEqual(Decimal(100), op.sendMax)
        XCTAssertEqual("USDC", op.destAsset.code)
        XCTAssertEqual(Decimal(95), op.destAmount)
        XCTAssertEqual(destinationKp.address, op.destinationAccountId)
        XCTAssertTrue(op.path.isEmpty)
    }

    func testStrictSendWithPath() async throws {
        let intermediate = try IssuedAssetId(code: "EUR", issuer: issuerKp.address)
        let tx = try (await sourceTxBuilder())
            .strictSend(sendAssetId: NativeAssetId(),
                        sendAmount: Decimal(100),
                        destinationAddress: destinationKp.address,
                        destinationAssetId: usdc,
                        path: [intermediate])
            .build()
        let op = try XCTUnwrap(tx.operations.first as? PathPaymentStrictSendOperation)
        XCTAssertEqual(1, op.path.count)
        XCTAssertEqual("EUR", op.path.first?.code)
        // default destinationMinAmount is 0.0000001.
        XCTAssertEqual(Decimal(string: "0.0000001"), op.destAmount)
    }

    func testStrictReceive() async throws {
        let tx = try (await sourceTxBuilder())
            .strictReceive(sendAssetId: NativeAssetId(),
                           destinationAddress: destinationKp.address,
                           destinationAssetId: usdc,
                           destinationAmount: Decimal(50),
                           sendMaxAmount: Decimal(60))
            .build()
        let op = try XCTUnwrap(tx.operations.first as? PathPaymentStrictReceiveOperation)
        XCTAssertEqual(AssetType.ASSET_TYPE_NATIVE, op.sendAsset.type)
        XCTAssertEqual(Decimal(60), op.sendMax)
        XCTAssertEqual("USDC", op.destAsset.code)
        XCTAssertEqual(Decimal(50), op.destAmount)
        XCTAssertEqual(destinationKp.address, op.destinationAccountId)
    }

    func testPathPaySendBranch() async throws {
        let tx = try (await sourceTxBuilder())
            .pathPay(destinationAddress: destinationKp.address,
                     sendAsset: NativeAssetId(),
                     destinationAsset: usdc,
                     sendAmount: Decimal(10))
            .build()
        let op = try XCTUnwrap(tx.operations.first as? PathPaymentStrictSendOperation)
        XCTAssertEqual(Decimal(10), op.sendMax)
    }

    func testPathPayReceiveBranch() async throws {
        let tx = try (await sourceTxBuilder())
            .pathPay(destinationAddress: destinationKp.address,
                     sendAsset: NativeAssetId(),
                     destinationAsset: usdc,
                     destAmount: Decimal(10),
                     sendMax: Decimal(100))
            .build()
        let op = try XCTUnwrap(tx.operations.first as? PathPaymentStrictReceiveOperation)
        XCTAssertEqual(Decimal(10), op.destAmount)
        XCTAssertEqual(Decimal(100), op.sendMax)
    }

    func testStrictReceiveDefaultSendMaxIsMaxAmount() async throws {
        // Without an explicit sendMaxAmount the builder must fall back to the maximum
        // Stellar amount (Int64.max stroops == 922337203685.4775807). This value is built
        // from a string because the equivalent Double literal rounds up to ...5808 and
        // overflows Int64 when converted to stroops, which would crash build().
        let tx = try (await sourceTxBuilder())
            .strictReceive(sendAssetId: NativeAssetId(),
                           destinationAddress: destinationKp.address,
                           destinationAssetId: usdc,
                           destinationAmount: Decimal(50))
            .build()
        let op = try XCTUnwrap(tx.operations.first as? PathPaymentStrictReceiveOperation)
        XCTAssertEqual(Decimal(50), op.destAmount)
        XCTAssertEqual(Decimal(string: "922337203685.4775807"), op.sendMax)
    }

    func testPathPayReceiveBranchDefaultSendMaxIsMaxAmount() async throws {
        // pathPay routed through the receive branch (destAmount, no sendMax) must use the
        // same maximum default and build without overflowing.
        let tx = try (await sourceTxBuilder())
            .pathPay(destinationAddress: destinationKp.address,
                     sendAsset: NativeAssetId(),
                     destinationAsset: usdc,
                     destAmount: Decimal(10))
            .build()
        let op = try XCTUnwrap(tx.operations.first as? PathPaymentStrictReceiveOperation)
        XCTAssertEqual(Decimal(10), op.destAmount)
        XCTAssertEqual(Decimal(string: "922337203685.4775807"), op.sendMax)
    }

    func testPathPayBothAmountsThrows() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertThrowsError(try builder.pathPay(destinationAddress: destinationKp.address,
                                                 sendAsset: NativeAssetId(),
                                                 destinationAsset: usdc,
                                                 sendAmount: Decimal(1),
                                                 destAmount: Decimal(1))) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testPathPayNoAmountThrows() async throws {
        let builder = try await sourceTxBuilder()
        XCTAssertThrowsError(try builder.pathPay(destinationAddress: destinationKp.address,
                                                 sendAsset: NativeAssetId(),
                                                 destinationAsset: usdc)) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testSwap() async throws {
        let tx = try (await sourceTxBuilder())
            .swap(fromAsset: NativeAssetId(), toAsset: usdc, amount: Decimal(20))
            .build()
        let op = try XCTUnwrap(tx.operations.first as? PathPaymentStrictSendOperation)
        // swap sends from the source account to itself.
        XCTAssertEqual(sourceKp.address, op.destinationAccountId)
        XCTAssertEqual(Decimal(20), op.sendMax)
    }

    func testMultipleOperationsAndFeeScaling() async throws {
        let tx = try (await sourceTxBuilder(baseFee: 100))
            .createAccount(newAccount: destinationKp, startingBalance: Decimal(2))
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .setThreshold(low: 1, medium: 1, high: 1)
            .build()
        XCTAssertEqual(3, tx.operations.count)
        // 3 operations * 100 base fee.
        XCTAssertEqual(UInt32(300), tx.fee)
    }

    // MARK: - Sponsoring

    func testSponsoringWrapsOperations() async throws {
        let sponsorKp = wallet.stellar.account.createKeyPair()
        let newKp = wallet.stellar.account.createKeyPair()

        let tx = try (await sourceTxBuilder())
            .sponsoring(sponsorAccount: sponsorKp, buildingFunction: { builder in
                builder.createAccount(newAccount: newKp)
            })
            .build()

        // BeginSponsoring + CreateAccount + EndSponsoring.
        XCTAssertEqual(3, tx.operations.count)

        let begin = try XCTUnwrap(tx.operations[0] as? BeginSponsoringFutureReservesOperation)
        // sponsored account defaults to the tx source account.
        XCTAssertEqual(sourceKp.address, begin.sponsoredId)
        XCTAssertEqual(sponsorKp.address, begin.sourceAccountId)

        let create = try XCTUnwrap(tx.operations[1] as? CreateAccountOperation)
        XCTAssertEqual(newKp.address, create.destination.accountId)
        // created within a sponsorship -> source is the sponsor.
        XCTAssertEqual(sponsorKp.address, create.sourceAccountId)

        let end = try XCTUnwrap(tx.operations[2] as? EndSponsoringFutureReservesOperation)
        XCTAssertEqual(sourceKp.address, end.sourceAccountId)
    }

    func testSponsoringWithExplicitSponsoredAccount() async throws {
        let sponsorKp = wallet.stellar.account.createKeyPair()
        let sponsoredKp = wallet.stellar.account.createKeyPair()

        let tx = try (await sourceTxBuilder())
            .sponsoring(sponsorAccount: sponsorKp,
                        buildingFunction: { builder in
                            builder.addAssetSupport(asset: usdc)
                        },
                        sponsoredAccount: sponsoredKp)
            .build()

        let begin = try XCTUnwrap(tx.operations[0] as? BeginSponsoringFutureReservesOperation)
        XCTAssertEqual(sponsoredKp.address, begin.sponsoredId)
        let trust = try XCTUnwrap(tx.operations[1] as? ChangeTrustOperation)
        XCTAssertEqual(sponsoredKp.address, trust.sourceAccountId)
        let end = try XCTUnwrap(tx.operations[2] as? EndSponsoringFutureReservesOperation)
        XCTAssertEqual(sponsoredKp.address, end.sourceAccountId)
    }

    func testSponsoringBuilderOperationsUseSponsorSource() async throws {
        let sponsorKp = wallet.stellar.account.createKeyPair()
        let signerKp = wallet.stellar.account.createKeyPair()

        let tx = try (await sourceTxBuilder())
            .sponsoring(sponsorAccount: sponsorKp, buildingFunction: { builder in
                _ = builder.addAccountSigner(signerAddress: signerKp, signerWeight: 5)
                _ = builder.setThreshold(low: 1, medium: 1, high: 1)
                return builder.lockAccountMasterKey()
            })
            .build()

        // begin + 3 sponsored ops + end.
        XCTAssertEqual(5, tx.operations.count)
        // All sponsored SetOptions ops have the sponsored account (source account) as their op source.
        let signerOp = try XCTUnwrap(tx.operations[1] as? SetOptionsOperation)
        XCTAssertEqual(sourceKp.address, signerOp.sourceAccountId)
        XCTAssertEqual(UInt32(5), signerOp.signerWeight)
    }

    // MARK: - Stellar.sign / submit

    func testStellarSignTransaction() async throws {
        let tx = try (await sourceTxBuilder())
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        XCTAssertEqual(0, tx.transactionXDR.signatures.count)
        wallet.stellar.sign(tx: tx, keyPair: sourceKp)
        XCTAssertEqual(1, tx.transactionXDR.signatures.count)
    }

    func testSubmitTransactionSuccess() async throws {
        // Use a memo so the SEP-29 memo-required check does not issue a GET to the destination.
        let tx = try (await sourceTxBuilder(memo: stellarsdk.Memo(text: "x")))
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        wallet.stellar.sign(tx: tx, keyPair: sourceKp)

        let envelope = try XCTUnwrap(tx.toEnvelopeXdrBase64())
        let submitMock = StellarUnitSubmitSuccessMock(envelopeXdr: envelope, sourceAccountId: sourceKp.address)
        defer { ServerMock.remove(mock: submitMock.requestMock()) }

        let result = try await wallet.stellar.submitTransaction(signedTransaction: tx)
        XCTAssertTrue(result)
    }

    func testSubmitTransactionFailure() async throws {
        let tx = try (await sourceTxBuilder(memo: stellarsdk.Memo(text: "x")))
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        wallet.stellar.sign(tx: tx, keyPair: sourceKp)

        let failMock = StellarUnitSubmitFailureMock()
        defer { ServerMock.remove(mock: failMock.requestMock()) }

        do {
            _ = try await wallet.stellar.submitTransaction(signedTransaction: tx)
            XCTFail("expected submitTransaction to throw on a 400 response")
        } catch let error as HorizonRequestError {
            guard case .badRequest = error else {
                return XCTFail("expected HorizonRequestError.badRequest, got \(error)")
            }
        }
    }

    func testSubmitWithFeeIncreaseSuccess() async throws {
        // The fee increase path only triggers on a 504 timeout; a direct success is the
        // common case and is what we assert here. The success mock echoes back the posted
        // envelope, so any envelope from this source account is accepted.
        let submitMock = StellarUnitSubmitSuccessMock(envelopeXdr: nil, sourceAccountId: sourceKp.address)
        defer { ServerMock.remove(mock: submitMock.requestMock()) }

        let result = try await wallet.stellar.submitWithFeeIncrease(
            sourceAddress: sourceKp,
            timeout: 180,
            baseFeeIncrease: 100,
            maxBaseFee: 2000,
            buildingFunction: { builder in
                // A memo avoids the SEP-29 destination GET.
                _ = builder.setMemo(memo: (try! stellarsdk.Memo(text: "x"))!)
                return try! builder.transfer(destinationAddress: self.destinationKp.address,
                                             assetId: NativeAssetId(),
                                             amount: Decimal(1))
            })
        XCTAssertTrue(result)
    }

    // MARK: - makeFeeBump / fee bump submit

    func testMakeFeeBump() async throws {
        let inner = try (await sourceTxBuilder(baseFee: 100))
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        wallet.stellar.sign(tx: inner, keyPair: sourceKp)

        let feeAccount = wallet.stellar.account.createKeyPair()
        let feeBump = try wallet.stellar.makeFeeBump(feeAddress: feeAccount, transaction: inner, baseFee: 200)
        XCTAssertEqual(feeAccount.address, feeBump.sourceAccountId)
        // fee = baseFee * (innerOps + 1) = 200 * (1 + 1) = 400.
        XCTAssertEqual(UInt64(400), feeBump.fee)
        XCTAssertEqual(inner.toEnvelopeXdrBase64(), feeBump.innerTransaction.toEnvelopeXdrBase64())
    }

    func testMakeFeeBumpTooLowFeeThrows() async throws {
        let inner = try (await sourceTxBuilder(baseFee: 1000))
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        wallet.stellar.sign(tx: inner, keyPair: sourceKp)

        let feeAccount = wallet.stellar.account.createKeyPair()
        // baseFee 50 -> total 100, which is below the inner transaction fee (1000) -> must throw.
        XCTAssertThrowsError(try wallet.stellar.makeFeeBump(feeAddress: feeAccount, transaction: inner, baseFee: 50)) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected ValidationError.invalidArgument, got \(error)")
            }
        }
    }

    func testSignFeeBumpTransaction() async throws {
        let inner = try (await sourceTxBuilder())
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        wallet.stellar.sign(tx: inner, keyPair: sourceKp)
        let feeAccount = wallet.stellar.account.createKeyPair()
        let feeBump = try wallet.stellar.makeFeeBump(feeAddress: feeAccount, transaction: inner, baseFee: 200)

        XCTAssertEqual(0, try StellarTest.feeBumpSignatureCount(feeBump))
        wallet.stellar.sign(feeBumpTx: feeBump, keyPair: feeAccount)
        XCTAssertEqual(1, try StellarTest.feeBumpSignatureCount(feeBump))
    }

    /// Counts the outer (fee bump) signatures by decoding the encoded envelope.
    private static func feeBumpSignatureCount(_ feeBump: stellarsdk.FeeBumpTransaction) throws -> Int {
        let xdr = try XCTUnwrap(feeBump.toEnvelopeXdrBase64())
        let envelope = try stellarsdk.TransactionEnvelopeXDR(xdr: xdr)
        guard case .feeBump(let feeBumpEnvelope) = envelope else {
            XCTFail("expected fee bump envelope")
            return -1
        }
        return feeBumpEnvelope.signatures.count
    }

    func testSubmitFeeBumpTransactionSuccess() async throws {
        let inner = try (await sourceTxBuilder(memo: stellarsdk.Memo(text: "x")))
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        wallet.stellar.sign(tx: inner, keyPair: sourceKp)
        let feeAccount = wallet.stellar.account.createKeyPair()
        let feeBump = try wallet.stellar.makeFeeBump(feeAddress: feeAccount, transaction: inner, baseFee: 200)
        wallet.stellar.sign(feeBumpTx: feeBump, keyPair: feeAccount)

        // submitFeeBumpTransaction bypasses the SEP-29 check (postTransactionCore), any envelope is accepted.
        let submitMock = StellarUnitSubmitSuccessMock(envelopeXdr: nil, sourceAccountId: feeAccount.address)
        defer { ServerMock.remove(mock: submitMock.requestMock()) }

        let result = try await wallet.stellar.submitTransaction(signedFeeBumpTransaction: feeBump)
        XCTAssertTrue(result)
    }

    // MARK: - decode / encode

    func testDecodeTransaction() async throws {
        let tx = try (await sourceTxBuilder())
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        let xdr = try XCTUnwrap(tx.toEnvelopeXdrBase64())
        let decoded = wallet.stellar.decodeTransaction(xdr: xdr)
        guard case .transaction(let decodedTx) = decoded else {
            return XCTFail("expected a plain transaction decode result")
        }
        XCTAssertEqual(tx.toEnvelopeXdrBase64(), decodedTx.toEnvelopeXdrBase64())
    }

    func testDecodeFeeBumpTransaction() async throws {
        let inner = try (await sourceTxBuilder())
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        wallet.stellar.sign(tx: inner, keyPair: sourceKp)
        let feeAccount = wallet.stellar.account.createKeyPair()
        let feeBump = try wallet.stellar.makeFeeBump(feeAddress: feeAccount, transaction: inner, baseFee: 200)
        wallet.stellar.sign(feeBumpTx: feeBump, keyPair: feeAccount)

        let xdr = try XCTUnwrap(feeBump.toEnvelopeXdrBase64())
        let decoded = wallet.stellar.decodeTransaction(xdr: xdr)
        guard case .feeBumpTransaction(let decodedFeeBump) = decoded else {
            return XCTFail("expected a fee bump transaction decode result")
        }
        XCTAssertEqual(feeAccount.address, decodedFeeBump.sourceAccountId)
        XCTAssertEqual(feeBump.fee, decodedFeeBump.fee)
    }

    func testDecodeInvalidXdr() throws {
        let decoded = wallet.stellar.decodeTransaction(xdr: "not-valid-xdr")
        guard case .invalidXdrErr = decoded else {
            return XCTFail("expected invalidXdrErr for malformed xdr")
        }
    }

    func testTransactionEnvelopeRoundTrip() async throws {
        let tx = try (await sourceTxBuilder())
            .createAccount(newAccount: destinationKp, startingBalance: Decimal(3))
            .build()
        let xdr = try XCTUnwrap(tx.toEnvelopeXdrBase64())
        let rebuilt = try stellarsdk.Transaction(envelopeXdr: xdr)
        XCTAssertEqual(xdr, rebuilt.toEnvelopeXdrBase64())
        XCTAssertEqual(1, rebuilt.operations.count)
    }

    func testFeeBumpTransactionEnvelopeRoundTrip() async throws {
        let inner = try (await sourceTxBuilder())
            .transfer(destinationAddress: destinationKp.address, assetId: NativeAssetId(), amount: Decimal(1))
            .build()
        wallet.stellar.sign(tx: inner, keyPair: sourceKp)
        let feeAccount = wallet.stellar.account.createKeyPair()
        let feeBump = try wallet.stellar.makeFeeBump(feeAddress: feeAccount, transaction: inner, baseFee: 200)
        let xdr = try XCTUnwrap(feeBump.toEnvelopeXdrBase64())
        XCTAssertTrue(xdr.count > 0)
        // round trip through FeeBumpTransactionEnvelopeXDR.
        let envelope = try stellarsdk.TransactionEnvelopeXDR(xdr: xdr)
        guard case .feeBump = envelope else {
            return XCTFail("expected fee bump envelope")
        }
    }

    // MARK: - fundTestNetAccount (Friendbot)

    func testFundTestNetAccountSuccess() async throws {
        let newKp = wallet.stellar.account.createKeyPair()
        let friendbotMock = StellarUnitFriendbotMock(success: true)
        defer { ServerMock.remove(mock: friendbotMock.requestMock()) }
        // Must not throw.
        try await wallet.stellar.fundTestNetAccount(address: newKp.address)
    }

    func testFundTestNetAccountFailure() async throws {
        let newKp = wallet.stellar.account.createKeyPair()
        let friendbotMock = StellarUnitFriendbotMock(success: false)
        defer { ServerMock.remove(mock: friendbotMock.requestMock()) }
        do {
            try await wallet.stellar.fundTestNetAccount(address: newKp.address)
            XCTFail("expected fundTestNetAccount to throw when friendbot returns an error")
        } catch {
            // any thrown error is acceptable; friendbot failures surface as HorizonRequestError.
        }
    }

    // MARK: - Payment path finding

    func testFindStrictSendPathForDestinationAddress() async throws {
        // native -> USDC, single intermediate hop (EUR).
        let mock = StellarUnitPathsMock(
            kind: .strictSend,
            records: [
                StellarUnitPathRecord(
                    sourceAssetType: "native", sourceAssetCode: nil, sourceAssetIssuer: nil, sourceAmount: "100.0000000",
                    destinationAssetType: "credit_alphanum4", destinationAssetCode: "USDC", destinationAssetIssuer: issuerKp.address, destinationAmount: "92.0000000",
                    path: [StellarUnitPathAsset(assetType: "credit_alphanum4", assetCode: "EUR", assetIssuer: issuerKp.address)])
            ])
        defer { ServerMock.remove(mock: mock.requestMock()) }

        let paths = try await wallet.stellar.findStrictSendPathForDestinationAddress(
            destinationAddress: destinationKp.address,
            sourceAssetId: NativeAssetId(),
            sourceAmount: "100")

        XCTAssertEqual(1, paths.count)
        let path = try XCTUnwrap(paths.first)
        XCTAssertEqual("100.0000000", path.sourceAmount)
        XCTAssertEqual("92.0000000", path.destinationAmount)
        XCTAssertEqual("native", path.sourceAsset.id)
        XCTAssertTrue(path.sourceAsset is NativeAssetId)
        let destAsset = try XCTUnwrap(path.destinationAsset as? IssuedAssetId)
        XCTAssertEqual("USDC", destAsset.code)
        XCTAssertEqual(issuerKp.address, destAsset.issuer)
        XCTAssertEqual(1, path.path.count)
        let hop = try XCTUnwrap(path.path.first as? IssuedAssetId)
        XCTAssertEqual("EUR", hop.code)
        XCTAssertEqual(issuerKp.address, hop.issuer)
    }

    func testFindStrictSendPathForDestinationAssets() async throws {
        // Issued source (USDC) -> native destination, empty path. Exercises the issued-asset
        // branch of getAssetParams and the native branch of PaymentPath.fromPathResponse.
        let mock = StellarUnitPathsMock(
            kind: .strictSend,
            records: [
                StellarUnitPathRecord(
                    sourceAssetType: "credit_alphanum4", sourceAssetCode: "USDC", sourceAssetIssuer: issuerKp.address, sourceAmount: "10.0000000",
                    destinationAssetType: "native", destinationAssetCode: nil, destinationAssetIssuer: nil, destinationAmount: "37.5000000",
                    path: [])
            ])
        defer { ServerMock.remove(mock: mock.requestMock()) }

        let paths = try await wallet.stellar.findStrictSendPathForDestinationAssets(
            destinationAssets: [NativeAssetId()],
            sourceAssetId: usdc,
            sourceAmount: "10")

        XCTAssertEqual(1, paths.count)
        let path = try XCTUnwrap(paths.first)
        XCTAssertEqual("10.0000000", path.sourceAmount)
        XCTAssertEqual("37.5000000", path.destinationAmount)
        let sourceAsset = try XCTUnwrap(path.sourceAsset as? IssuedAssetId)
        XCTAssertEqual("USDC", sourceAsset.code)
        XCTAssertTrue(path.destinationAsset is NativeAssetId)
        XCTAssertTrue(path.path.isEmpty)
    }

    func testFindStrictReceivePathForSourceAddress() async throws {
        // Two records: one with a 12-char alphanum source hop, one direct.
        let mock = StellarUnitPathsMock(
            kind: .strictReceive,
            records: [
                StellarUnitPathRecord(
                    sourceAssetType: "credit_alphanum12", sourceAssetCode: "LONGASSET12", sourceAssetIssuer: issuerKp.address, sourceAmount: "55.0000000",
                    destinationAssetType: "credit_alphanum4", destinationAssetCode: "USDC", destinationAssetIssuer: issuerKp.address, destinationAmount: "50.0000000",
                    path: [StellarUnitPathAsset(assetType: "native", assetCode: nil, assetIssuer: nil)]),
                StellarUnitPathRecord(
                    sourceAssetType: "native", sourceAssetCode: nil, sourceAssetIssuer: nil, sourceAmount: "60.0000000",
                    destinationAssetType: "credit_alphanum4", destinationAssetCode: "USDC", destinationAssetIssuer: issuerKp.address, destinationAmount: "50.0000000",
                    path: [])
            ])
        defer { ServerMock.remove(mock: mock.requestMock()) }

        let paths = try await wallet.stellar.findStrictReceivePathForSourceAddress(
            sourceAddress: sourceKp.address,
            destinationAssetId: usdc,
            destinationAmount: "50")

        XCTAssertEqual(2, paths.count)

        let first = paths[0]
        let firstSource = try XCTUnwrap(first.sourceAsset as? IssuedAssetId)
        XCTAssertEqual("LONGASSET12", firstSource.code)
        XCTAssertEqual("55.0000000", first.sourceAmount)
        XCTAssertEqual("50.0000000", first.destinationAmount)
        XCTAssertEqual(1, first.path.count)
        XCTAssertTrue(first.path.first is NativeAssetId)

        let second = paths[1]
        XCTAssertTrue(second.sourceAsset is NativeAssetId)
        XCTAssertEqual("60.0000000", second.sourceAmount)
        XCTAssertTrue(second.path.isEmpty)
    }

    func testFindStrictReceivePathForSourceAssets() async throws {
        // Mixed source asset list (native + issued) exercises encodeAssets joining.
        let mock = StellarUnitPathsMock(
            kind: .strictReceive,
            records: [
                StellarUnitPathRecord(
                    sourceAssetType: "native", sourceAssetCode: nil, sourceAssetIssuer: nil, sourceAmount: "12.3456789",
                    destinationAssetType: "credit_alphanum4", destinationAssetCode: "USDC", destinationAssetIssuer: issuerKp.address, destinationAmount: "10.0000000",
                    path: [])
            ])
        defer { ServerMock.remove(mock: mock.requestMock()) }

        let eur = try IssuedAssetId(code: "EUR", issuer: issuerKp.address)
        let paths = try await wallet.stellar.findStrictReceivePathForSourceAssets(
            sourceAssets: [NativeAssetId(), eur],
            destinationAssetId: usdc,
            destinationAmount: "10")

        XCTAssertEqual(1, paths.count)
        let path = try XCTUnwrap(paths.first)
        XCTAssertEqual("12.3456789", path.sourceAmount)
        XCTAssertEqual("10.0000000", path.destinationAmount)
        XCTAssertTrue(path.sourceAsset is NativeAssetId)
        let destAsset = try XCTUnwrap(path.destinationAsset as? IssuedAssetId)
        XCTAssertEqual("USDC", destAsset.code)
    }

    func testFindStrictSendPathReturnsEmptyWhenNoRecords() async throws {
        let mock = StellarUnitPathsMock(kind: .strictSend, records: [])
        defer { ServerMock.remove(mock: mock.requestMock()) }

        let paths = try await wallet.stellar.findStrictSendPathForDestinationAddress(
            destinationAddress: destinationKp.address,
            sourceAssetId: NativeAssetId(),
            sourceAmount: "100")
        XCTAssertTrue(paths.isEmpty)
    }

    func testFindStrictSendPathPropagatesHorizonError() async throws {
        // A 400 response on the path endpoint must surface as a thrown HorizonRequestError.
        let mock = StellarUnitPathsErrorMock(kind: .strictSend)
        defer { ServerMock.remove(mock: mock.requestMock()) }

        do {
            _ = try await wallet.stellar.findStrictSendPathForDestinationAddress(
                destinationAddress: destinationKp.address,
                sourceAssetId: NativeAssetId(),
                sourceAmount: "100")
            XCTFail("expected findStrictSendPath to throw on a 400 response")
        } catch is HorizonRequestError {
            // expected
        }
    }

    func testPaymentPathInitStoresValues() throws {
        // Direct construction of the public PaymentPath model.
        let eur = try IssuedAssetId(code: "EUR", issuer: issuerKp.address)
        let path = PaymentPath(sourceAmount: "1.0000000",
                               sourceAsset: NativeAssetId(),
                               destinationAmount: "2.0000000",
                               destinationAsset: usdc,
                               path: [eur])
        XCTAssertEqual("1.0000000", path.sourceAmount)
        XCTAssertEqual("2.0000000", path.destinationAmount)
        XCTAssertTrue(path.sourceAsset is NativeAssetId)
        XCTAssertEqual("USDC", (path.destinationAsset as? IssuedAssetId)?.code)
        XCTAssertEqual(1, path.path.count)
        XCTAssertEqual("EUR", (path.path.first as? IssuedAssetId)?.code)
    }

    // MARK: - util

    /// Returns the G... account id for an ed25519 signer key, or nil for other signer kinds.
    static func ed25519AccountId(_ key: SignerKeyXDR) -> String? {
        switch key {
        case .ed25519(let data):
            return try? PublicKey([UInt8](data.wrapped)).accountId
        default:
            return nil
        }
    }
}

// MARK: - Mocks

struct StellarUnitHorizonSigner {
    let key: String
    let weight: Int
}

/// Mocks GET https://horizon-testnet.stellar.org/accounts/{accountId} returning a fixed,
/// valid Horizon AccountResponse. Unregistered account ids are served a 404 by the
/// wildcard fallback (StellarUnitHorizonNotFoundMock), registered last.
class StellarUnitHorizonAccountMock: ResponsesMock {
    let accountId: String
    let sequence: String
    let signers: [StellarUnitHorizonSigner]

    init(accountId: String, sequence: String, signers: [StellarUnitHorizonSigner]) {
        self.accountId = accountId
        self.sequence = sequence
        self.signers = signers
        super.init()
    }

    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            mock.statusCode = 200
            return self.accountJson()
        }
        return RequestMock(host: StellarTest.horizonHost,
                           path: "/accounts/\(accountId)",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    private func accountJson() -> String {
        let signersJson = signers.map { signer in
            """
            {
              "weight": \(signer.weight),
              "key": "\(signer.key)",
              "type": "ed25519_public_key"
            }
            """
        }.joined(separator: ",")

        return """
        {
          "_links": {
            "self": { "href": "https://\(StellarTest.horizonHost)/accounts/\(accountId)" },
            "transactions": { "href": "https://\(StellarTest.horizonHost)/accounts/\(accountId)/transactions{?cursor,limit,order}", "templated": true },
            "operations": { "href": "https://\(StellarTest.horizonHost)/accounts/\(accountId)/operations{?cursor,limit,order}", "templated": true },
            "payments": { "href": "https://\(StellarTest.horizonHost)/accounts/\(accountId)/payments{?cursor,limit,order}", "templated": true },
            "effects": { "href": "https://\(StellarTest.horizonHost)/accounts/\(accountId)/effects{?cursor,limit,order}", "templated": true },
            "offers": { "href": "https://\(StellarTest.horizonHost)/accounts/\(accountId)/offers{?cursor,limit,order}", "templated": true },
            "trades": { "href": "https://\(StellarTest.horizonHost)/accounts/\(accountId)/trades{?cursor,limit,order}", "templated": true },
            "data": { "href": "https://\(StellarTest.horizonHost)/accounts/\(accountId)/data/{key}", "templated": true }
          },
          "id": "\(accountId)",
          "account_id": "\(accountId)",
          "sequence": "\(sequence)",
          "subentry_count": 0,
          "last_modified_ledger": 985731,
          "last_modified_time": "2024-01-01T00:00:00Z",
          "thresholds": {
            "low_threshold": 0,
            "med_threshold": 0,
            "high_threshold": 0
          },
          "flags": {
            "auth_required": false,
            "auth_revocable": false,
            "auth_immutable": false,
            "auth_clawback_enabled": false
          },
          "balances": [
            {
              "balance": "10000.0000000",
              "buying_liabilities": "0.0000000",
              "selling_liabilities": "0.0000000",
              "asset_type": "native"
            }
          ],
          "signers": [
            \(signersJson)
          ],
          "data": {},
          "num_sponsoring": 0,
          "num_sponsored": 0,
          "paging_token": "\(accountId)"
        }
        """
    }
}

/// Wildcard fallback: any /accounts/* GET not matched by a specific account mock
/// returns a Horizon 404 notFound. Registered last (in setUp).
class StellarUnitHorizonNotFoundMock: ResponsesMock {
    override func requestMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            mock.statusCode = 404
            return self?.resourceMissingResponse()
        }
        return RequestMock(host: StellarTest.horizonHost,
                           path: "/accounts/*",
                           httpMethod: "GET",
                           mockHandler: handler)
    }
}

/// Mocks POST https://horizon-testnet.stellar.org/transactions returning a successful
/// SubmitTransactionResponse. If envelopeXdr is given it is echoed back, otherwise the
/// posted envelope is decoded from the request body so the response stays self consistent.
class StellarUnitSubmitSuccessMock: ResponsesMock {
    let envelopeXdr: String?
    let sourceAccountId: String
    private var sharedMock: RequestMock?

    /// txSUCCESS TransactionResult (fee_charged 100, one op_inner payment success).
    static let resultXdr = "AAAAAAAAAGQAAAAAAAAAAQAAAAAAAAABAAAAAAAAAAA="

    init(envelopeXdr: String?, sourceAccountId: String) {
        self.envelopeXdr = envelopeXdr
        self.sourceAccountId = sourceAccountId
        super.init()
    }

    override func requestMock() -> RequestMock {
        if let existing = sharedMock {
            return existing
        }
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            mock.statusCode = 200
            let envelope = self.envelopeXdr ?? self.envelopeFrom(request: request) ?? ""
            return self.submitJson(envelope: envelope)
        }
        let mock = RequestMock(host: StellarTest.horizonHost,
                               path: "/transactions",
                               httpMethod: "POST",
                               mockHandler: handler)
        sharedMock = mock
        return mock
    }

    /// Extracts the tx= envelope from the urlencoded POST body.
    private func envelopeFrom(request: URLRequest) -> String? {
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            body = stream.readfully()
        }
        guard let data = body, let str = String(data: data, encoding: .utf8) else { return nil }
        guard let range = str.range(of: "tx=") else { return nil }
        let encoded = String(str[range.upperBound...])
        return encoded.removingPercentEncoding
    }

    private func submitJson(envelope: String) -> String {
        return """
        {
          "_links": {
            "self": { "href": "https://\(StellarTest.horizonHost)/transactions/abc" },
            "account": { "href": "https://\(StellarTest.horizonHost)/accounts/\(sourceAccountId)" },
            "ledger": { "href": "https://\(StellarTest.horizonHost)/ledgers/100" },
            "operations": { "href": "https://\(StellarTest.horizonHost)/transactions/abc/operations{?cursor,limit,order}", "templated": true },
            "effects": { "href": "https://\(StellarTest.horizonHost)/transactions/abc/effects{?cursor,limit,order}", "templated": true },
            "precedes": { "href": "https://\(StellarTest.horizonHost)/transactions?order=asc&cursor=1" },
            "succeeds": { "href": "https://\(StellarTest.horizonHost)/transactions?order=desc&cursor=1" }
          },
          "id": "f1e2d3c4b5a6978889aabbccddeeff00112233445566778899aabbccddeeff00",
          "paging_token": "429496729600",
          "successful": true,
          "hash": "f1e2d3c4b5a6978889aabbccddeeff00112233445566778899aabbccddeeff00",
          "ledger": 100,
          "created_at": "2024-01-01T00:00:00Z",
          "source_account": "\(sourceAccountId)",
          "source_account_sequence": "4233721387843586",
          "fee_account": "\(sourceAccountId)",
          "fee_charged": "100",
          "max_fee": "100",
          "operation_count": 1,
          "envelope_xdr": "\(envelope)",
          "result_xdr": "\(StellarUnitSubmitSuccessMock.resultXdr)",
          "memo_type": "none",
          "signatures": []
        }
        """
    }
}

/// Mocks POST https://horizon-testnet.stellar.org/transactions returning a 400 bad request.
class StellarUnitSubmitFailureMock: ResponsesMock {
    private var sharedMock: RequestMock?

    override func requestMock() -> RequestMock {
        if let existing = sharedMock {
            return existing
        }
        let handler: MockHandler = { mock, request in
            mock.statusCode = 400
            return """
            {
              "type": "https://stellar.org/horizon-errors/transaction_failed",
              "title": "Transaction Failed",
              "status": 400,
              "detail": "The transaction failed when submitted to the stellar network.",
              "extras": {
                "envelope_xdr": "",
                "result_codes": {
                  "transaction": "tx_failed",
                  "operations": ["op_underfunded"]
                },
                "result_xdr": "AAAAAAAAAGT/////AAAAAQAAAAAAAAAB////+wAAAAA="
              }
            }
            """
        }
        let mock = RequestMock(host: StellarTest.horizonHost,
                               path: "/transactions",
                               httpMethod: "POST",
                               mockHandler: handler)
        sharedMock = mock
        return mock
    }
}

/// Mocks GET https://horizon-testnet.stellar.org/friendbot returning either a success body
/// or a 400 error body.
class StellarUnitFriendbotMock: ResponsesMock {
    let success: Bool
    private var sharedMock: RequestMock?

    init(success: Bool) {
        self.success = success
        super.init()
    }

    override func requestMock() -> RequestMock {
        if let existing = sharedMock {
            return existing
        }
        let handler: MockHandler = { [weak self] mock, request in
            guard let self = self else { return nil }
            if self.success {
                mock.statusCode = 200
                return """
                {
                  "hash": "f1e2d3c4b5a6978889aabbccddeeff00112233445566778899aabbccddeeff00",
                  "ledger": 100
                }
                """
            } else {
                // createTestAccount ignores the HTTP status and only fails if the body
                // is not valid JSON, so the error body must be non-JSON to exercise the
                // failure branch of fundTestNetAccount.
                mock.statusCode = 400
                mock.contentType = "text/plain"
                return "account already exists"
            }
        }
        let mock = RequestMock(host: StellarTest.horizonHost,
                               path: "/friendbot",
                               httpMethod: "GET",
                               mockHandler: handler)
        sharedMock = mock
        return mock
    }
}

// MARK: - Payment path mocks

enum StellarUnitPathKind {
    case strictSend
    case strictReceive

    var path: String {
        switch self {
        case .strictSend: return "/paths/strict-send"
        case .strictReceive: return "/paths/strict-receive"
        }
    }
}

/// One intermediate asset entry in the `path` array of a payment path record.
struct StellarUnitPathAsset {
    let assetType: String
    let assetCode: String?
    let assetIssuer: String?
}

/// A single FindPaymentPaths record (one `_embedded.records` entry).
struct StellarUnitPathRecord {
    let sourceAssetType: String
    let sourceAssetCode: String?
    let sourceAssetIssuer: String?
    let sourceAmount: String
    let destinationAssetType: String
    let destinationAssetCode: String?
    let destinationAssetIssuer: String?
    let destinationAmount: String
    let path: [StellarUnitPathAsset]
}

/// Mocks GET https://horizon-testnet.stellar.org/paths/strict-send|strict-receive returning a
/// valid FindPaymentPathsResponse (records wrapped in `_embedded`). Field names follow the
/// Horizon payment-path response schema (source_asset_*, destination_asset_*, path[]).
class StellarUnitPathsMock: ResponsesMock {
    let kind: StellarUnitPathKind
    let records: [StellarUnitPathRecord]
    private var sharedMock: RequestMock?

    init(kind: StellarUnitPathKind, records: [StellarUnitPathRecord]) {
        self.kind = kind
        self.records = records
        super.init()
    }

    override func requestMock() -> RequestMock {
        if let existing = sharedMock {
            return existing
        }
        let handler: MockHandler = { [weak self] mock, _ in
            guard let self = self else { return nil }
            mock.statusCode = 200
            return self.pathsJson()
        }
        let mock = RequestMock(host: StellarTest.horizonHost,
                               path: kind.path,
                               httpMethod: "GET",
                               mockHandler: handler)
        sharedMock = mock
        return mock
    }

    private func assetJson(type: String, code: String?, issuer: String?) -> String {
        if type == "native" {
            return "\"asset_type\": \"native\""
        }
        return """
        "asset_type": "\(type)",
        "asset_code": "\(code ?? "")",
        "asset_issuer": "\(issuer ?? "")"
        """
    }

    private func recordJson(_ record: StellarUnitPathRecord) -> String {
        let pathItems = record.path.map { item in
            "{ \(self.assetJson(type: item.assetType, code: item.assetCode, issuer: item.assetIssuer)) }"
        }.joined(separator: ",\n")

        var fields: [String] = []
        // source asset fields
        fields.append("\"source_asset_type\": \"\(record.sourceAssetType)\"")
        if record.sourceAssetType != "native" {
            fields.append("\"source_asset_code\": \"\(record.sourceAssetCode ?? "")\"")
            fields.append("\"source_asset_issuer\": \"\(record.sourceAssetIssuer ?? "")\"")
        }
        fields.append("\"source_amount\": \"\(record.sourceAmount)\"")
        // destination asset fields
        fields.append("\"destination_asset_type\": \"\(record.destinationAssetType)\"")
        if record.destinationAssetType != "native" {
            fields.append("\"destination_asset_code\": \"\(record.destinationAssetCode ?? "")\"")
            fields.append("\"destination_asset_issuer\": \"\(record.destinationAssetIssuer ?? "")\"")
        }
        fields.append("\"destination_amount\": \"\(record.destinationAmount)\"")
        fields.append("\"path\": [\(pathItems)]")

        return "{\n\(fields.joined(separator: ",\n"))\n}"
    }

    private func pathsJson() -> String {
        let recordsJson = records.map { recordJson($0) }.joined(separator: ",\n")
        return """
        {
          "_embedded": {
            "records": [
              \(recordsJson)
            ]
          }
        }
        """
    }
}

/// Mocks the payment path endpoints returning a 400 bad request.
class StellarUnitPathsErrorMock: ResponsesMock {
    let kind: StellarUnitPathKind
    private var sharedMock: RequestMock?

    init(kind: StellarUnitPathKind) {
        self.kind = kind
        super.init()
    }

    override func requestMock() -> RequestMock {
        if let existing = sharedMock {
            return existing
        }
        let handler: MockHandler = { mock, _ in
            mock.statusCode = 400
            return """
            {
              "type": "https://stellar.org/horizon-errors/bad_request",
              "title": "Bad Request",
              "status": 400,
              "detail": "The request you sent was invalid in some way."
            }
            """
        }
        let mock = RequestMock(host: StellarTest.horizonHost,
                               path: kind.path,
                               httpMethod: "GET",
                               mockHandler: handler)
        sharedMock = mock
        return mock
    }
}
