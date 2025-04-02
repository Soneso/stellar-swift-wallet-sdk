//
//  Sep7Tx.swift
//
//
//  Created by Christian Rogobete on 31.03.25.
//

import Foundation
import stellarsdk

public class Sep7Tx:Sep7 {
    
    public init() {
        super.init(operationType: Sep7OperationType.tx)
    }
    
    public convenience init(transaction:Transaction) throws {
        self.init()
        setXdr(xdr: try transaction.encodedEnvelope())
    }
    
    /// Sets and URL-encodes the uri [xdr] param.
    public func setXdr(xdr:String?) {
        setParam(key: Sep7ParameterName.xdr.rawValue, value: xdr)
    }
    
    /// Returns a URL-decoded version of the uri 'xdr' param if any.
    public func getXdr() -> String? {
        return getParam(key: Sep7ParameterName.xdr.rawValue)
    }
    
    /// Sets and URL-encodes the uri [pubKey] param.
    public func setPubKey(pubKey:String?) {
        setParam(key: Sep7ParameterName.publicKey.rawValue, value: pubKey)
    }
    
    /// Returns a URL-decoded version of the uri 'pubKey' param if any.
    public func getPubKey() -> String? {
        return getParam(key: Sep7ParameterName.publicKey.rawValue)
    }
    
    /// Sets and URL-encodes the uri [chain] param.
    public func setChain(chain:String?) {
        setParam(key: Sep7ParameterName.chain.rawValue, value: chain)
    }
    
    /// Returns a URL-decoded version of the uri 'chain' param if any.
    public func getChain() -> String? {
        return getParam(key: Sep7ParameterName.chain.rawValue)
    }
    
    /// Sets and URL-encodes the uri 'replace' param, which is a list of fields in
    /// the transaction that needs to be replaced.
    ///
    /// Deletes the uri 'replace' param if set as empty array '[]' or 'null'.
    ///
    /// This 'replace' param should be a URL-encoded value that identifies the
    /// fields to be replaced in the XDR using the 'Txrep (SEP-0011)' representation.
    /// This will be specified in the format of:
    /// txrep_tx_field_name_1:reference_identifier_1,txrep_tx_field_name_2:reference_identifier_2;reference_identifier_1:hint_1,reference_identifier_2:hint_2
    ///
    /// @see https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0011.md
    public func setReplacements(replacements:[Sep7Replacement]?) {
        guard let replace = replacements, !replace.isEmpty else {
            setParam(key: Sep7ParameterName.replace.rawValue, value: nil)
            return
        }
        setParam(key: Sep7ParameterName.replace.rawValue, value: Sep7.sep7ReplacementsToString(replacements: replace))
    }
    
    /// Gets a list of fields in the transaction that need to be replaced.
    public func getReplacements() -> [Sep7Replacement]? {
        guard let replaceStr = getParam(key: Sep7ParameterName.replace.rawValue) else {
            return nil
        }
        return Sep7.sep7ReplacementsFromString(replace: replaceStr)
    }
    
    /// Adds an additional [replacement].
    public func addReplacement(replacement:Sep7Replacement) {
        var replacements:[Sep7Replacement] = getReplacements() ?? []
        replacements.append(replacement)
        setReplacements(replacements: replacements)
    }
    
}
