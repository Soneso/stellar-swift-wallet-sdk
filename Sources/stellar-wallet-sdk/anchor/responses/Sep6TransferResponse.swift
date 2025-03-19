//
//  Sep6TransferResponse.swift
//
//
//  Created by Christian Rogobete on 05.03.25.
//

import Foundation
import stellarsdk

public enum Sep6TransferResponse {
    case missingKYC(fields:[String])
    case pending(status:String, moreInfoUrl:String?, eta:Int?)
    case withdrawSuccess(accountId:String?, memoType:String?, memo:String?, id:String?, eta:Int?, minAmount:Double?, maxAmount:Double?, feeFixed:Double?, feePercent:Double?, extraInfo:Sep6ExtraInfo?)
    case depositSuccess(how:String?, id:String?, eta:Int?, minAmount:Double?, maxAmount:Double?, feeFixed:Double?, feePercent:Double?, extraInfo:Sep6ExtraInfo?, instructions:[String:Sep6DepositInstruction]?)
    
    internal static func fromCustomerInformationNeededResponse(response: CustomerInformationNeededNonInteractive) -> Sep6TransferResponse {
        return Sep6TransferResponse.missingKYC(fields: response.fields)
    }
    
    internal static func fromCustomerInformationStatusResponse(response: CustomerInformationStatus) -> Sep6TransferResponse {
        return Sep6TransferResponse.pending(status: response.status, moreInfoUrl: response.moreInfoUrl, eta: response.eta)
    }
    
    internal static func fromWithdrawSuccessResponse(response: WithdrawResponse) -> Sep6TransferResponse {
        var extraInfo:Sep6ExtraInfo? = nil
        if let responseExtraInfo = response.extraInfo {
            extraInfo = Sep6ExtraInfo(message: responseExtraInfo.message)
        }
        return Sep6TransferResponse.withdrawSuccess(accountId: response.accountId, memoType: response.memoType, memo: response.memo, id: response.id, eta: response.eta, minAmount: response.minAmount, maxAmount: response.maxAmount, feeFixed: response.feeFixed, feePercent: response.feePercent, extraInfo: extraInfo)
    }
    
    internal static func fromDepositSuccessResponse(response: DepositResponse) -> Sep6TransferResponse {
        var extraInfo:Sep6ExtraInfo? = nil
        if let responseExtraInfo = response.extraInfo {
            extraInfo = Sep6ExtraInfo(message: responseExtraInfo.message)
        }
        var instructions:[String:Sep6DepositInstruction]? = nil
        if let responseInstructions = response.instructions {
            instructions = [:]
            for (key, val) in responseInstructions {
                instructions![key] = Sep6DepositInstruction(instruction: val)
            }
        }
        return Sep6TransferResponse.depositSuccess(how: response.how, id: response.id, eta: response.eta, minAmount: response.minAmount, maxAmount: response.maxAmount, feeFixed: response.feeFixed, feePercent: response.feePercent, extraInfo: extraInfo, instructions: instructions)
    }
}

public class Sep6ExtraInfo {
    
    /// Message with additional details about the (deposit or withdrawal) process
    public var message:String?
    
    internal init(message: String? = nil) {
        self.message = message
    }
}

public class Sep6DepositInstruction {
    
    /// The value of the field.
    public var value:String
    
    /// A human-readable description of the field. This can be used by an anchor
    /// to provide any additional information about fields that are not defined
    /// in the SEP-9 standard.
    public var description:String
    
    internal init(value: String, description: String) {
        self.value = value
        self.description = description
    }
    
    internal convenience init(instruction:DepositInstruction) {
        self.init(value: instruction.value, description: instruction.description)
    }
  
}



