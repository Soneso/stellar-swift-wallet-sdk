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
    
    override func setUp() {
        URLProtocol.registerClass(ServerMock.self)
        
        
        signerKeyPair  = try! SigningKeyPair(secretKey: "SBA2XQ5SRUW5H3FUQARMC6QYEPUYNSVCMM4PGESGVB2UIFHLM73TPXXF")
        anchorTomlServerMock = TomlResponseMock(host: "place.domain.com",
                                                serverSigningKey: "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP",
                                                uriRequestSigningKey: signerKeyPair.address) // "GDGUF4SCNINRDCRUIVOMDYGIMXOWVP3ZLMTL2OGQIWMFDDSECZSFQMQV"
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
    
}
