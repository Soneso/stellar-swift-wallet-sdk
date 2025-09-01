//
//  Sep38.swift
//
//
//  Created by Christian Rogobete on 18.02.25.
//

import Foundation
import stellarsdk

/// Implements SEP-0038 - Anchor RFQ API.
/// See <https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md" target="_blank">Anchor RFQ API.</a>
public class Sep38 {
    public var authToken:AuthToken?
    private let quoteService: QuoteService
    
    /// Constructor
    ///
    /// - Parameters:
    ///   - serviceAddress: the serviceAddress from the server (ANCHOR_QUOTE_SERVER in stellar.toml).
    ///   - authToken: SEP-10 Authentication token for the request. Optional, but required for [requestQuote] and [getQuote] methods (endpoints).
    ///
    internal init(serviceAddress:String, authToken:AuthToken? = nil) {
        self.authToken = authToken
        self.quoteService = QuoteService(serviceAddress: serviceAddress)
    }
    
    /// The supported Stellar assets and off-chain assets available for trading.
    /// See: https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md#get-info
    public var info: QuotesInfoResponse {
        get async throws {
            let infoResponse = await quoteService.info(jwt: authToken?.jwt)
            switch infoResponse {
            case .success(let response):
                return QuotesInfoResponse(info: response)
            case .failure(let error):
                throw error
            }
        }
    }
    
    /// This endpoint can be used to fetch the indicative prices of available off-chain assets in exchange for a Stellar asset and vice versa.
    /// See <https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md#get-prices" target="_blank">GET prices</a>
    ///
    /// - Parameters:
    ///   - sellAsset: The asset you want to sell, using the Asset Identification Format.
    ///   - sellAmount: The amount of sell_asset the client would exchange for each of the buy_assets.
    ///   - sellDeliveryMethod: Optional, one of the name values specified by the sell_delivery_methods array for the associated asset returned from GET /info. Can be provided if the user is delivering an off-chain asset to the anchor but is not strictly required.
    ///   - buyDeliveryMethod: Optional, one of the name values specified by the buy_delivery_methods array for the associated asset returned from GET /info. Can be provided if the user intends to receive an off-chain asset from the anchor but is not strictly required.
    ///   - countryCode: Optional, The ISO 3166-2 or ISO-3166-1 alpha-2 code of the user's current address. Should be provided if there are two or more country codes available for the desired asset in GET /info.
    ///
    public func prices(sellAsset:String,
                       sellAmount:String,
                       sellDeliveryMethod:String? = nil,
                       buyDeliveryMethod:String? = nil,
                       countryCode:String? = nil) async throws -> QuoteAssetIndicativePrices {
        let pricesResponse = await quoteService.prices(sellAsset: sellAsset, 
                                                       sellAmount: sellAmount,
                                                       sellDeliveryMethod: sellDeliveryMethod,
                                                       buyDeliveryMethod: buyDeliveryMethod,
                                                       countryCode: countryCode,
                                                       jwt: authToken?.jwt)
        switch pricesResponse {
        case .success(let response):
            return QuoteAssetIndicativePrices(prices: response)
        case .failure(let error):
            throw error
        }
    }
    
    /// This endpoint can be used to fetch the indicative price for a given asset pair.
    /// See <https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md#get-price" target="_blank">GET price</a>
    /// The client must provide either [sellAmount] or [buyAmount], but not both.
    ///
    /// - Parameters:
    ///   - context: The context for what this quote will be used for. Must be one of 'sep6' or 'sep31'.
    ///   - sellAsset: The asset the client would like to sell. Ex. stellar:USDC:G..., iso4217:ARS
    ///   - buyAsset: The asset the client would like to exchange for sellAsset.
    ///   - sellAmount: optional, the amount of sellAsset the client would like to exchange for buyAsset.
    ///   - buyAmount: optional, the amount of buyAsset the client would like to exchange for sellAsset.
    ///   - sellDeliveryMethod: Optional, one of the name values specified by the sell_delivery_methods array for the associated asset returned from GET /info. Can be provided if the user is delivering an off-chain asset to the anchor but is not strictly required.
    ///   - buyDeliveryMethod: Optional, one of the name values specified by the buy_delivery_methods array for the associated asset returned from GET /info. Can be provided if the user intends to receive an off-chain asset from the anchor but is not strictly required.
    ///   - countryCode: Optional, The ISO 3166-2 or ISO-3166-1 alpha-2 code of the user's current address. Should be provided if there are two or more country codes available for the desired asset in GET /info.
    ///
    public func price(context:String,
                      sellAsset:String,
                      buyAsset:String,
                      sellAmount:String? = nil,
                      buyAmount:String? = nil,
                      sellDeliveryMethod:String? = nil,
                      buyDeliveryMethod:String? = nil,
                      countryCode:String? = nil) async throws -> QuoteAssetPairIndicativePrice {
        
        if ((sellAmount != nil && buyAmount != nil) || (sellAmount == nil && buyAmount == nil)) {
            throw ValidationError.invalidArgument(message: "The caller must provide either sellAmount or buyAmount, but not both")
        }
        
        let priceResponse = await quoteService.price(context: context,
                                                     sellAsset: sellAsset,
                                                     buyAsset: buyAsset,
                                                     sellAmount: sellAmount,
                                                     buyAmount: buyAmount,
                                                     sellDeliveryMethod: sellDeliveryMethod,
                                                     buyDeliveryMethod:buyDeliveryMethod,
                                                     countryCode: countryCode,
                                                     jwt: authToken?.jwt)
        switch priceResponse {
        case .success(let response):
            return QuoteAssetPairIndicativePrice(sep38Price: response)
        case .failure(let error):
            throw error
        }
    }
    
