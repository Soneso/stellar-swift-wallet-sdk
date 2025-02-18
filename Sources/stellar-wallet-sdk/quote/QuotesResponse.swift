//
//  QuotesResponses.swift
//
//
//  Created by Christian Rogobete on 18.02.25.
//

import Foundation
import stellarsdk

public class QuotesInfoResponse {
    var assets: [QuoteInfoAsset]
    
    init(info:Sep38InfoResponse) {
        self.assets = []
        for asset in info.assets {
            self.assets.append(QuoteInfoAsset(asset: asset))
        }
    }
}

public class QuoteInfoAsset {
    var asset:String
    var sellDeliveryMethods:[QuoteSellDeliveryMethod]?
    var buyDeliveryMethods:[QuoteBuyDeliveryMethod]?
    var countryCodes:[String]?
 
    init(asset:Sep38Asset) {
        self.asset = asset.asset
        if let sellMethods = asset.sellDeliveryMethods {
            self.sellDeliveryMethods = []
            for method in sellMethods {
                self.sellDeliveryMethods!.append(QuoteSellDeliveryMethod(method: method))
            }
        }
        if let buyMethods = asset.buyDeliveryMethods {
            self.buyDeliveryMethods = []
            for method in buyMethods {
                self.buyDeliveryMethods!.append(QuoteBuyDeliveryMethod(method: method))
            }
        }
        
        if let cCodes = asset.countryCodes {
            self.countryCodes = []
            for code in cCodes {
                self.countryCodes!.append(code)
            }
        }
    }
}

public class QuoteSellDeliveryMethod {
    var name:String
    var description:String
    
    init(method:Sep38SellDeliveryMethod) {
        self.name = method.name
        self.description = method.description
    }
}


public class QuoteBuyDeliveryMethod {
    var name:String
    var description:String
    
    init(method:Sep38BuyDeliveryMethod) {
        self.name = method.name
        self.description = method.description
    }
}

public class QuoteAssetIndicativePrices {
    var buyAssets:[QuoteBuyAsset]
    
    init(prices:Sep38PricesResponse) {
        self.buyAssets = []
        for asset in prices.buyAssets {
            self.buyAssets.append(QuoteBuyAsset(buyAsset: asset))
        }
    }
}

public class QuoteBuyAsset {
    var asset:String
    var price:String
    var decimals:Int
    
    init(buyAsset:Sep38BuyAsset) {
        self.asset = buyAsset.asset
        self.price = buyAsset.price
        self.decimals = buyAsset.decimals
    }
}

public class QuoteAssetPairIndicativePrice {
    var totalPrice:String
    var price:String
    var sellAmount:String
    var buyAmount:String
    var fee:ConversionFee
    
    init(sep38Price:Sep38PriceResponse) {
        self.totalPrice = sep38Price.totalPrice
        self.price = sep38Price.price
        self.sellAmount = sep38Price.sellAmount
        self.buyAmount = sep38Price.buyAmount
        self.fee = ConversionFee(fee: sep38Price.fee)
    }
}

public class ConversionFee {
    var total:String
    var asset:String
    var details: [ConversionFeeDetails]?
    
    init(fee:Sep38Fee) {
        self.total = fee.total
        self.asset = fee.asset
        if let details = fee.details {
            self.details = []
            for detail in details {
                self.details!.append(ConversionFeeDetails(details: detail))
            }
        }
    }
}

public class ConversionFeeDetails {
    var name:String
    var amount:String
    var description:String?
    
    init(details:Sep38FeeDetails) {
        self.name = details.name
        self.amount = details.amount
        self.description = details.description
    }
}

public class FirmQuote {
    public var id: String
    public var expiresAt: Date
    public var totalPrice: String
    public var price: String
    public var sellAsset: String
    public var sellAmount: String
    public var buyAsset: String
    public var buyAmount: String
    public var fee: ConversionFee
    
    init(quote:Sep38QuoteResponse) {
        self.id = quote.id
        self.expiresAt = quote.expiresAt
        self.totalPrice = quote.totalPrice
        self.price = quote.price
        self.sellAsset = quote.sellAsset
        self.sellAmount = quote.sellAmount
        self.buyAsset = quote.buyAsset
        self.buyAmount = quote.buyAmount
        self.fee = ConversionFee(fee: quote.fee)
    }
}
