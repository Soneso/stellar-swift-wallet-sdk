//
//  UriTest.swift
//  
//
//  Created by Christian Rogobete on 26.03.25.
//

import XCTest
import Foundation
import stellarsdk
@testable import stellar_wallet_sdk

final class UriTest: XCTestCase {

    let wallet = Wallet.testNet
    let stellar = Wallet.testNet.stellar
    let account = Wallet.testNet.stellar.account
    
    let classicTxXdr = "AAAAAgAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAGQABqQMAAAAAQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAAAAmJaAAAAAAAAAAAFw7E5LAAAAQBu4V+/lttEONNM6KFwdSf5TEEogyEBy0jTOHJKuUzKScpLHyvDJGY+xH9Ri4cIuA7AaB8aL+VdlucCfsNYpKAY="
    
    let sorobanTransferTxXdr = "AAAAAgAAAACM6IR9GHiRoVVAO78JJNksy2fKDQNs2jBn8bacsRLcrDucaFsAAAWIAAAAMQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAGAAAAAAAAAABHkEVdJ+UfDnWpBr/qF582IEoDQ0iW0WPzO9CEUdvvh8AAAAIdHJhbnNmZXIAAAADAAAAEgAAAAAAAAAAjOiEfRh4kaFVQDu/CSTZLMtnyg0DbNowZ/G2nLES3KwAAAASAAAAAAAAAADoFl2ACT9HZkbCeuaT9MAIdStpdf58wM3P24nl738AnQAAAAoAAAAAAAAAAAAAAAAAAAAFAAAAAQAAAAAAAAAAAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAACHRyYW5zZmVyAAAAAwAAABIAAAAAAAAAAIzohH0YeJGhVUA7vwkk2SzLZ8oNA2zaMGfxtpyxEtysAAAAEgAAAAAAAAAA6BZdgAk/R2ZGwnrmk/TACHUraXX+fMDNz9uJ5e9/AJ0AAAAKAAAAAAAAAAAAAAAAAAAABQAAAAAAAAABAAAAAAAAAAIAAAAGAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAAFAAAAAEAAAAHa35L+/RxV6EuJOVk78H5rCN+eubXBWtsKrRxeLnnpRAAAAACAAAABgAAAAEeQRV0n5R8OdakGv+oXnzYgSgNDSJbRY/M70IRR2++HwAAABAAAAABAAAAAgAAAA8AAAAHQmFsYW5jZQAAAAASAAAAAAAAAACM6IR9GHiRoVVAO78JJNksy2fKDQNs2jBn8bacsRLcrAAAAAEAAAAGAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAAEAAAAAEAAAACAAAADwAAAAdCYWxhbmNlAAAAABIAAAAAAAAAAOgWXYAJP0dmRsJ65pP0wAh1K2l1/nzAzc/bieXvfwCdAAAAAQBkcwsAACBwAAABKAAAAAAAAB1kAAAAAA=="
    
    let sorobanMintTxXdr = "AAAAAgAAAACM6IR9GHiRoVVAO78JJNksy2fKDQNs2jBn8bacsRLcrDucQIQAAAWIAAAAMQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAGAAAAAAAAAABHkEVdJ+UfDnWpBr/qF582IEoDQ0iW0WPzO9CEUdvvh8AAAAEbWludAAAAAIAAAASAAAAAAAAAADoFl2ACT9HZkbCeuaT9MAIdStpdf58wM3P24nl738AnQAAAAoAAAAAAAAAAAAAAAAAAAAFAAAAAQAAAAAAAAAAAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAABG1pbnQAAAACAAAAEgAAAAAAAAAA6BZdgAk/R2ZGwnrmk/TACHUraXX+fMDNz9uJ5e9/AJ0AAAAKAAAAAAAAAAAAAAAAAAAABQAAAAAAAAABAAAAAAAAAAIAAAAGAAAAAR5BFXSflHw51qQa/6hefNiBKA0NIltFj8zvQhFHb74fAAAAFAAAAAEAAAAHa35L+/RxV6EuJOVk78H5rCN+eubXBWtsKrRxeLnnpRAAAAABAAAABgAAAAEeQRV0n5R8OdakGv+oXnzYgSgNDSJbRY/M70IRR2++HwAAABAAAAABAAAAAgAAAA8AAAAHQmFsYW5jZQAAAAASAAAAAAAAAADoFl2ACT9HZkbCeuaT9MAIdStpdf58wM3P24nl738AnQAAAAEAYpBIAAAfrAAAAJQAAAAAAAAdYwAAAAA="

    var anchorTomlServerMock: TomlResponseMock!
    var signerKeyPair : SigningKeyPair!

    // A valid classic transaction envelope (testnet-agnostic; only structural validity matters).
    let s7ClassicTxXdr = "AAAAAgAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAGQABqQMAAAAAQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAAAAmJaAAAAAAAAAAAFw7E5LAAAAQBu4V+/lttEONNM6KFwdSf5TEEogyEBy0jTOHJKuUzKScpLHyvDJGY+xH9Ri4cIuA7AaB8aL+VdlucCfsNYpKAY="

    // Known-valid Stellar addresses for destination / issuer / public key checks.
    let s7ValidAccount = "GCALNQQBXAPZ2WIRSDDBMSTAKCUH5SG6U76YBFLQLIXJTF7FE5AX7AOO"
    let s7ValidMuxed = "MA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLTJJFC7MGXUA74P7UJVAAAAAAAAAAAAAJLK"
    let s7ValidContract = "CA3D5KRYM6CB7OWQ6TWYRR3Z4T7GNZLKERYNZGGA5SOAOPIFY6YQGAXE"

    var s7TomlServerMock: TomlResponseMock!
    var s7SignerKeyPair: SigningKeyPair!

    override func setUp() {
        super.setUp()
        ServerMock.removeAll()
        URLProtocol.registerClass(ServerMock.self)

        signerKeyPair  = try! SigningKeyPair(secretKey: "SBA2XQ5SRUW5H3FUQARMC6QYEPUYNSVCMM4PGESGVB2UIFHLM73TPXXF")
        anchorTomlServerMock = TomlResponseMock(host: "place.domain.com",
                                                serverSigningKey: "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP",
                                                uriRequestSigningKey: signerKeyPair.address) // "GDGUF4SCNINRDCRUIVOMDYGIMXOWVP3ZLMTL2OGQIWMFDDSECZSFQMQV"

        s7SignerKeyPair = try! SigningKeyPair(secretKey: "SBA2XQ5SRUW5H3FUQARMC6QYEPUYNSVCMM4PGESGVB2UIFHLM73TPXXF")
        s7TomlServerMock = TomlResponseMock(host: "place.domain.com",
                                            serverSigningKey: "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP",
                                            uriRequestSigningKey: s7SignerKeyPair.address)
    }

    override func tearDown() {
        ServerMock.removeAll()
        super.tearDown()
    }

    func testAll() async throws {
        try await sep7TxTest()
        try sep7PayTest()
        try await verifySignatureTest()
        replaceTest()
    }
    