    /// This endpoint can be used to request a firm quote for a Stellar asset and off-chain asset pair.
    /// See <https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md#post-quote" target="_blank">POST quote</a>
    /// The client must provide either [sellAmount] or [buyAmount], but not both.
    ///
    /// - Parameters:
    ///   - context: The context for what this quote will be used for. Must be one of 'sep6' or 'sep31'.
    ///   - sellAsset: The asset the client would like to sell. Ex. stellar:USDC:G..., iso4217:ARS
    ///   - buyAsset: The asset the client would like to exchange for sellAsset.
    ///   - sellAmount: optional, the amount of sellAsset the client would like to exchange for buyAsset.
    ///   - buyAmount: optional, the amount of buyAsset the client would like to exchange for sellAsset.
    ///   - expireAfter: optional, the client's desired expires_at date and time for the quote.
    ///   - sellDeliveryMethod: Optional, one of the name values specified by the sell_delivery_methods array for the associated asset returned from GET /info. Can be provided if the user is delivering an off-chain asset to the anchor but is not strictly required.
    ///   - buyDeliveryMethod: Optional, one of the name values specified by the buy_delivery_methods array for the associated asset returned from GET /info. Can be provided if the user intends to receive an off-chain asset from the anchor but is not strictly required.
    ///   - countryCode: Optional, The ISO 3166-2 or ISO-3166-1 alpha-2 code of the user's current address. Should be provided if there are two or more country codes available for the desired asset in GET /info.
    ///   - authToken: token obtained before with SEP-0010. If not given by constructor, it can be passed here.
    ///
    public func requestQuote(context:String,
                      sellAsset:String,
                      buyAsset:String,
                      sellAmount:String? = nil,
                      buyAmount:String? = nil,
                      expireAfter:Date? = nil,
                      sellDeliveryMethod:String? = nil,
                      buyDeliveryMethod:String? = nil,
                      countryCode:String? = nil,
                      authToken:AuthToken? = nil) async throws -> FirmQuote {
        
        if ((sellAmount != nil && buyAmount != nil) ||
            (sellAmount == nil && buyAmount == nil)) {
            throw ValidationError.invalidArgument(message: "The caller must provide either sellAmount or buyAmount, but not both")
        }
        
        var request = Sep38PostQuoteRequest(context: context, sellAsset: sellAsset, buyAsset: buyAsset)
        request.sellAmount = sellAmount
        request.buyAmount = buyAmount
        request.expireAfter = expireAfter
        request.sellDeliveryMethod = sellDeliveryMethod
        request.buyDeliveryMethod = buyDeliveryMethod
        request.countryCode = countryCode
        
        if let jwt = self.authToken?.jwt ?? authToken?.jwt {
            let postQuoteResponse = await quoteService.postQuote(request: request, jwt: jwt)
            switch postQuoteResponse {
            case .success(let response):
                return FirmQuote(quote: response)
            case .failure(let error):
                throw error
            }
        }
        
        throw ValidationError.invalidArgument(message: "The requestQuote endpoint requires SEP-10 authentication")
    }
    
    /// This endpoint can be used to fetch a previously-provided firm quote by id.
    /// See <https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md#get-quote" target="_blank">GET quote</a>
    ///
    /// - Parameters:
    ///   - quoteId: the id of the quote.
    ///   - authToken: token obtained before with SEP-0010. If not given by constructor, it can be passed here.
    ///
    public func getQuote(quoteId:String, authToken:AuthToken? = nil) async throws -> FirmQuote {
        if let jwt = self.authToken?.jwt ?? authToken?.jwt {
            let getQuoteResponse = await quoteService.getQuote(id: quoteId, jwt: jwt)
            switch getQuoteResponse {
            case .success(let response):
                return FirmQuote(quote: response)
            case .failure(let error):
                throw error
            }
        }
        
        throw ValidationError.invalidArgument(message: "The getQuote endpoint requires SEP-10 authentication")
    }
}
