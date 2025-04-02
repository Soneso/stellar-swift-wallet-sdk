//
//  Sep7Pay.swift
//
//
//  Created by Christian Rogobete on 02.04.25.
//

import Foundation
import stellarsdk

public class Sep7Pay:Sep7 {
    
    public init(destination:String? = nil) {
        super.init(operationType: Sep7OperationType.pay)
        setDestination(destination: destination)
    }
    
    /// Sets and URL-encodes the uri [destination] param.
    public func setDestination(destination:String?) {
        setParam(key: Sep7ParameterName.destination.rawValue, value: destination)
    }
    
    /// Returns a URL-decoded version of the uri 'destination' param if any.
    public func getDestination() -> String? {
        return getParam(key: Sep7ParameterName.destination.rawValue)
    }
    
    /// Sets and URL-encodes the uri [amount] param.
    public func setAmount(amount:String?) {
        setParam(key: Sep7ParameterName.amount.rawValue, value: amount)
    }
    
    /// Returns a URL-decoded version of the uri 'amount' param if any.
    public func getAmount() -> String? {
        return getParam(key: Sep7ParameterName.amount.rawValue)
    }
    
    /// Sets and URL-encodes the uri [assetCode] param.
    public func setAssetCode(assetCode:String?) {
        setParam(key: Sep7ParameterName.assetCode.rawValue, value: assetCode)
    }
    
    /// Returns a URL-decoded version of the uri 'assetCode' param if any.
    public func getAssetCode() -> String? {
        return getParam(key: Sep7ParameterName.assetCode.rawValue)
    }
    
    /// Sets and URL-encodes the uri [assetIssuer] param.
    public func setAssetIssuer(assetIssuer:String?) {
        setParam(key: Sep7ParameterName.assetIssuer.rawValue, value: assetIssuer)
    }
    
    /// Returns a URL-decoded version of the uri 'assetIssuer' param if any.
    public func getAssetIssuer() -> String? {
        return getParam(key: Sep7ParameterName.assetIssuer.rawValue)
    }
    
    /// Sets and URL-encodes the uri [memo] param.
    public func setMemo(memo:String?) {
        setParam(key: Sep7ParameterName.memo.rawValue, value: memo)
    }
    
    /// Returns a URL-decoded version of the uri 'memo' param if any.
    public func getMemo() -> String? {
        return getParam(key: Sep7ParameterName.memo.rawValue)
    }
    
    /// Sets and URL-encodes the uri [memoType] param.
    public func setMemoType(memoType:String?) {
        setParam(key: Sep7ParameterName.memoType.rawValue, value: memoType)
    }
    
    /// Returns a URL-decoded version of the uri 'memoType' param if any.
    public func getMemoType() -> String? {
        return getParam(key: Sep7ParameterName.memoType.rawValue)
    }
}
