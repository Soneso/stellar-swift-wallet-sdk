//
//  Sep7.swift
//
//
//  Created by Christian Rogobete on 26.03.25.
//

import Foundation
import stellarsdk

/// For parsing and constructing SEP-7 Stellar URIs.
/// [SEP-7](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md).
public class Sep7 {

    public static let messageMaxLength = 300
    public static let maxAllowedChainingNestedLevels = 7;
    public static let replacementHintDelimiter = ";";
    public static let replacementIdDelimiter = ":";
    public static let replacementListDelimiter = ",";
    
    public static let uriSchemePrefix = "stellar.sep.7 - URI Scheme";
    
    internal var queryParameters:[URLQueryItem] = []
    public var operationType:Sep7OperationType
    private let uriScheme:URIScheme
    
    
    internal init(operationType: Sep7OperationType) {
        self.operationType = operationType
        self.uriScheme = URIScheme()
    }
    
    /// Checks if a given url is a valid sep7 url without verifying the signature.
    /// If you need to verifying the signature you can use [isValidSep7SignedUrl]
    /// or [verifySignature].
    public static func isValidSep7Url(uri:String) -> IsValidSep7UriResult {
        if(!uri.starts(with: URISchemeName)) {
            return IsValidSep7UriResult(result: false, reason: "It must start with \(URISchemeName)")
        }
        
        // transform to be able to parse components
        let xUrl = uri.replacingOccurrences(of: URISchemeName, with: "https://www.soneso.com/")
        
        guard let url = URL(string: xUrl) else {
          return IsValidSep7UriResult(result: false, reason: "Could not parse url")
        }
        guard let urlComponents = URLComponents(string: xUrl) else {
          return IsValidSep7UriResult(result: false, reason: "Could not parse url")
        }
        
        guard let queryItems = urlComponents.queryItems else {
            return IsValidSep7UriResult(result: false, reason: "Url has no query items")
        }
        
        let pathSegments = url.pathComponents
        if pathSegments.count != 2 { // first is "/" then should be "tx" or "pay"
            return IsValidSep7UriResult(result: false, reason: "Invalid number of path segments. Must only have one path segment", queryItems: queryItems)
        }
        
        let operationType = pathSegments.last!
        var resultOpType:Sep7OperationType? = nil
        if operationType == Sep7OperationType.tx.rawValue {
            resultOpType = Sep7OperationType.tx
        } else if operationType == Sep7OperationType.pay.rawValue {
            resultOpType = Sep7OperationType.pay
        } else {
            return IsValidSep7UriResult(result: false, reason: "Operation type \(operationType) is not supported", queryItems: queryItems)
        }
        
        if operationType == Sep7OperationType.tx.rawValue  {
            guard let xdrItem = queryItems.filter({$0.name == Sep7ParameterName.xdr.rawValue}).first else {
                return IsValidSep7UriResult(result: false,
                                            reason: "Operation type \(operationType) must have a '\(Sep7ParameterName.xdr.rawValue)' parameter",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            guard let xdrItemValue = xdrItem.value else {
                return IsValidSep7UriResult(result: false, reason: "Invalid '\(Sep7ParameterName.xdr.rawValue)' parameter value",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            do {
                let _ = try Transaction(envelopeXdr: xdrItemValue)
            } catch {
                return IsValidSep7UriResult(result: false, reason: "Invalid '\(Sep7ParameterName.xdr.rawValue)' parameter value",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if queryItems.filter({$0.name == Sep7ParameterName.destination.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.destination.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if queryItems.filter({$0.name == Sep7ParameterName.amount.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.amount.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if queryItems.filter({$0.name == Sep7ParameterName.assetCode.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.assetCode.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if queryItems.filter({$0.name == Sep7ParameterName.assetIssuer.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.assetIssuer.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if let publicKey = queryItems.filter({$0.name == Sep7ParameterName.publicKey.rawValue}).first?.value, (try? publicKey.decodeEd25519PublicKey()) == nil {
                return IsValidSep7UriResult(result: false, reason: "The provided '\(Sep7ParameterName.publicKey.rawValue)' parameter is not a valid Stellar public key",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if queryItems.filter({$0.name == Sep7ParameterName.memo.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.memo.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if queryItems.filter({$0.name == Sep7ParameterName.memoType.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.memoType.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            var chain:String? = queryItems.filter({$0.name == Sep7ParameterName.chain.rawValue}).first?.value
            var level = 1
            while let chainUri = chain {
                if(!chainUri.starts(with: URISchemeName)) {
                    return IsValidSep7UriResult(result: false, reason: "Parameter '\(Sep7ParameterName.chain.rawValue)' must start with \(URISchemeName). (level: \(level))",
                                                operationType: resultOpType,
                                                queryItems: queryItems)
                }
                
                // transform to be able to parse components
                let chainUrlStr = chainUri.replacingOccurrences(of: URISchemeName, with: "https://www.soneso.com/")
                
                guard let _ = URL(string: chainUrlStr) else {
                  return IsValidSep7UriResult(result: false, reason: "Could not parse url from parameter '\(Sep7ParameterName.chain.rawValue)' (level: \(level))",
                                              operationType: resultOpType,
                                              queryItems: queryItems)
                }
                
                guard let chainUrlComponents = URLComponents(string: chainUrlStr) else {
                    return IsValidSep7UriResult(result: false, reason: "Could not parse url from parameter '\(Sep7ParameterName.chain.rawValue)' (level: \(level))",
                                                operationType: resultOpType,
                                                queryItems: queryItems)
                }
                
                guard let chainQueryItems = chainUrlComponents.queryItems else {
                    return IsValidSep7UriResult(result: false, reason: "Url from parameter '\(Sep7ParameterName.chain.rawValue) has no query items (level: \(level))",
                                                operationType: resultOpType,
                                                queryItems: queryItems)
                }
                chain = chainQueryItems.filter({$0.name == Sep7ParameterName.chain.rawValue}).first?.value
                if chain != nil && level > maxAllowedChainingNestedLevels {
                    return IsValidSep7UriResult(result: false, reason: "'Chaining more then \(maxAllowedChainingNestedLevels) nested levels is not allowed'",
                                                operationType: resultOpType,
                                                queryItems: queryItems)
                }
                level += 1
            }
        } else {
            if queryItems.filter({$0.name == Sep7ParameterName.xdr.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.xdr.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            guard let destinationItem = queryItems.filter({$0.name == Sep7ParameterName.destination.rawValue}).first else {
                return IsValidSep7UriResult(result: false, reason: "Operation type \(operationType) must have a '\(Sep7ParameterName.destination.rawValue)' parameter",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            guard let destinationItemValue = destinationItem.value else {
                return IsValidSep7UriResult(result: false, reason: "Invalid '\(Sep7ParameterName.destination.rawValue)' parameter value",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if (try? destinationItemValue.decodeEd25519PublicKey()) == nil &&
                (try? destinationItemValue.decodeMuxedAccount()) == nil &&
                (try? destinationItemValue.decodeContractId()) == nil {
                return IsValidSep7UriResult(result: false, reason: "The provided '\(Sep7ParameterName.destination.rawValue)' parameter is not a valid Stellar address",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if queryItems.filter({$0.name == Sep7ParameterName.replace.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.replace.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if let assetCode = queryItems.filter({$0.name == Sep7ParameterName.assetCode.rawValue}).first?.value, assetCode.count > 12 {
                return IsValidSep7UriResult(result: false, reason: "The provided '\(Sep7ParameterName.assetCode.rawValue)' parameter is not a valid Stellar asset code",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if let assetIssuer = queryItems.filter({$0.name == Sep7ParameterName.assetIssuer.rawValue}).first?.value, (try? assetIssuer.decodeEd25519PublicKey()) == nil {
                return IsValidSep7UriResult(result: false, reason: "The provided '\(Sep7ParameterName.assetIssuer.rawValue)' parameter is not a valid Stellar address",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if queryItems.filter({$0.name == Sep7ParameterName.publicKey.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.publicKey.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            if let memoType = queryItems.filter({$0.name == Sep7ParameterName.memoType.rawValue}).first?.value {
                if Sep7MemoType(rawValue: memoType) == nil {
                    return IsValidSep7UriResult(result: false, reason: "Unsupported '\(Sep7ParameterName.memoType.rawValue)' value \(memoType)",
                                                operationType: resultOpType,
                                                queryItems: queryItems)
                }
            }
            if let memo = queryItems.filter({$0.name == Sep7ParameterName.memo.rawValue}).first?.value {
                guard let memoTypeVal = queryItems.filter({$0.name == Sep7ParameterName.memoType.rawValue}).first?.value, let memoType = Sep7MemoType(rawValue: memoTypeVal) else {
                    return IsValidSep7UriResult(result: false, reason: "Parameter '\(Sep7ParameterName.memo.rawValue)' provided but parameter '\(Sep7ParameterName.memoType.rawValue)' is missing.",
                                                operationType: resultOpType,
                                                queryItems: queryItems)
                }
                
                switch memoType {
                case .text:
                    do {
                        let _ = try Memo(text: memo)
                    } catch {
                        return IsValidSep7UriResult(result: false, reason: "Invalid '\(Sep7ParameterName.memo.rawValue)' for '\(Sep7ParameterName.memoType.rawValue)'",
                                                    operationType: resultOpType,
                                                    queryItems: queryItems)
                    }
                case .id:
                    guard let _ = UInt64(memo) else {
                        return IsValidSep7UriResult(result: false, reason: "Invalid '\(Sep7ParameterName.memo.rawValue)' for '\(Sep7ParameterName.memoType.rawValue)'",
                                                    operationType: resultOpType,
                                                    queryItems: queryItems)
                    }
                case .hash:
                    guard let decodedMemo = Data(base64Encoded: memo) else {
                        return IsValidSep7UriResult(result: false, reason: "Parameter '\(Sep7ParameterName.memo.rawValue)' of memo type '\(Sep7ParameterName.memoType.rawValue)' must be base64 encoded",
                                                    operationType: resultOpType,
                                                    queryItems: queryItems)
                    }
                    do {
                        let _ = try Memo(hash: decodedMemo)
                    } catch {
                        return IsValidSep7UriResult(result: false, reason: "Invalid '\(Sep7ParameterName.memo.rawValue)' for '\(Sep7ParameterName.memoType.rawValue)'",
                                                    operationType: resultOpType,
                                                    queryItems: queryItems)
                    }
                case .returnMemo:
                    guard let decodedMemo = Data(base64Encoded: memo) else {
                        return IsValidSep7UriResult(result: false, reason: "Parameter '\(Sep7ParameterName.memo.rawValue)' of memo type '\(Sep7ParameterName.memoType.rawValue)' must be base64 encoded",
                                                    operationType: resultOpType,
                                                    queryItems: queryItems)
                    }
                    do {
                        let _ = try Memo(returnHash: decodedMemo)
                    } catch {
                        return IsValidSep7UriResult(result: false, reason: "Invalid '\(Sep7ParameterName.memo.rawValue)' for '\(Sep7ParameterName.memoType.rawValue)'",
                                                    operationType: resultOpType,
                                                    queryItems: queryItems)
                    }
                }
                
            }
            
            if queryItems.filter({$0.name == Sep7ParameterName.chain.rawValue}).first != nil {
                return IsValidSep7UriResult(result: false, reason: "Unsupported parameter '\(Sep7ParameterName.chain.rawValue)' for operation type \(operationType)",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
            
        }
        
        if let message = queryItems.filter({$0.name == Sep7ParameterName.message.rawValue}).first?.value, message.count > Sep7.messageMaxLength {
            return IsValidSep7UriResult(result: false, reason: "The '\(Sep7ParameterName.message.rawValue)' parameter should be no longer than $\(Sep7.messageMaxLength) characters",
                                        operationType: resultOpType,
                                        queryItems: queryItems)
        }
        
        if let originDomain = queryItems.filter({$0.name == Sep7ParameterName.originDomain.rawValue}).first?.value{
            
            if !originDomain.isFullyQualifiedDomainName {
                return IsValidSep7UriResult(result: false, reason: "The '\(Sep7ParameterName.originDomain.rawValue)' parameter is not a fully qualified domain name",
                                            operationType: resultOpType,
                                            queryItems: queryItems)
            }
        }
        
        return IsValidSep7UriResult(result: true, operationType: resultOpType, queryItems: queryItems)
    }
    
    /// Checks if the given url is a valid an properly signed sep7 url.
    /// The 'origin_domain' and 'signature' query parameters in the url must be set,
    /// otherwise the given url will be considered as invalid. This function will make a http request
    /// to obtain the toml data from the 'origin_domain'. If the toml data could not be loaded
    /// or if it dose not contain the signer's public key, the given url will be
    /// considered as invalid. If the url has been signed by the signer from the
    /// 'origin_domain' toml data, the url will be considered as valid.
    public static func isValidSep7SignedUrl(uri:String) async -> IsValidSep7UriResult {
        let result = isValidSep7Url(uri: uri)
        if !result.result {
            // not valid
            return result
        }
        
        let validationResponseEnum = await URISchemeValidator().checkURISchemeIsValid(url: uri)
        switch validationResponseEnum {
        case .success:
            return IsValidSep7UriResult(result: true)
        case .failure(let uRISchemeErrors):
            switch uRISchemeErrors {
            case .invalidSignature:
                return IsValidSep7UriResult(result: false, reason: "Signature is not from the signing key found in the toml data of origin domain",
                                            operationType: result.operationType, queryItems: result.queryItems)
            case .invalidOriginDomain:
                return IsValidSep7UriResult(result: false, reason: "The '\(Sep7ParameterName.originDomain.rawValue)' parameter is not a fully qualified domain name",
                                            operationType: result.operationType, queryItems: result.queryItems)
            case .missingOriginDomain:
                return IsValidSep7UriResult(result: false, reason: "Missing parameter '\(Sep7ParameterName.originDomain.rawValue)'",
                                            operationType: result.operationType, queryItems: result.queryItems)
            case .missingSignature:
                return IsValidSep7UriResult(result: false, reason: "Missing parameter '\(Sep7ParameterName.signature.rawValue)'",
                                            operationType: result.operationType, queryItems: result.queryItems)
            case .invalidTomlDomain:
                return IsValidSep7UriResult(result: false, reason: "Toml not found for origin domain",
                                            operationType: result.operationType, queryItems: result.queryItems)
            case .invalidToml:
                return IsValidSep7UriResult(result: false, reason: "Invalid toml at origin domain",
                                            operationType: result.operationType, queryItems: result.queryItems)
            case .tomlSignatureMissing:
                return IsValidSep7UriResult(result: false, reason: "No signing key found in toml from origin domain",
                                            operationType: result.operationType, queryItems: result.queryItems)
            }
        }
    }
    
    /// Tries to parse a given sep7 compliant [url].
    /// Throws a ValidationError if the given url  is not a valid sep7 url.
    /// Otherwise it returns Sep7Pay or Sep7Tx.
    public static func parseSep7Uri(uri:String) throws -> Sep7 {
        let validationResult = Sep7.isValidSep7Url(uri: uri)
        if !validationResult.result {
            throw ValidationError.invalidArgument(message: "Invalid url. Reason: \(validationResult.reason ?? "")")
        }
        guard let opType = validationResult.operationType else {
            throw ValidationError.invalidArgument(message: "Invalid url. Reason: \(validationResult.reason ?? "")")
        }
        
        let queryItems:[URLQueryItem] = validationResult.queryItems ?? []
        
        
        switch opType {
        case .tx:
            let result = Sep7Tx()
            result.queryParameters = queryItems
            return result
        case .pay:
            let result = Sep7Pay()
            result.queryParameters = queryItems
            return result
        }
    }
    
    /// Takes a Sep-7 URL-decoded `replace` string param and parses it to a list of
    /// [Sep7Replacement] objects for easy of use.
    ///
    /// The `replace` string identifies the fields to be replaced in the XDR using
    /// the 'Txrep (SEP-0011)' representation, which should be specified in the format of:
    /// txrep_tx_field_name_1:reference_identifier_1,txrep_tx_field_name_2:reference_identifier_2;reference_identifier_1:hint_1,reference_identifier_2:hint_2
    ///
    /// @see https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0011.md
    public static func sep7ReplacementsFromString(replace:String) -> [Sep7Replacement] {
        if replace.count == 0 {
            return []
        }
        let fieldsAndHints = replace.components(separatedBy:replacementHintDelimiter)
        
        var fieldsAndIds:[String] = []
        if let first = fieldsAndHints.first {
            fieldsAndIds = first.components(separatedBy:replacementListDelimiter)
        }
        
        var idsAndHints:[String] = []
        if fieldsAndHints.count > 1 {
            idsAndHints = fieldsAndHints[1].components(separatedBy:replacementListDelimiter)
        }
        
        var fields:[Sep7ReplaceKeyVal] = []
        for item in fieldsAndIds {
            let fieldAndId = item.components(separatedBy:replacementIdDelimiter)
            if fieldAndId.count > 1 {
                fields.append(Sep7ReplaceKeyVal(key: fieldAndId.first!, val: fieldAndId[1]))
            }
        }
        
        var hints:[Sep7ReplaceKeyVal] = []
        for item in idsAndHints {
            let idAndHint = item.components(separatedBy:replacementIdDelimiter)
            if idAndHint.count > 1 {
                hints.append(Sep7ReplaceKeyVal(key: idAndHint.first!, val: idAndHint[1]))
            }
        }
        var result:[Sep7Replacement] = []
        for field in fields {
            let hint = hints.filter({$0.key == field.val}).first?.val ?? ""
            result.append(Sep7Replacement(id: field.val, path: field.key, hint: hint))
        }
        return result
    }
    
    /// Takes a list of [Sep7Replacement] objects and parses it to a string that
    /// could be used as a Sep-7 URI 'replace' param.
    ///
    /// This string identifies the fields to be replaced in the XDR using
    /// the 'Txrep (SEP-0011)' representation, which should be specified in the format of:
    /// txrep_tx_field_name_1:reference_identifier_1,txrep_tx_field_name_2:reference_identifier_2;reference_identifier_1:hint_1,reference_identifier_2:hint_2
    ///
    /// @see https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0011.md
    public static func sep7ReplacementsToString(replacements:[Sep7Replacement]) -> String {
        if replacements.isEmpty {
            return ""
        }
        var fields:String = ""
        var hints:String = ""
        for item in replacements {
            fields += "\(item.path)\(replacementIdDelimiter)\(item.id)\(replacementListDelimiter)"
            let nextHint = "\(item.id)\(replacementIdDelimiter)\(item.hint)\(replacementListDelimiter)"
            if !(hints.contains(nextHint)) {
                hints += nextHint
            }
        }
        return String(fields.prefix(fields.count - 1)) +
                replacementHintDelimiter +
                String(hints.prefix(hints.count - 1))
    }
    
    /// Returns a URL-decoded version of the uri 'callback' param without
    /// the 'url:' prefix if any. The URI handler should send the signed XDR to
    /// this callback url, if this value is omitted then the URI handler should
    /// submit it to the network.
    public func getCallback() -> String? {
        guard let callback = queryParameters.filter({$0.name == Sep7ParameterName.callback.rawValue}).first?.value else {
            return nil
        }
        if callback.starts(with: "url:") {
            let index = callback.index(callback.startIndex, offsetBy: 4)
            return String(callback.suffix(from: index))
        }
        return callback
    }
    
    /// Sets and URL-encodes the uri [callback] param, appends the 'url:'
    /// prefix to it if not yet present. Deletes the uri [callback] param if set as null.
    /// The URI handler should send the signed XDR to this [callback] url, if this
    /// value is omitted then the URI handler should submit it to the network.
    public func setCallback(callback:String?) {
        guard let newCallback = callback else {
            setParam(key: Sep7ParameterName.callback.rawValue, value: nil)
            return
        }
        if newCallback.starts(with: "url:") {
            setParam(key: Sep7ParameterName.callback.rawValue, value: newCallback)
        } else {
            setParam(key: Sep7ParameterName.callback.rawValue, value: "url:" + newCallback)
        }
    }
    
    /// Returns a URL-decoded version of the uri 'msg' param if any.
    /// This message should indicate any additional information that the website
    /// or application wants to show the user in her wallet.
    public func getMsg() -> String? {
        return getParam(key: Sep7ParameterName.message.rawValue)
    }
    
    /// Sets and URL-encodes the uri 'msg' param, the [msg] param can't
    /// be larger than 300 characters. If larger, throws [ValidationError.invalidArgument].
    /// Deletes the uri [msg] param if set as null.
    /// This message should indicate any additional information that the website
    /// or application wants to show the user in her wallet.
    public func setMsg(msg:String?) throws  {
        if msg != nil && msg!.count > Sep7.messageMaxLength {
            throw ValidationError.invalidArgument(message: "'msg' should be no longer than \(Sep7.messageMaxLength) characters")
        }
        setParam(key: Sep7ParameterName.message.rawValue, value: msg)
    }
    
    /// Returns uri 'network_passphrase' param as [String], if not present returns
    /// the PUBLIC Network value by default: 'Public Global Stellar Network ; September 2015'.
    public func getNetworkPassphrase() -> String? {
        guard let networkPassphrase = getParam(key: Sep7ParameterName.networkPassphrase.rawValue) else {
            return Network.public.passphrase
        }
        return networkPassphrase
    }
    
    /// Returns uri 'network_passphrase' param as [Network], if not present returns
    /// the PUBLIC Network value
    public func getNetwork() -> Network {
        guard let networkPassphrase = getParam(key: Sep7ParameterName.networkPassphrase.rawValue) else {
            return Network.public
        }
        
        if networkPassphrase == Network.public.passphrase {
            return Network.public
        } else if networkPassphrase == Network.testnet.passphrase {
            return Network.testnet
        } else if networkPassphrase == Network.futurenet.passphrase {
            return Network.futurenet
        }
        
        return Network.custom(passphrase: networkPassphrase)
    }
    
    /// Sets the uri 'network_passphrase' param.
    /// Deletes the uri [networkPassphrase] param if set as null.
    /// Only need to set it if this transaction is for a network other than
    /// the public network.
    public func setNetworkPassphrase(networkPassphrase: String?) {
        setParam(key:Sep7ParameterName.networkPassphrase.rawValue , value: networkPassphrase)
    }
    
    /// Sets the uri 'network_passphrase' param by using the value from the given [network].
    /// Deletes the uri 'network_passphrase' param if [network] is set as null.
    /// Only need to set it if this transaction is for a network other than
    /// the public network.
    public func setNetwork(network:Network?) {
        setParam(key:Sep7ParameterName.networkPassphrase.rawValue , value: network?.passphrase)
    }
    
    /// Returns a URL-decoded version of the uri 'origin_domain' param if any.
    /// This should be a fully qualified domain name that specifies the originating
    /// domain of the URI request.
    public func getOriginDomain() -> String? {
        return getParam(key: Sep7ParameterName.originDomain.rawValue)
    }
    
    /// Sets and URL-encodes the uri 'origin_domain' param.
    /// Deletes the uri 'origin_domain' param if [originDomain] is set as null.
    public func setOriginDomain(originDomain:String?) {
        setParam(key: Sep7ParameterName.originDomain.rawValue, value: originDomain)
    }
    
    /// Returns a URL-decoded version of the uri 'signature' param if any.
    /// This should be a signature of the hash of the URI request (excluding the
    /// 'signature' field and value itself).
    /// Wallets should use the URI_REQUEST_SIGNING_KEY specified in the
    /// origin_domain's stellar.toml file to validate this signature.
    /// If the verification fails, wallets must alert the user.
    public func getSignature() -> String? {
        return getParam(key: Sep7ParameterName.signature.rawValue)
    }
    
    /// Generates the sep7 url.
    public func toString() -> String {
        var path = "pay"
        if operationType == Sep7OperationType.tx {
            path = "tx"
        }
        
        var result = "web+stellar:\(path)?"
        
        for item in queryParameters {
            var encodedValue=""
            if let val = item.value, let encoded = val.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                encodedValue = encoded
            }
            result += "\(item.name)=\(encodedValue)&"
        }
        
        if !(queryParameters.isEmpty) {
            result = String(result.dropLast())
        }
        
        return result
    }
    
    /// Signs the URI with the given [keypair], which means it sets the 'signature' param.
    /// This should be the last step done before generating the URI string,
    /// otherwise the signature will be invalid for the URI.
    /// The given [keypair] (including secret key) is used to sign the request.
    /// This should be the keypair found in the URI_REQUEST_SIGNING_KEY field of the
    /// 'origin_domains' stellar.toml.
    public func addSignature(keyPair:SigningKeyPair) throws -> String {
        let sep7Url = toString()
        let validationResult = Sep7.isValidSep7Url(uri: sep7Url)
        if !validationResult.result {
            throw ValidationError.invalidArgument(message: "Invalid sep7 url")
        }
        if sep7Url.contains(Sep7ParameterName.signature.rawValue) {
            throw ValidationError.invalidArgument(message: "sep7 url already contains a signature")
        }
        
        let signature = sign(url: sep7Url, keyPair: keyPair)
        setParam(key: Sep7ParameterName.signature.rawValue, value: signature)
        return signature
    }
    
    /// Verifies that the signature added to the URI is valid.
    /// returns 'true' if the signature is valid for
    /// the current URI and origin_domain. Returns 'false' if signature verification
    /// fails, or if there is a problem looking up the stellar.toml associated with
    /// the origin_domain.
    public func verifySignature() async -> Bool {
        let sep7Url = toString()
        let validationResult = await Sep7.isValidSep7SignedUrl(uri: sep7Url)
        return validationResult.result
    }
    
    
    
    internal func sign(url:String, keyPair:SigningKeyPair) -> String {
        let payload = getPayload(url: url)
        let signatureBytes = Data(keyPair.keyPair.sign(payload))
        let signatureBase64 = signatureBytes.base64EncodedString()
        return signatureBase64
        //return signatureBase64.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? signatureBase64
    }
    
    internal func getPayload(url:String) -> [UInt8] {
        var payload:[UInt8] = []
        for _ in 0..<36 {
            payload.append(0)
        }
        payload[35] = 4
        payload.append(contentsOf: (Sep7.uriSchemePrefix + url).utf8)
        return payload
    }
    
    internal func getParam(key:String) -> String? {
        return queryParameters.filter({$0.name == key}).first?.value
    }
    
    internal func setParam(key:String, value:String?) {
        guard let newVal = value else {
            queryParameters.removeAll(where: {$0.name == key})
            return
        }
        for i in 0..<queryParameters.count {
            if queryParameters[i].name == key {
                queryParameters[i].value = newVal
                return
            }
        }
        queryParameters.append(URLQueryItem(name: key, value: newVal))
    }
    
}

internal class Sep7ReplaceKeyVal {
    internal init(key: String, val: String) {
        self.key = key
        self.val = val
    }
    
    internal var key:String
    internal var val:String
    
}
