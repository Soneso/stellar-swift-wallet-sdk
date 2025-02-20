//
//  CustomerResponses.swift
//
//
//  Created by Christian Rogobete on 18.02.25.
//

import Foundation
import stellarsdk

public class GetCustomerResponse {
    var id:String?
    var sep12Status:Sep12Status
    var fields:[String:Field]?
    var providedFields:[String:ProvidedField]?
    var message:String?
    init(info:GetCustomerInfoResponse) {
        self.id = info.id
        self.sep12Status = Sep12Status(rawValue: info.status) ?? Sep12Status.neesdInfo
        if let fields = info.fields {
            self.fields = [:]
            for (key, value) in fields {
                self.fields![key] = Field(field: value)
            }
        }
        if let providedFields = info.providedFields {
            self.providedFields = [:]
            for (key, value) in providedFields {
                self.providedFields![key] = ProvidedField(field: value)
            }
        }
        self.message = info.message
    }
}

public class AddCustomerResponse {
    var id:String
    init(info:PutCustomerInfoResponse) {
        self.id = info.id
    }
}

public class Field {
    var type:FieldType
    var description:String?
    var choices:[String]?
    var optional:Bool?
    
    init(field:GetCustomerInfoField) {
        self.type = FieldType(rawValue: field.type) ?? FieldType.string
        self.description = field.description
        if let choices = field.choices {
            self.choices = []
            for choice in choices {
                if choice is String {
                    self.choices!.append(choice as! String)
                }
            }
        }
        self.optional = field.optional
    }
}

public class ProvidedField {
    var type:FieldType
    var description:String?
    var choices:[String]?
    var optional:Bool?
    var sep12Status:Sep12Status?
    var error:String?
    
    init(field:GetCustomerInfoProvidedField) {
        self.type = FieldType(rawValue: field.type) ?? FieldType.string
        self.description = field.description
        if let choices = field.choices {
            self.choices = []
            for choice in choices {
                if choice is String {
                    self.choices!.append(choice as! String)
                }
            }
        }
        self.optional = field.optional
        if let status = field.status {
            self.sep12Status = Sep12Status(rawValue: field.status!)
        }
        self.error = field.error
    }
}

public enum Sep12Status:String {
    case neesdInfo = "NEEDS_INFO"
    case accepted = "ACCEPTED"
    case processing = "PROCESSING"
    case rejected = "REJECTED"
    case verificationRequired = "VERIFICATION_REQUIRED"
}

public enum FieldType:String {
    case string = "string"
    case binary = "binary"
    case number = "number"
    case date = "date"
}