    func sep7TxTest() async throws {
        var sep7 = Sep7Tx()
        var validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertFalse(validationResult.result)
        
        sep7.setXdr(xdr: classicTxXdr)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(classicTxXdr, sep7.getXdr())
        
        sep7 = try Sep7Tx(transaction: Transaction(envelopeXdr: classicTxXdr))
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(classicTxXdr, sep7.getXdr())
        
        let callback = "https://soneso.com/sep7"
        sep7.setCallback(callback: callback)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(callback, sep7.getCallback())
        
        // should default to public network if not set
        XCTAssertEqual(Network.public.passphrase, sep7.getNetworkPassphrase())
        
        let urlCallback = "url:https://soneso.com/sep7"
        sep7.setCallback(callback: urlCallback)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        // should remove "url:" prefix when getting
        XCTAssertEqual(callback, sep7.getCallback())
        
        var msg = "Hello world!"
        try sep7.setMsg(msg: msg)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(msg, sep7.getMsg())
        
        // should throw whe message is too long
        msg = "another long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long message"
        
        var thrown = false
        do {
            try sep7.setMsg(msg: msg)
        } catch {
            thrown = true
        }
        XCTAssertTrue(thrown)
        
        // Should throw when message is too long and creating from uri string
        let encodedXdr = classicTxXdr.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? classicTxXdr
        var uriString =
                "web+stellar:tx?xdr=\(encodedXdr)&msg=test%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20message%20test%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20long%20message"
        thrown = false
        do {
            let _ = try Sep7.parseSep7Uri(uri: uriString)
        } catch {
            thrown = true
        }
        XCTAssertTrue(thrown)

        let networkPassphrase = Network.testnet.passphrase
        sep7.setNetworkPassphrase(networkPassphrase: networkPassphrase)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(networkPassphrase, sep7.getNetworkPassphrase())
        
        sep7.setNetwork(network: Network.testnet)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(networkPassphrase, sep7.getNetworkPassphrase())
        
        let originDomain = "soneso.com"
        sep7.setOriginDomain(originDomain: originDomain)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(originDomain, sep7.getOriginDomain())
        sep7.setOriginDomain(originDomain: "xyz.com")
        XCTAssertEqual("xyz.com", sep7.getOriginDomain())
        sep7.setOriginDomain(originDomain: nil)
        XCTAssertNil(sep7.getOriginDomain())
        sep7.setOriginDomain(originDomain: originDomain)

        
        let accountKeyPair = account.createKeyPair()
        sep7.setPubKey(pubKey: accountKeyPair.address)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(accountKeyPair.address, sep7.getPubKey())
        
        var parsedSep7 = try Sep7.parseSep7Uri(uri: sep7.toString())
        XCTAssertTrue(parsedSep7 is Sep7Tx)
        XCTAssertEqual(Sep7OperationType.tx, parsedSep7.operationType)
        XCTAssertEqual(sep7.toString(), parsedSep7.toString())
        
        // verifySignature() returns false when there is no origin_domain and signature
        uriString = "web+stellar:tx?xdr=\(encodedXdr)"
        parsedSep7 = try Sep7.parseSep7Uri(uri: uriString)
        XCTAssertTrue(parsedSep7 is Sep7Tx)
        let passedVerification = await parsedSep7.verifySignature()
        XCTAssertFalse(passedVerification)
        
        var sep7Tx = try Sep7Tx(transaction: Transaction(envelopeXdr: sorobanTransferTxXdr))
        validationResult = Sep7.isValidSep7Url(uri: sep7Tx.toString())
        XCTAssertTrue(validationResult.result)
        
        sep7Tx = try Sep7Tx(transaction: Transaction(envelopeXdr: sorobanMintTxXdr))
        validationResult = Sep7.isValidSep7Url(uri: sep7Tx.toString())
        XCTAssertTrue(validationResult.result)
        
    }

    func sep7PayTest() throws {
        let accountKeyPair = account.createKeyPair()
        let sep7 = Sep7Pay()
        
        var validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertFalse(validationResult.result)
        
        sep7.setDestination(destination: accountKeyPair.address)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        
        let callback = "https://soneso.com/sep7"
        sep7.setCallback(callback: callback)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(callback, sep7.getCallback())
        
        // should default to public network if not set
        XCTAssertEqual(Network.public.passphrase, sep7.getNetworkPassphrase())
        
        let urlCallback = "url:https://soneso.com/sep7"
        sep7.setCallback(callback: urlCallback)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        // should remove "url:" prefix when getting
        XCTAssertEqual(callback, sep7.getCallback())
        
        let msg = "Hello world!"
        try sep7.setMsg(msg: msg)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(msg, sep7.getMsg())
        
        let networkPassphrase = Network.testnet.passphrase
        sep7.setNetworkPassphrase(networkPassphrase: networkPassphrase)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(networkPassphrase, sep7.getNetworkPassphrase())
        
        sep7.setNetwork(network: Network.testnet)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(networkPassphrase, sep7.getNetworkPassphrase())
        
        let originDomain = "soneso.com"
        sep7.setOriginDomain(originDomain: originDomain)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(originDomain, sep7.getOriginDomain())
        
        let amount = "22.30"
        sep7.setAmount(amount: amount)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(amount, sep7.getAmount())
        
        let assetCode = "USDC"
        sep7.setAssetCode(assetCode: assetCode)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(assetCode, sep7.getAssetCode())
        
        let assetIssuer = "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
        sep7.setAssetIssuer(assetIssuer: assetIssuer)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(assetIssuer, sep7.getAssetIssuer())
        
        let memo = "1092839284"
        sep7.setMemo(memo: memo)
        sep7.setMemoType(memoType: Sep7MemoType.id.rawValue)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertEqual(memo, sep7.getMemo())
        XCTAssertEqual(Sep7MemoType.id.rawValue, sep7.getMemoType())
        
        let _ = try sep7.addSignature(keyPair: accountKeyPair)
        validationResult = Sep7.isValidSep7Url(uri: sep7.toString())
        XCTAssertTrue(validationResult.result)
        XCTAssertNotNil(sep7.getSignature())
        
        let parsedSep7 = try Sep7.parseSep7Uri(uri: sep7.toString())
        XCTAssertTrue(parsedSep7 is Sep7Pay)
        XCTAssertEqual(Sep7OperationType.pay, parsedSep7.operationType)
        XCTAssertEqual(sep7.toString(), parsedSep7.toString())
    }
    
