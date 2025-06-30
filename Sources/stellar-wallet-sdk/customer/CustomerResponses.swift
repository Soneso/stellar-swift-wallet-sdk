//
//  CustomerResponses.swift
//
//
//  Created by Christian Rogobete on 18.02.25.
//

import Foundation
import stellarsdk

public class GetCustomerResponse {
    public var id:String?
    public var sep12Status:Sep12Status
    public var fields:[String:Field]?
    public var providedFields:[String:ProvidedField]?
    public var message:String?
    
    internal init(info:GetCustomerInfoResponse) {
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
    public var id:String
    
    internal init(info:PutCustomerInfoResponse) {
        self.id = info.id
    }
}

public class Field {
    public var type:FieldType
    public var description:String?
    public var choices:[String]?
    public var optional:Bool?
    
    internal init(field:GetCustomerInfoField) {
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
    public var type:FieldType
    public var description:String?
    public var choices:[String]?
    public var optional:Bool?
    public var sep12Status:Sep12Status?
    public var error:String?
    
    internal init(field:GetCustomerInfoProvidedField) {
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
            self.sep12Status = Sep12Status(rawValue: status)
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

