//
//  InteractiveFlowError.swift
//
//
//  Created by Christian Rogobete on 08.01.25.
//

import Foundation

public enum InteractiveFlowError: Error {
    case assetNotAcceptedForWithdrawal(assetId: StellarAssetId)
    case assetNotEnabledForWithdrawal(assetId: StellarAssetId)
    case assetNotAcceptedForDeposit(assetId: StellarAssetId)
    case assetNotEnabledForDeposit(assetId: StellarAssetId)
}