    func verifySignatureTest() async throws {
        
        var sep7tx = try Sep7Tx(transaction: Transaction(envelopeXdr: sorobanMintTxXdr))
        var verificationResult = await sep7tx.verifySignature()
        // no signature, no origin_domain
        XCTAssertFalse(verificationResult)
        
        sep7tx.setOriginDomain(originDomain: "place.domain.com")
        verificationResult = await sep7tx.verifySignature()
        // no signature
        XCTAssertFalse(verificationResult)
        
        sep7tx = try Sep7Tx(transaction: Transaction(envelopeXdr: sorobanMintTxXdr))
        let _ = try sep7tx.addSignature(keyPair: signerKeyPair)
        verificationResult = await sep7tx.verifySignature()
        // no origin_domain
        XCTAssertFalse(verificationResult)
        
        sep7tx = try Sep7Tx(transaction: Transaction(envelopeXdr: sorobanMintTxXdr))
        sep7tx.setOriginDomain(originDomain: "place.domain.com")
        let _ = try sep7tx.addSignature(keyPair: signerKeyPair)
        verificationResult = await sep7tx.verifySignature()
        // ok
        XCTAssertTrue(verificationResult)
        
        let otherSigner = try SigningKeyPair(secretKey: "SBKQDF56C5VY2YQTNQFGY7HM6R3V6QKDUEDXZQUCPQOP2EBZWG2QJ2JL")
        sep7tx = try Sep7Tx(transaction: Transaction(envelopeXdr: sorobanMintTxXdr))
        sep7tx.setOriginDomain(originDomain: "place.domain.com")
        let _ = try sep7tx.addSignature(keyPair: otherSigner)
        verificationResult = await sep7tx.verifySignature()
        // signature is not from toml:URI_REQUEST_SIGNING_KEY
        XCTAssertFalse(verificationResult)
        
        sep7tx = try Sep7Tx(transaction: Transaction(envelopeXdr: sorobanMintTxXdr))
        sep7tx.setOriginDomain(originDomain: "uuuu.uuuu.com")
        let _ = try sep7tx.addSignature(keyPair: signerKeyPair)
        verificationResult = await sep7tx.verifySignature()
        // no stellar.toml
        XCTAssertFalse(verificationResult)
        
        let uriString =
                "web+stellar:pay?destination=GCALNQQBXAPZ2WIRSDDBMSTAKCUH5SG6U76YBFLQLIXJTF7FE5AX7AOO&amount=120.1234567&memo=skdjfasf&memo_type=MEMO_TEXT&msg=pay%20me%20with%20lumens&origin_domain=someDomain.com";
        let parsedSep7 = try Sep7.parseSep7Uri(uri: uriString)
        

        let signature = try parsedSep7.addSignature(keyPair: otherSigner)
        let expectedSignature = "G/OEnKi7yT4VP2ba7pbrhStH131GQKbg8M7lJTCcGWKo80RbTvTc2Dx5BEpN23Z36gNYBc4/wbBEcu66fuR6DQ=="
        XCTAssertEqual(expectedSignature, signature)
        
    }
    
    public func replaceTest() {
        let first = Sep7Replacement(id: "X", path: "sourceAccount", hint: "account from where you want to pay fees")
        let second = Sep7Replacement(id: "Y", path: "operations[0].sourceAccount", hint: "account that needs the trustline and which will receive the new tokens")
        let third = Sep7Replacement(id: "Y", path: "operations[1].destination", hint: "account that needs the trustline and which will receive the new tokens")
        
        let replace = Sep7.sep7ReplacementsToString(replacements: [first,second,third])
        let expected =
                "sourceAccount:X,operations[0].sourceAccount:Y,operations[1].destination:Y;X:account from where you want to pay fees,Y:account that needs the trustline and which will receive the new tokens"
            
        XCTAssertEqual(expected, replace)
        
        let sep7Tx = Sep7Tx()
        sep7Tx.setXdr(xdr: classicTxXdr)
        sep7Tx.setReplacements(replacements: [first, second])
        sep7Tx.addReplacement(replacement: third)
        let validationResult = Sep7.isValidSep7Url(uri: sep7Tx.toString())
        XCTAssertTrue(validationResult.result)
        
        var replacements = Sep7.sep7ReplacementsFromString(replace: replace)
        XCTAssertEqual(3, replacements.count)
        var firstParsed = replacements[0]
        XCTAssertEqual(first.id, firstParsed.id)
        XCTAssertEqual(first.path, firstParsed.path)
        XCTAssertEqual(first.hint, firstParsed.hint)
        var secondParsed = replacements[1]
        XCTAssertEqual(second.id, secondParsed.id)
        XCTAssertEqual(second.path, secondParsed.path)
        XCTAssertEqual(second.hint, secondParsed.hint)
        var thirdParsed = replacements[2]
        XCTAssertEqual(third.id, thirdParsed.id)
        XCTAssertEqual(third.path, thirdParsed.path)
        XCTAssertEqual(third.hint, thirdParsed.hint)
        
        replacements = sep7Tx.getReplacements() ?? []
        XCTAssertEqual(3, replacements.count)
        firstParsed = replacements[0]
        XCTAssertEqual(first.id, firstParsed.id)
        XCTAssertEqual(first.path, firstParsed.path)
        XCTAssertEqual(first.hint, firstParsed.hint)
        secondParsed = replacements[1]
        XCTAssertEqual(second.id, secondParsed.id)
        XCTAssertEqual(second.path, secondParsed.path)
        XCTAssertEqual(second.hint, secondParsed.hint)
        thirdParsed = replacements[2]
        XCTAssertEqual(third.id, thirdParsed.id)
        XCTAssertEqual(third.path, thirdParsed.path)
        XCTAssertEqual(third.hint, thirdParsed.hint)
    }

    private func encoded(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? value
    }

    // MARK: - Enum raw values

    func testEnumRawValues() {
        XCTAssertEqual("tx", Sep7OperationType.tx.rawValue)
        XCTAssertEqual("pay", Sep7OperationType.pay.rawValue)
        XCTAssertEqual(Sep7OperationType.tx, Sep7OperationType(rawValue: "tx"))
        XCTAssertEqual(Sep7OperationType.pay, Sep7OperationType(rawValue: "pay"))
        XCTAssertNil(Sep7OperationType(rawValue: "txn"))

        XCTAssertEqual("MEMO_TEXT", Sep7MemoType.text.rawValue)
        XCTAssertEqual("MEMO_ID", Sep7MemoType.id.rawValue)
        XCTAssertEqual("MEMO_HASH", Sep7MemoType.hash.rawValue)
        XCTAssertEqual("MEMO_RETURN", Sep7MemoType.returnMemo.rawValue)
        XCTAssertEqual(Sep7MemoType.text, Sep7MemoType(rawValue: "MEMO_TEXT"))
        XCTAssertEqual(Sep7MemoType.id, Sep7MemoType(rawValue: "MEMO_ID"))
        XCTAssertEqual(Sep7MemoType.hash, Sep7MemoType(rawValue: "MEMO_HASH"))
        XCTAssertEqual(Sep7MemoType.returnMemo, Sep7MemoType(rawValue: "MEMO_RETURN"))
        XCTAssertNil(Sep7MemoType(rawValue: "MEMO_NONE"))

        XCTAssertEqual("xdr", Sep7ParameterName.xdr.rawValue)
        XCTAssertEqual("replace", Sep7ParameterName.replace.rawValue)
        XCTAssertEqual("callback", Sep7ParameterName.callback.rawValue)
        XCTAssertEqual("pubkey", Sep7ParameterName.publicKey.rawValue)
        XCTAssertEqual("chain", Sep7ParameterName.chain.rawValue)
        XCTAssertEqual("msg", Sep7ParameterName.message.rawValue)
        XCTAssertEqual("network_passphrase", Sep7ParameterName.networkPassphrase.rawValue)
        XCTAssertEqual("origin_domain", Sep7ParameterName.originDomain.rawValue)
        XCTAssertEqual("signature", Sep7ParameterName.signature.rawValue)
        XCTAssertEqual("destination", Sep7ParameterName.destination.rawValue)
        XCTAssertEqual("amount", Sep7ParameterName.amount.rawValue)
        XCTAssertEqual("asset_code", Sep7ParameterName.assetCode.rawValue)
        XCTAssertEqual("asset_issuer", Sep7ParameterName.assetIssuer.rawValue)
        XCTAssertEqual("memo", Sep7ParameterName.memo.rawValue)
        XCTAssertEqual("memo_type", Sep7ParameterName.memoType.rawValue)
    }

