//
//  MemoTest.swift
//
//
//  Offline unit tests covering the MemoType model type of the wallet sdk.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

final class MemoTest: XCTestCase {

    func testMemoTypeRawValues() {
        XCTAssertEqual("text", MemoType.text.rawValue)
        XCTAssertEqual("hash", MemoType.hash.rawValue)
        XCTAssertEqual("id", MemoType.id.rawValue)
        XCTAssertEqual(.text, MemoType(rawValue: "text"))
        XCTAssertEqual(.hash, MemoType(rawValue: "hash"))
        XCTAssertEqual(.id, MemoType(rawValue: "id"))
        XCTAssertNil(MemoType(rawValue: "unknown"))
    }
}
