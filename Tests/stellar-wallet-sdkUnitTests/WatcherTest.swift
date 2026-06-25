//
//  WatcherTest.swift
//
//
//  Offline unit tests covering the Watcher infrastructure of the wallet sdk:
//  WalletExceptionHandler / RetryContext, StatusUpdateEvent and Watcher
//  (construction + result lifecycle, no network polling).
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class WatcherTest: XCTestCase {

    let wallet = Wallet.testNet

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    // MARK: - WalletExceptionHandler / RetryContext

    func testRetryContextOnErrorAndRefresh() {
        let ctx = RetryContext()
        XCTAssertEqual(0, ctx.retries)
        XCTAssertNil(ctx.error)

        struct WatcherTestDummyError: Error {}
        ctx.onError(e: WatcherTestDummyError())
        XCTAssertEqual(1, ctx.retries)
        XCTAssertNotNil(ctx.error)

        ctx.onError(e: WatcherTestDummyError())
        XCTAssertEqual(2, ctx.retries)

        ctx.refresh()
        XCTAssertEqual(0, ctx.retries)
        XCTAssertNil(ctx.error)
    }

    func testRetryExceptionHandlerRetriesThenGivesUp() async {
        // backoffPeriod is intentionally tiny to keep this offline test fast.
        let handler = RetryExceptionHandler(maxRetryCount: 2, backoffPeriod: 0.001)
        let ctx = RetryContext()

        struct WatcherTestDummyError: Error {}

        // retries < maxRetryCount -> false (keep retrying)
        ctx.onError(e: WatcherTestDummyError()) // retries == 1
        let shouldExit1 = await handler.invoke(ctx: ctx)
        XCTAssertFalse(shouldExit1)

        ctx.onError(e: WatcherTestDummyError()) // retries == 2 == maxRetryCount
        let shouldExit2 = await handler.invoke(ctx: ctx)
        XCTAssertTrue(shouldExit2, "once retries reaches maxRetryCount the handler gives up")
    }

    func testRetryExceptionHandlerDefaults() {
        let handler = RetryExceptionHandler()
        XCTAssertEqual(3, handler.maxRetryCount)
        XCTAssertEqual(5.0, handler.backoffPeriod)
    }

    // MARK: - StatusUpdateEvent

    func testStatusChangeTerminalAndError() {
        let completedTx = AnchorTransaction(id: "tx1", transactionStatus: .completed)
        let change = StatusChange(transaction: completedTx,
                                  status: .completed,
                                  oldStatus: .pendingAnchor)
        XCTAssertTrue(change.isTerminal())
        XCTAssertFalse(change.isError())
        XCTAssertEqual(.completed, change.status)
        XCTAssertEqual(.pendingAnchor, change.oldStatus)
        XCTAssertTrue(change.transaction === completedTx)
    }

    func testStatusChangeErrorStatus() {
        let errorTx = AnchorTransaction(id: "tx2", transactionStatus: .error, message: "boom")
        let change = StatusChange(transaction: errorTx, status: .error)
        XCTAssertTrue(change.isError())
        XCTAssertTrue(change.isTerminal())
        XCTAssertNil(change.oldStatus)
        XCTAssertEqual("boom", change.transaction.message)
    }

    func testStatusChangeNonTerminal() {
        let pendingTx = AnchorTransaction(id: "tx3", transactionStatus: .pendingUser)
        let change = StatusChange(transaction: pendingTx, status: .pendingUser)
        XCTAssertFalse(change.isTerminal())
        XCTAssertFalse(change.isError())
    }

    func testExceptionHandlerExitAndNotificationsClosedAreEvents() {
        let exit: StatusUpdateEvent = ExceptionHandlerExit()
        let closed: StatusUpdateEvent = NotificationsClosed()
        XCTAssertTrue(exit is ExceptionHandlerExit)
        XCTAssertTrue(closed is NotificationsClosed)
    }

    // MARK: - Watcher (construction + result lifecycle, no network polling)

    func testWatcherConstructionViaSep24() {
        let anchor = wallet.anchor(homeDomain: "watcher.watchertest.example")
        let handler = RetryExceptionHandler(maxRetryCount: 1, backoffPeriod: 0.001)
        let watcher = anchor.sep24.watcher(pollDelay: 1.0, exceptionHandler: handler)
        XCTAssertEqual(1.0, watcher.pollDelay)
        XCTAssertTrue(watcher.exceptionHandler is RetryExceptionHandler)
        XCTAssertTrue(watcher.anchor === anchor)
    }

    func testWatcherConstructionViaSep6() {
        let anchor = wallet.anchor(homeDomain: "watcher6.watchertest.example")
        let watcher = anchor.sep6.watcher(pollDelay: 2.0)
        XCTAssertEqual(2.0, watcher.pollDelay)
        XCTAssertTrue(watcher.anchor === anchor)
    }

    func testWatcherResultStopInvalidatesTimer() {
        // Build a timer that won't fire (huge interval) and wrap it in a WatcherResult.
        let timer = Timer(timeInterval: 10000, repeats: true) { _ in }
        let result = WatcherResult(notificationName: Notification.Name("watchertest_test"), timer: timer)
        XCTAssertTrue(result.timer.isValid)
        result.stop()
        XCTAssertFalse(result.timer.isValid)
        // Calling stop again on an invalid timer must be a no-op.
        result.stop()
        XCTAssertFalse(result.timer.isValid)
    }

    // MARK: - Watcher: watchOneTransaction / watchAsset result lifecycle

    func testWatchOneTransactionResult() throws {
        let anchor = wallet.anchor(homeDomain: WatchResultUtils.anchorDomain)
        // Large poll delay so the timer never fires within the test; no network occurs.
        let watcher = anchor.sep24.watcher(pollDelay: 3600)
        let token = try AuthToken(jwt: WatchResultUtils.jwt)

        let result = watcher.watchOneTransaction(authToken: token, id: "example-tx-1")
        XCTAssertEqual(Notification.Name("tx_example-tx-1"), result.notificationName)
        XCTAssertTrue(result.timer.isValid)

        result.stop()
        XCTAssertFalse(result.timer.isValid)
    }

    func testWatchAssetResult() throws {
        let anchor = wallet.anchor(homeDomain: WatchResultUtils.anchorDomain)
        let watcher = anchor.sep6.watcher(pollDelay: 3600)
        let token = try AuthToken(jwt: WatchResultUtils.jwt)

        let result = watcher.watchAsset(authToken: token, asset: WatchResultUtils.usdcAsset)
        XCTAssertEqual(Notification.Name("txs_\(WatchResultUtils.usdcAsset.id)"), result.notificationName)
        XCTAssertTrue(result.timer.isValid)

        result.stop()
        XCTAssertFalse(result.timer.isValid)
    }
}

/// Constants for the watcher result-lifecycle tests, prefixed to avoid collisions
/// with names used elsewhere in the test target.
final class WatchResultUtils {

    static let anchorDomain = "anchor.examplewatcher.example"

    static let usdcIssuer = "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
    static let usdcAsset = try! IssuedAssetId(code: "USDC", issuer: usdcIssuer)

    /// A structurally valid JWT (header.payload.signature) used to build an AuthToken
    /// directly for the watcher tests without performing SEP-10 auth.
    /// Header: {"alg":"HS256","typ":"JWT"}
    /// Payload: {"iss":"https://issuer.example","sub":"GABC:def:1234","iat":1700000000,"exp":1700003600,"client_domain":"client.example"}
    static let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlIiwic3ViIjoiR0FCQzpkZWY6MTIzNCIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAzNjAwLCJjbGllbnRfZG9tYWluIjoiY2xpZW50LmV4YW1wbGUifQ.c2lnbmF0dXJlc2VnbWVudA"
}
