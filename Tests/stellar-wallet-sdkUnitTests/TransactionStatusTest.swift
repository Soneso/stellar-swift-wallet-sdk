//
//  TransactionStatusTest.swift
//
//
//  Offline unit tests covering the TransactionStatus and TransactionKind
//  model types of the wallet sdk.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class TransactionStatusTest: XCTestCase {

    // MARK: - TransactionStatus

    func testTransactionStatusRawValues() {
        XCTAssertEqual(.incomplete, TransactionStatus(rawValue: "incomplete"))
        XCTAssertEqual(.pendingUserTransferStart, TransactionStatus(rawValue: "pending_user_transfer_start"))
        XCTAssertEqual(.completed, TransactionStatus(rawValue: "completed"))
        XCTAssertEqual(.pendingCustomerInfoUpdate, TransactionStatus(rawValue: "pending_customer_info_update"))
        XCTAssertNil(TransactionStatus(rawValue: "does_not_exist"))
    }

    func testTransactionStatusIsError() {
        XCTAssertTrue(TransactionStatus.error.isError())
        XCTAssertTrue(TransactionStatus.noMarket.isError())
        XCTAssertTrue(TransactionStatus.tooLarge.isError())
        XCTAssertTrue(TransactionStatus.tooSmall.isError())

        XCTAssertFalse(TransactionStatus.completed.isError())
        XCTAssertFalse(TransactionStatus.refunded.isError())
        XCTAssertFalse(TransactionStatus.pendingAnchor.isError())
        XCTAssertFalse(TransactionStatus.incomplete.isError())
    }

    func testTransactionStatusIsTerminal() {
        XCTAssertTrue(TransactionStatus.completed.isTerminal())
        XCTAssertTrue(TransactionStatus.refunded.isTerminal())
        XCTAssertTrue(TransactionStatus.expired.isTerminal())
        XCTAssertTrue(TransactionStatus.error.isTerminal())
        XCTAssertTrue(TransactionStatus.noMarket.isTerminal())
        XCTAssertTrue(TransactionStatus.tooLarge.isTerminal())
        XCTAssertTrue(TransactionStatus.tooSmall.isTerminal())

        XCTAssertFalse(TransactionStatus.incomplete.isTerminal())
        XCTAssertFalse(TransactionStatus.pendingAnchor.isTerminal())
        XCTAssertFalse(TransactionStatus.pendingUser.isTerminal())
        XCTAssertFalse(TransactionStatus.pendingStellar.isTerminal())
    }

    // MARK: - TransactionKind

    func testTransactionKindRawValues() {
        XCTAssertEqual("deposit", TransactionKind.deposit.rawValue)
        XCTAssertEqual("withdrawal", TransactionKind.withdrawal.rawValue)
        XCTAssertEqual("deposit-exchange", TransactionKind.depositExchange.rawValue)
        XCTAssertEqual("withdrawal-exchange", TransactionKind.withdrawalExchange.rawValue)
        XCTAssertEqual(.deposit, TransactionKind(rawValue: "deposit"))
        XCTAssertEqual(.withdrawalExchange, TransactionKind(rawValue: "withdrawal-exchange"))
        XCTAssertNil(TransactionKind(rawValue: "swap"))
    }
}