    // MARK: - isValidSep7Url: top-level structural failures

    func testInvalidUrlWrongPrefix() {
        let result = Sep7.isValidSep7Url(uri: "https://example.com/tx?xdr=abc")
        XCTAssertFalse(result.result)
        XCTAssertEqual("It must start with \(URISchemeName)", result.reason)
        XCTAssertNil(result.operationType)
        XCTAssertNil(result.queryItems)
    }

    func testInvalidUrlNoQueryItems() {
        // Valid prefix and a path segment but no query string.
        let result = Sep7.isValidSep7Url(uri: "web+stellar:tx")
        XCTAssertFalse(result.result)
        XCTAssertEqual("Url has no query items", result.reason)
    }

    func testInvalidUrlTooManyPathSegments() {
        let result = Sep7.isValidSep7Url(uri: "web+stellar:tx/extra?xdr=\(encoded(s7ClassicTxXdr))")
        XCTAssertFalse(result.result)
        XCTAssertEqual("Invalid number of path segments. Must only have one path segment", result.reason)
        XCTAssertNotNil(result.queryItems)
    }

    func testInvalidUrlUnsupportedOperationType() {
        let result = Sep7.isValidSep7Url(uri: "web+stellar:sign?xdr=\(encoded(s7ClassicTxXdr))")
        XCTAssertFalse(result.result)
        XCTAssertEqual("Operation type sign is not supported", result.reason)
        XCTAssertNil(result.operationType)
        XCTAssertNotNil(result.queryItems)
    }

    // MARK: - isValidSep7Url: tx branch failures

    func testTxMissingXdrParameter() {
        // tx with a query item but no xdr.
        let result = Sep7.isValidSep7Url(uri: "web+stellar:tx?msg=hello")
        XCTAssertFalse(result.result)
        XCTAssertEqual("Operation type tx must have a 'xdr' parameter", result.reason)
        XCTAssertEqual(Sep7OperationType.tx, result.operationType)
    }

    func testTxInvalidXdrValue() {
        let result = Sep7.isValidSep7Url(uri: "web+stellar:tx?xdr=not-a-valid-xdr")
        XCTAssertFalse(result.result)
        XCTAssertEqual("Invalid 'xdr' parameter value", result.reason)
        XCTAssertEqual(Sep7OperationType.tx, result.operationType)
    }

