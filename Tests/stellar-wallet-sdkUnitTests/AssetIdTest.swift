//
//  AssetIdTest.swift
//
//
//  Offline unit tests covering the AssetId model types of the wallet sdk:
//  NativeAssetId, IssuedAssetId, FiatAssetId and the StellarAssetId factory helpers.
//

import XCTest
import stellarsdk
@testable import stellar_wallet_sdk

/// Test fixtures namespaced with the AssetIdTest prefix to avoid collisions with other suites.
final class AssetIdTestUtils {
    static let issuer = "GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN"
    static let otherIssuer = "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
}

final class AssetIdTest: XCTestCase {

    func testNativeAssetId() {
        let native = NativeAssetId()
        XCTAssertEqual("native", native.id)
        XCTAssertEqual("stellar", native.scheme)
        XCTAssertEqual("stellar:native", native.sep38)

        let asset = native.toAsset()
        XCTAssertEqual(AssetType.ASSET_TYPE_NATIVE, asset.type)
    }

    func testIssuedAssetIdValid() throws {
        let issued = try IssuedAssetId(code: "USDC", issuer: AssetIdTestUtils.issuer)
        XCTAssertEqual("USDC", issued.code)
        XCTAssertEqual(AssetIdTestUtils.issuer, issued.issuer)
        XCTAssertEqual("USDC:\(AssetIdTestUtils.issuer)", issued.id)
        XCTAssertEqual("stellar", issued.scheme)
        XCTAssertEqual("stellar:USDC:\(AssetIdTestUtils.issuer)", issued.sep38)

        // toAsset round trips into an ALPHANUM4 credit asset.
        let asset = issued.toAsset()
        XCTAssertEqual(AssetType.ASSET_TYPE_CREDIT_ALPHANUM4, asset.type)
        XCTAssertEqual("USDC", asset.code)
        XCTAssertEqual(AssetIdTestUtils.issuer, asset.issuer?.accountId)
    }

    func testIssuedAssetIdAlphanum12() throws {
        let issued = try IssuedAssetId(code: "LONGASSET12", issuer: AssetIdTestUtils.issuer)
        XCTAssertEqual("LONGASSET12", issued.code)
        let asset = issued.toAsset()
        XCTAssertEqual(AssetType.ASSET_TYPE_CREDIT_ALPHANUM12, asset.type)
        XCTAssertEqual("LONGASSET12", asset.code)
    }

    func testIssuedAssetIdTrimsCode() throws {
        let issued = try IssuedAssetId(code: "  USDC  ", issuer: AssetIdTestUtils.issuer)
        XCTAssertEqual("USDC", issued.code)
        XCTAssertEqual("USDC:\(AssetIdTestUtils.issuer)", issued.id)
    }

    func testIssuedAssetIdEmptyCodeThrows() {
        XCTAssertThrowsError(try IssuedAssetId(code: "   ", issuer: AssetIdTestUtils.issuer)) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testIssuedAssetIdTooLongCodeThrows() {
        XCTAssertThrowsError(try IssuedAssetId(code: "THIRTEENCHARS", issuer: AssetIdTestUtils.issuer)) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testIssuedAssetIdInvalidIssuerThrows() {
        XCTAssertThrowsError(try IssuedAssetId(code: "USDC", issuer: "NOT_AN_ACCOUNT_ID")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testFiatAssetId() {
        let fiat = FiatAssetId(id: "USD")
        XCTAssertEqual("USD", fiat.id)
        XCTAssertEqual("iso4217", fiat.scheme)
        XCTAssertEqual("iso4217:USD", fiat.sep38)
    }

    func testStellarAssetIdEqualityAndHash() throws {
        let a = try IssuedAssetId(code: "USDC", issuer: AssetIdTestUtils.issuer)
        let b = try IssuedAssetId(code: "USDC", issuer: AssetIdTestUtils.issuer)
        let c = try IssuedAssetId(code: "USDC", issuer: AssetIdTestUtils.otherIssuer)
        let native = NativeAssetId()

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a as StellarAssetId, native as StellarAssetId)

        var set = Set<StellarAssetId>()
        set.insert(a)
        set.insert(b)
        set.insert(c)
        // a and b are equal so the set holds only two distinct entries.
        XCTAssertEqual(2, set.count)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testFromAssetNative() throws {
        let nativeAsset = Asset(type: AssetType.ASSET_TYPE_NATIVE)!
        let result = try StellarAssetId.fromAsset(asset: nativeAsset)
        XCTAssertTrue(result is NativeAssetId)
        XCTAssertEqual("native", result.id)
    }

    func testFromAssetAlphanum4() throws {
        let issuerKp = try KeyPair(accountId: AssetIdTestUtils.issuer)
        let asset = Asset(type: AssetType.ASSET_TYPE_CREDIT_ALPHANUM4, code: "USDC", issuer: issuerKp)!
        let result = try StellarAssetId.fromAsset(asset: asset)
        XCTAssertTrue(result is IssuedAssetId)
        XCTAssertEqual("USDC:\(AssetIdTestUtils.issuer)", result.id)
    }

    func testFromAssetAlphanum12() throws {
        let issuerKp = try KeyPair(accountId: AssetIdTestUtils.issuer)
        let asset = Asset(type: AssetType.ASSET_TYPE_CREDIT_ALPHANUM12, code: "LONGASSET12", issuer: issuerKp)!
        let result = try StellarAssetId.fromAsset(asset: asset)
        XCTAssertTrue(result is IssuedAssetId)
        XCTAssertEqual("LONGASSET12:\(AssetIdTestUtils.issuer)", result.id)
    }

    func testFromAssetDataNative() throws {
        let result = try StellarAssetId.fromAssetData(type: "native")
        XCTAssertTrue(result is NativeAssetId)
        XCTAssertEqual("native", result.id)
    }

    func testFromAssetDataAlphanum4() throws {
        let result = try StellarAssetId.fromAssetData(type: "credit_alphanum4",
                                                      code: "USDC",
                                                      issuerAccountId: AssetIdTestUtils.issuer)
        XCTAssertTrue(result is IssuedAssetId)
        XCTAssertEqual("USDC:\(AssetIdTestUtils.issuer)", result.id)
    }

    func testFromAssetDataAlphanum12() throws {
        let result = try StellarAssetId.fromAssetData(type: "credit_alphanum12",
                                                      code: "LONGASSET12",
                                                      issuerAccountId: AssetIdTestUtils.issuer)
        XCTAssertTrue(result is IssuedAssetId)
        XCTAssertEqual("LONGASSET12:\(AssetIdTestUtils.issuer)", result.id)
    }

    func testFromAssetDataUnknownTypeThrows() {
        XCTAssertThrowsError(try StellarAssetId.fromAssetData(type: "bogus")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testFromAssetDataInvalidIssuerThrows() {
        XCTAssertThrowsError(try StellarAssetId.fromAssetData(type: "credit_alphanum4",
                                                              code: "USDC",
                                                              issuerAccountId: "NOPE")) { error in
            guard case ValidationError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }
}