    func testTxUnsupportedDestinationParameter() {
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&destination=\(s7ValidAccount)"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'destination' for operation type tx", result.reason)
    }

    func testTxUnsupportedAmountParameter() {
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&amount=10"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'amount' for operation type tx", result.reason)
    }

    func testTxUnsupportedAssetCodeParameter() {
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&asset_code=USDC"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'asset_code' for operation type tx", result.reason)
    }

    func testTxUnsupportedAssetIssuerParameter() {
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&asset_issuer=\(s7ValidAccount)"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'asset_issuer' for operation type tx", result.reason)
    }

    func testTxInvalidPublicKey() {
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&pubkey=GINVALID"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("The provided 'pubkey' parameter is not a valid Stellar public key", result.reason)
    }

    func testTxValidPublicKeyAccepted() {
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&pubkey=\(s7ValidAccount)"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
        XCTAssertEqual(Sep7OperationType.tx, result.operationType)
    }

    func testTxUnsupportedMemoParameter() {
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&memo=hello"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'memo' for operation type tx", result.reason)
    }

    func testTxUnsupportedMemoTypeParameter() {
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&memo_type=MEMO_TEXT"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'memo_type' for operation type tx", result.reason)
    }

    // MARK: - isValidSep7Url: chain branch

    func testTxChainMustStartWithScheme() {
        let badChain = encoded("https://example.com/tx?xdr=abc")
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&chain=\(badChain)"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Parameter 'chain' must start with \(URISchemeName). (level: 1)", result.reason)
    }

    func testTxValidSingleChainAccepted() {
        let innerChain = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))"
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&chain=\(encoded(innerChain))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
        XCTAssertEqual(Sep7OperationType.tx, result.operationType)
    }

    func testTxNestedChainWithinLimitAccepted() {
        // Two nested chain levels - well within the allowed maximum.
        let level2 = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))"
        let level1 = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&chain=\(encoded(level2))"
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))&chain=\(encoded(level1))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
    }

    // MARK: - isValidSep7Url: pay branch failures

    func testPayUnsupportedXdrParameter() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&xdr=\(encoded(s7ClassicTxXdr))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'xdr' for operation type pay", result.reason)
        XCTAssertEqual(Sep7OperationType.pay, result.operationType)
    }

    func testPayMissingDestinationParameter() {
        let result = Sep7.isValidSep7Url(uri: "web+stellar:pay?amount=10")
        XCTAssertFalse(result.result)
        XCTAssertEqual("Operation type pay must have a 'destination' parameter", result.reason)
        XCTAssertEqual(Sep7OperationType.pay, result.operationType)
    }

    func testPayInvalidDestination() {
        let result = Sep7.isValidSep7Url(uri: "web+stellar:pay?destination=NOT_AN_ADDRESS")
        XCTAssertFalse(result.result)
        XCTAssertEqual("The provided 'destination' parameter is not a valid Stellar address", result.reason)
    }

    func testPayMuxedDestinationAccepted() {
        let result = Sep7.isValidSep7Url(uri: "web+stellar:pay?destination=\(s7ValidMuxed)")
        XCTAssertTrue(result.result)
        XCTAssertEqual(Sep7OperationType.pay, result.operationType)
    }

    func testPayContractDestinationAccepted() {
        let result = Sep7.isValidSep7Url(uri: "web+stellar:pay?destination=\(s7ValidContract)")
        XCTAssertTrue(result.result)
        XCTAssertEqual(Sep7OperationType.pay, result.operationType)
    }

    func testPayUnsupportedReplaceParameter() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&replace=\(encoded("sourceAccount:X;X:hint"))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'replace' for operation type pay", result.reason)
    }

    func testPayInvalidAssetCodeTooLong() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&asset_code=TOOLONGASSETCODE"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("The provided 'asset_code' parameter is not a valid Stellar asset code", result.reason)
    }

    func testPayAssetCodeMaxLengthAccepted() {
        // 12 chars is the maximum allowed.
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&asset_code=ABCDEFGHIJKL"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
    }

    func testPayInvalidAssetIssuer() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&asset_issuer=GINVALIDISSUER"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("The provided 'asset_issuer' parameter is not a valid Stellar address", result.reason)
    }

    func testPayUnsupportedPublicKeyParameter() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&pubkey=\(s7ValidAccount)"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'pubkey' for operation type pay", result.reason)
    }

    func testPayUnsupportedMemoType() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_BOGUS"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported 'memo_type' value MEMO_BOGUS", result.reason)
    }

    func testPayInvalidMemoTextTooLong() {
        // text memo of more than 28 bytes is rejected by Memo(text:).
        let longText = String(repeating: "a", count: 40)
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_TEXT&memo=\(encoded(longText))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Invalid 'memo' for 'memo_type'", result.reason)
    }

    func testPayValidMemoTextAccepted() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_TEXT&memo=\(encoded("hello"))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
    }

    func testPayInvalidMemoId() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_ID&memo=not-a-number"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Invalid 'memo' for 'memo_type'", result.reason)
    }

    func testPayValidMemoIdAccepted() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_ID&memo=123456789"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
    }

    func testPayMemoHashNotBase64() {
        // A string containing characters not valid in base64 padding triggers the decode failure branch.
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_HASH&memo=\(encoded("not base64 !!!"))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Parameter 'memo' of memo type 'memo_type' must be base64 encoded", result.reason)
    }

    func testPayMemoHashTooLong() {
        // Valid base64 but more than the 32 bytes allowed for a hash memo -> Memo(hash:) throws.
        let tooLong = Data(repeating: 0x01, count: 33).base64EncodedString()
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_HASH&memo=\(encoded(tooLong))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Invalid 'memo' for 'memo_type'", result.reason)
    }

    func testPayValidMemoHashAccepted() {
        let hash = Data(repeating: 0x07, count: 32).base64EncodedString()
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_HASH&memo=\(encoded(hash))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
    }

    func testPayMemoReturnTooLong() {
        let tooLong = Data(repeating: 0x02, count: 33).base64EncodedString()
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_RETURN&memo=\(encoded(tooLong))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Invalid 'memo' for 'memo_type'", result.reason)
    }

    func testPayValidMemoReturnAccepted() {
        let hash = Data(repeating: 0x09, count: 32).base64EncodedString()
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo_type=MEMO_RETURN&memo=\(encoded(hash))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
    }

    func testPayMemoWithoutMemoTypeIsIgnored() {
        // memo present but no memo_type -> validation does not attempt to decode the memo.
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&memo=anything"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
    }

    func testPayUnsupportedChainParameter() {
        let inner = "web+stellar:pay?destination=\(s7ValidAccount)"
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&chain=\(encoded(inner))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("Unsupported parameter 'chain' for operation type pay", result.reason)
    }

    // MARK: - isValidSep7Url: shared trailing checks (message / origin_domain)

    func testMessageTooLong() {
        let longMsg = String(repeating: "x", count: Sep7.messageMaxLength + 1)
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&msg=\(encoded(longMsg))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertNotNil(result.reason)
        XCTAssertTrue(result.reason!.contains("msg"))
    }

    func testMessageAtMaxLengthAccepted() {
        let msg = String(repeating: "x", count: Sep7.messageMaxLength)
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&msg=\(encoded(msg))"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
    }

    func testInvalidOriginDomain() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&origin_domain=not_a_domain"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertEqual("The 'origin_domain' parameter is not a fully qualified domain name", result.reason)
    }

    func testValidOriginDomainAccepted() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&origin_domain=place.domain.com"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
    }

    // MARK: - parseSep7Uri error handling

    func testParseSep7UriThrowsOnInvalidUri() {
        var thrown = false
        do {
            _ = try Sep7.parseSep7Uri(uri: "web+stellar:pay?amount=10")
        } catch let error as ValidationError {
            thrown = true
            if case .invalidArgument(let message) = error {
                XCTAssertTrue(message.contains("Invalid url"))
                XCTAssertTrue(message.contains("destination"))
            } else {
                XCTFail("unexpected ValidationError case")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
        XCTAssertTrue(thrown)
    }

    func testParseSep7UriThrowsOnWrongPrefix() {
        var thrown = false
        do {
            _ = try Sep7.parseSep7Uri(uri: "https://example.com/pay?destination=\(s7ValidAccount)")
        } catch {
            thrown = true
        }
        XCTAssertTrue(thrown)
    }

    func testParseSep7UriReturnsTxInstance() throws {
        let uri = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))"
        let parsed = try Sep7.parseSep7Uri(uri: uri)
        XCTAssertTrue(parsed is Sep7Tx)
        XCTAssertEqual(Sep7OperationType.tx, parsed.operationType)
        XCTAssertEqual(s7ClassicTxXdr, (parsed as! Sep7Tx).getXdr())
    }

    func testParseSep7UriReturnsPayInstance() throws {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&amount=5"
        let parsed = try Sep7.parseSep7Uri(uri: uri)
        XCTAssertTrue(parsed is Sep7Pay)
        XCTAssertEqual(Sep7OperationType.pay, parsed.operationType)
        XCTAssertEqual(s7ValidAccount, (parsed as! Sep7Pay).getDestination())
        XCTAssertEqual("5", (parsed as! Sep7Pay).getAmount())
    }

    // MARK: - Sep7 setters / getters

    func testCallbackUrlPrefixHandling() {
        let sep7 = Sep7Pay()
        sep7.setCallback(callback: "https://cb.example.com/x")
        // stored value gets the "url:" prefix
        XCTAssertEqual("url:https://cb.example.com/x", sep7.getParam(key: Sep7ParameterName.callback.rawValue))
        // getter strips the prefix
        XCTAssertEqual("https://cb.example.com/x", sep7.getCallback())

        // setting an already-prefixed value keeps a single prefix
        sep7.setCallback(callback: "url:https://cb.example.com/y")
        XCTAssertEqual("url:https://cb.example.com/y", sep7.getParam(key: Sep7ParameterName.callback.rawValue))
        XCTAssertEqual("https://cb.example.com/y", sep7.getCallback())

        // a value without "url:" prefix in storage is returned verbatim by the getter
        sep7.setParam(key: Sep7ParameterName.callback.rawValue, value: "plainvalue")
        XCTAssertEqual("plainvalue", sep7.getCallback())

        // clearing the callback
        sep7.setCallback(callback: nil)
        XCTAssertNil(sep7.getCallback())
    }

    func testSetMsgThrowsWhenTooLong() {
        let sep7 = Sep7Pay()
        let longMsg = String(repeating: "a", count: Sep7.messageMaxLength + 1)
        var thrown = false
        do {
            try sep7.setMsg(msg: longMsg)
        } catch let error as ValidationError {
            thrown = true
            if case .invalidArgument(let message) = error {
                XCTAssertTrue(message.contains("msg"))
            } else {
                XCTFail("unexpected ValidationError case")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
        XCTAssertTrue(thrown)
        XCTAssertNil(sep7.getMsg())
    }

    func testSetMsgClearsWhenNil() throws {
        let sep7 = Sep7Pay()
        try sep7.setMsg(msg: "hi")
        XCTAssertEqual("hi", sep7.getMsg())
        try sep7.setMsg(msg: nil)
        XCTAssertNil(sep7.getMsg())
    }

    func testNetworkPassphraseDefaultsToPublic() {
        let sep7 = Sep7Pay()
        XCTAssertEqual(Network.public.passphrase, sep7.getNetworkPassphrase())
        XCTAssertEqual(Network.public.passphrase, sep7.getNetwork().passphrase)
    }

    func testGetNetworkResolvesKnownNetworks() {
        let sep7 = Sep7Pay()

        sep7.setNetwork(network: Network.testnet)
        XCTAssertEqual(Network.testnet.passphrase, sep7.getNetwork().passphrase)

        sep7.setNetwork(network: Network.futurenet)
        XCTAssertEqual(Network.futurenet.passphrase, sep7.getNetwork().passphrase)

        sep7.setNetwork(network: Network.public)
        XCTAssertEqual(Network.public.passphrase, sep7.getNetwork().passphrase)
    }

    func testGetNetworkResolvesCustomPassphrase() {
        let sep7 = Sep7Pay()
        let custom = "My Custom Network ; June 2026"
        sep7.setNetworkPassphrase(networkPassphrase: custom)
        XCTAssertEqual(custom, sep7.getNetworkPassphrase())
        XCTAssertEqual(custom, sep7.getNetwork().passphrase)
    }

    func testSetNetworkNilClearsParam() {
        let sep7 = Sep7Pay()
        sep7.setNetwork(network: Network.testnet)
        XCTAssertEqual(Network.testnet.passphrase, sep7.getNetworkPassphrase())
        sep7.setNetwork(network: nil)
        // falls back to public default once cleared
        XCTAssertEqual(Network.public.passphrase, sep7.getNetworkPassphrase())
    }

    func testSetNetworkPassphraseNilClearsParam() {
        let sep7 = Sep7Pay()
        sep7.setNetworkPassphrase(networkPassphrase: Network.testnet.passphrase)
        XCTAssertEqual(Network.testnet.passphrase, sep7.getNetworkPassphrase())
        sep7.setNetworkPassphrase(networkPassphrase: nil)
        XCTAssertEqual(Network.public.passphrase, sep7.getNetworkPassphrase())
    }

    func testOriginDomainSetGetClear() {
        let sep7 = Sep7Pay()
        XCTAssertNil(sep7.getOriginDomain())
        sep7.setOriginDomain(originDomain: "place.domain.com")
        XCTAssertEqual("place.domain.com", sep7.getOriginDomain())
        sep7.setOriginDomain(originDomain: nil)
        XCTAssertNil(sep7.getOriginDomain())
    }

    func testSignatureGetterNilWhenUnset() {
        let sep7 = Sep7Pay()
        XCTAssertNil(sep7.getSignature())
    }

    func testSetParamUpdatesExistingValue() {
        let sep7 = Sep7Pay()
        sep7.setParam(key: Sep7ParameterName.amount.rawValue, value: "1")
        XCTAssertEqual("1", sep7.getParam(key: Sep7ParameterName.amount.rawValue))
        // update in place
        sep7.setParam(key: Sep7ParameterName.amount.rawValue, value: "2")
        XCTAssertEqual("2", sep7.getParam(key: Sep7ParameterName.amount.rawValue))
        XCTAssertEqual(1, sep7.queryParameters.filter { $0.name == Sep7ParameterName.amount.rawValue }.count)
        // remove
        sep7.setParam(key: Sep7ParameterName.amount.rawValue, value: nil)
        XCTAssertNil(sep7.getParam(key: Sep7ParameterName.amount.rawValue))
    }

    // MARK: - toString

    func testToStringEmptyTx() {
        XCTAssertEqual("web+stellar:tx?", Sep7Tx().toString())
    }

    func testToStringEmptyPay() {
        // Sep7Pay() with no destination has no query params.
        XCTAssertEqual("web+stellar:pay?", Sep7Pay().toString())
    }

    func testToStringEncodesValues() {
        let sep7 = Sep7Pay()
        sep7.setDestination(destination: s7ValidAccount)
        sep7.setAmount(amount: "10")
        let str = sep7.toString()
        XCTAssertTrue(str.hasPrefix("web+stellar:pay?"))
        XCTAssertTrue(str.contains("destination=\(s7ValidAccount)"))
        XCTAssertTrue(str.contains("amount=10"))
        XCTAssertFalse(str.hasSuffix("&"))
    }

    func testToStringRoundTripsThroughParse() throws {
        let sep7 = Sep7Pay()
        sep7.setDestination(destination: s7ValidAccount)
        sep7.setAmount(amount: "12.5")
        sep7.setMemo(memo: "hello world")
        sep7.setMemoType(memoType: Sep7MemoType.text.rawValue)
        let parsed = try Sep7.parseSep7Uri(uri: sep7.toString())
        XCTAssertEqual(sep7.toString(), parsed.toString())
    }

    // MARK: - Sep7Tx specific

    func testSep7TxSettersGetters() {
        let tx = Sep7Tx()
        XCTAssertEqual(Sep7OperationType.tx, tx.operationType)
        XCTAssertNil(tx.getXdr())
        tx.setXdr(xdr: s7ClassicTxXdr)
        XCTAssertEqual(s7ClassicTxXdr, tx.getXdr())
        tx.setXdr(xdr: nil)
        XCTAssertNil(tx.getXdr())

        XCTAssertNil(tx.getPubKey())
        tx.setPubKey(pubKey: s7ValidAccount)
        XCTAssertEqual(s7ValidAccount, tx.getPubKey())
        tx.setPubKey(pubKey: nil)
        XCTAssertNil(tx.getPubKey())

        XCTAssertNil(tx.getChain())
        let chain = "web+stellar:tx?xdr=\(encoded(s7ClassicTxXdr))"
        tx.setChain(chain: chain)
        XCTAssertEqual(chain, tx.getChain())
        tx.setChain(chain: nil)
        XCTAssertNil(tx.getChain())
    }

    func testSep7TxFromTransaction() throws {
        let tx = try Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        XCTAssertEqual(s7ClassicTxXdr, tx.getXdr())
        XCTAssertTrue(Sep7.isValidSep7Url(uri: tx.toString()).result)
    }

    func testSep7TxGetReplacementsNilWhenUnset() {
        XCTAssertNil(Sep7Tx().getReplacements())
    }

    func testSep7TxSetReplacementsClearsOnNilAndEmpty() {
        let tx = Sep7Tx()
        tx.setXdr(xdr: s7ClassicTxXdr)
        tx.setReplacements(replacements: [Sep7Replacement(id: "X", path: "sourceAccount", hint: "h")])
        XCTAssertNotNil(tx.getReplacements())
        tx.setReplacements(replacements: nil)
        XCTAssertNil(tx.getReplacements())

        tx.setReplacements(replacements: [Sep7Replacement(id: "X", path: "sourceAccount", hint: "h")])
        XCTAssertNotNil(tx.getReplacements())
        tx.setReplacements(replacements: [])
        XCTAssertNil(tx.getReplacements())
    }

    func testSep7TxAddReplacementFromEmpty() {
        let tx = Sep7Tx()
        tx.setXdr(xdr: s7ClassicTxXdr)
        tx.addReplacement(replacement: Sep7Replacement(id: "A", path: "sourceAccount", hint: "first"))
        var replacements = tx.getReplacements()
        XCTAssertEqual(1, replacements?.count)
        tx.addReplacement(replacement: Sep7Replacement(id: "B", path: "operations[0].sourceAccount", hint: "second"))
        replacements = tx.getReplacements()
        XCTAssertEqual(2, replacements?.count)
        XCTAssertEqual("A", replacements?[0].id)
        XCTAssertEqual("sourceAccount", replacements?[0].path)
        XCTAssertEqual("first", replacements?[0].hint)
        XCTAssertEqual("B", replacements?[1].id)
        XCTAssertEqual("operations[0].sourceAccount", replacements?[1].path)
        XCTAssertEqual("second", replacements?[1].hint)
    }

    // MARK: - Sep7Pay specific

    func testSep7PaySettersGetters() {
        let pay = Sep7Pay()
        XCTAssertEqual(Sep7OperationType.pay, pay.operationType)
        XCTAssertNil(pay.getDestination())
        pay.setDestination(destination: s7ValidAccount)
        XCTAssertEqual(s7ValidAccount, pay.getDestination())

        pay.setAmount(amount: "100.5")
        XCTAssertEqual("100.5", pay.getAmount())
        pay.setAmount(amount: nil)
        XCTAssertNil(pay.getAmount())

        pay.setAssetCode(assetCode: "USDC")
        XCTAssertEqual("USDC", pay.getAssetCode())
        pay.setAssetCode(assetCode: nil)
        XCTAssertNil(pay.getAssetCode())

        pay.setAssetIssuer(assetIssuer: s7ValidAccount)
        XCTAssertEqual(s7ValidAccount, pay.getAssetIssuer())
        pay.setAssetIssuer(assetIssuer: nil)
        XCTAssertNil(pay.getAssetIssuer())

        pay.setMemo(memo: "memo-value")
        XCTAssertEqual("memo-value", pay.getMemo())
        pay.setMemo(memo: nil)
        XCTAssertNil(pay.getMemo())

        pay.setMemoType(memoType: Sep7MemoType.text.rawValue)
        XCTAssertEqual(Sep7MemoType.text.rawValue, pay.getMemoType())
        pay.setMemoType(memoType: nil)
        XCTAssertNil(pay.getMemoType())
    }

    func testSep7PayInitWithDestination() {
        let pay = Sep7Pay(destination: s7ValidAccount)
        XCTAssertEqual(s7ValidAccount, pay.getDestination())
        XCTAssertTrue(Sep7.isValidSep7Url(uri: pay.toString()).result)
    }

    // MARK: - Replacement helpers

    func testReplacementsToStringEmptyReturnsEmpty() {
        XCTAssertEqual("", Sep7.sep7ReplacementsToString(replacements: []))
    }

    func testReplacementsFromStringEmptyReturnsEmpty() {
        XCTAssertEqual(0, Sep7.sep7ReplacementsFromString(replace: "").count)
    }

    func testReplacementsRoundTrip() {
        let first = Sep7Replacement(id: "X", path: "sourceAccount", hint: "fee account")
        let second = Sep7Replacement(id: "Y", path: "operations[0].destination", hint: "destination account")
        let str = Sep7.sep7ReplacementsToString(replacements: [first, second])
        let expected = "sourceAccount:X,operations[0].destination:Y;X:fee account,Y:destination account"
        XCTAssertEqual(expected, str)

        let parsed = Sep7.sep7ReplacementsFromString(replace: str)
        XCTAssertEqual(2, parsed.count)
        XCTAssertEqual("X", parsed[0].id)
        XCTAssertEqual("sourceAccount", parsed[0].path)
        XCTAssertEqual("fee account", parsed[0].hint)
        XCTAssertEqual("Y", parsed[1].id)
        XCTAssertEqual("operations[0].destination", parsed[1].path)
        XCTAssertEqual("destination account", parsed[1].hint)
    }

    func testReplacementsToStringDeduplicatesHints() {
        // Two replacements sharing the same id should only emit one hint entry.
        let first = Sep7Replacement(id: "Y", path: "operations[0].sourceAccount", hint: "shared hint")
        let second = Sep7Replacement(id: "Y", path: "operations[1].destination", hint: "shared hint")
        let str = Sep7.sep7ReplacementsToString(replacements: [first, second])
        let expected = "operations[0].sourceAccount:Y,operations[1].destination:Y;Y:shared hint"
        XCTAssertEqual(expected, str)
    }

    func testReplacementsFromStringWithoutHints() {
        // No hint section: every replacement gets an empty hint.
        let parsed = Sep7.sep7ReplacementsFromString(replace: "sourceAccount:X,operations[0].destination:Y")
        XCTAssertEqual(2, parsed.count)
        XCTAssertEqual("X", parsed[0].id)
        XCTAssertEqual("sourceAccount", parsed[0].path)
        XCTAssertEqual("", parsed[0].hint)
        XCTAssertEqual("Y", parsed[1].id)
        XCTAssertEqual("operations[0].destination", parsed[1].path)
        XCTAssertEqual("", parsed[1].hint)
    }

    func testReplacementsFromStringMissingHintForId() {
        // Only one of two ids has a hint; the other defaults to empty.
        let parsed = Sep7.sep7ReplacementsFromString(replace: "sourceAccount:X,opDest:Y;X:only X hint")
        XCTAssertEqual(2, parsed.count)
        XCTAssertEqual("only X hint", parsed.first { $0.id == "X" }?.hint)
        XCTAssertEqual("", parsed.first { $0.id == "Y" }?.hint)
    }

    func testReplacementsFromStringSkipsMalformedFieldEntries() {
        // An entry without the id delimiter is skipped entirely.
        let parsed = Sep7.sep7ReplacementsFromString(replace: "noDelimiterHere,sourceAccount:X;X:hint")
        XCTAssertEqual(1, parsed.count)
        XCTAssertEqual("X", parsed[0].id)
        XCTAssertEqual("sourceAccount", parsed[0].path)
        XCTAssertEqual("hint", parsed[0].hint)
    }

    func testReplacementInitStoresProperties() {
        let r = Sep7Replacement(id: "ID", path: "PATH", hint: "HINT")
        XCTAssertEqual("ID", r.id)
        XCTAssertEqual("PATH", r.path)
        XCTAssertEqual("HINT", r.hint)
    }

    // MARK: - addSignature error branches

    func testAddSignatureThrowsOnInvalidUrl() {
        // tx without xdr -> toString() produces an invalid sep7 url.
        let tx = Sep7Tx()
        tx.setOriginDomain(originDomain: "place.domain.com")
        var thrown = false
        do {
            _ = try tx.addSignature(keyPair: s7SignerKeyPair)
        } catch let error as ValidationError {
            thrown = true
            if case .invalidArgument(let message) = error {
                XCTAssertEqual("Invalid sep7 url", message)
            } else {
                XCTFail("unexpected ValidationError case")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
        XCTAssertTrue(thrown)
    }

    func testAddSignatureThrowsWhenAlreadySigned() throws {
        let tx = try Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        tx.setOriginDomain(originDomain: "place.domain.com")
        _ = try tx.addSignature(keyPair: s7SignerKeyPair)
        XCTAssertNotNil(tx.getSignature())

        var thrown = false
        do {
            _ = try tx.addSignature(keyPair: s7SignerKeyPair)
        } catch let error as ValidationError {
            thrown = true
            if case .invalidArgument(let message) = error {
                XCTAssertEqual("sep7 url already contains a signature", message)
            } else {
                XCTFail("unexpected ValidationError case")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
        XCTAssertTrue(thrown)
    }

    func testAddSignatureIsDeterministic() throws {
        // Two identical URIs signed by the same key produce the same signature.
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&amount=120.1234567&memo=skdjfasf&memo_type=MEMO_TEXT&msg=pay%20me%20with%20lumens&origin_domain=someDomain.com"
        let a = try Sep7.parseSep7Uri(uri: uri)
        let b = try Sep7.parseSep7Uri(uri: uri)
        let sigA = try a.addSignature(keyPair: s7SignerKeyPair)
        let sigB = try b.addSignature(keyPair: s7SignerKeyPair)
        XCTAssertEqual(sigA, sigB)
        // signature is valid base64
        XCTAssertNotNil(Data(base64Encoded: sigA))
    }

    // MARK: - isValidSep7SignedUrl / verifySignature failure branches

    func testIsValidSignedUrlReturnsUnderlyingInvalidResult() async {
        // An url that is not even a valid sep7 url short-circuits before any network access.
        let result = await Sep7.isValidSep7SignedUrl(uri: "web+stellar:pay?amount=10")
        XCTAssertFalse(result.result)
        XCTAssertEqual("Operation type pay must have a 'destination' parameter", result.reason)
    }

    func testIsValidSignedUrlMissingOriginDomain() async {
        // Valid sep7 url but no origin_domain and no signature.
        let tx = try! Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        let result = await Sep7.isValidSep7SignedUrl(uri: tx.toString())
        XCTAssertFalse(result.result)
        XCTAssertEqual("Missing parameter 'origin_domain'", result.reason)
    }

    func testIsValidSignedUrlMissingSignature() async {
        let tx = try! Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        tx.setOriginDomain(originDomain: "place.domain.com")
        let result = await Sep7.isValidSep7SignedUrl(uri: tx.toString())
        XCTAssertFalse(result.result)
        XCTAssertEqual("Missing parameter 'signature'", result.reason)
    }

    func testVerifySignatureNoOriginNoSignature() async throws {
        let tx = try Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        let verified = await tx.verifySignature()
        XCTAssertFalse(verified)
    }

    func testVerifySignatureWrongSigner() async throws {
        // origin_domain toml advertises s7SignerKeyPair but the url is signed by a different key.
        let otherSigner = try SigningKeyPair(secretKey: "SBKQDF56C5VY2YQTNQFGY7HM6R3V6QKDUEDXZQUCPQOP2EBZWG2QJ2JL")
        let tx = try Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        tx.setOriginDomain(originDomain: "place.domain.com")
        _ = try tx.addSignature(keyPair: otherSigner)
        let verified = await tx.verifySignature()
        XCTAssertFalse(verified)
    }

    func testVerifySignatureTomlNotFound() async throws {
        // origin_domain has no toml mock registered.
        let tx = try Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        tx.setOriginDomain(originDomain: "nonexistent.example.com")
        _ = try tx.addSignature(keyPair: s7SignerKeyPair)
        let verified = await tx.verifySignature()
        XCTAssertFalse(verified)
    }

    func testVerifySignatureValid() async throws {
        let tx = try Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        tx.setOriginDomain(originDomain: "place.domain.com")
        _ = try tx.addSignature(keyPair: s7SignerKeyPair)
        let verified = await tx.verifySignature()
        XCTAssertTrue(verified)
    }

    func testIsValidSignedUrlValid() async throws {
        let tx = try Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        tx.setOriginDomain(originDomain: "place.domain.com")
        _ = try tx.addSignature(keyPair: s7SignerKeyPair)
        let result = await Sep7.isValidSep7SignedUrl(uri: tx.toString())
        XCTAssertTrue(result.result)
    }

    func testIsValidSignedUrlWrongSignerReports() async throws {
        let otherSigner = try SigningKeyPair(secretKey: "SBKQDF56C5VY2YQTNQFGY7HM6R3V6QKDUEDXZQUCPQOP2EBZWG2QJ2JL")
        let tx = try Sep7Tx(transaction: Transaction(envelopeXdr: s7ClassicTxXdr))
        tx.setOriginDomain(originDomain: "place.domain.com")
        _ = try tx.addSignature(keyPair: otherSigner)
        let result = await Sep7.isValidSep7SignedUrl(uri: tx.toString())
        XCTAssertFalse(result.result)
        XCTAssertEqual("Signature is not from the signing key found in the toml data of origin domain", result.reason)
    }

    // MARK: - IsValidSep7UriResult container

    func testIsValidResultCarriesQueryItemsOnSuccess() {
        let uri = "web+stellar:pay?destination=\(s7ValidAccount)&amount=7"
        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertTrue(result.result)
        XCTAssertNil(result.reason)
        XCTAssertEqual(Sep7OperationType.pay, result.operationType)
        XCTAssertNotNil(result.queryItems)
        XCTAssertEqual(s7ValidAccount, result.queryItems?.first { $0.name == "destination" }?.value)
        XCTAssertEqual("7", result.queryItems?.first { $0.name == "amount" }?.value)
    }

    // MARK: - Sep7: chain nesting beyond the allowed maximum

    func testSep7ChainExceedsMaxNestedLevels() {
        // Build a chain of nested tx URIs deeper than maxAllowedChainingNestedLevels (7).
        // Each level wraps the previous one in a 'chain' query parameter.
        let xdr = "AAAAAgAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAGQABqQMAAAAAQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAAAAmJaAAAAAAAAAAAFw7E5LAAAAQBu4V+/lttEONNM6KFwdSf5TEEogyEBy0jTOHJKuUzKScpLHyvDJGY+xH9Ri4cIuA7AaB8aL+VdlucCfsNYpKAY="

        // Encoding the chain value with alphanumerics-only ensures the nested
        // '&chain=' / '?xdr=' separators are percent-encoded so the chain truly
        // nests (rather than flattening into sibling query items).
        func encoded(_ value: String) -> String {
            return value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
        }

        // Innermost level: a plain valid tx uri.
        var uri = "web+stellar:tx?xdr=\(encoded(xdr))"
        // Nest 9 additional chain levels so the deepest 'chain' is encountered while
        // level has already passed maxAllowedChainingNestedLevels (7).
        for _ in 0..<9 {
            uri = "web+stellar:tx?xdr=\(encoded(xdr))&chain=\(encoded(uri))"
        }

        let result = Sep7.isValidSep7Url(uri: uri)
        XCTAssertFalse(result.result)
        XCTAssertNotNil(result.reason)
        XCTAssertTrue(result.reason!.contains("Chaining more then \(Sep7.maxAllowedChainingNestedLevels) nested levels is not allowed"),
                      "unexpected reason: \(result.reason ?? "nil")")
        XCTAssertEqual(Sep7OperationType.tx, result.operationType)
    }

}
