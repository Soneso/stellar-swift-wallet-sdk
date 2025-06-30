//
//  FeeBumpTransaction+Encoding.swift
//
//
//  Created by Christian Rogobete on 31.10.24.
//

import stellarsdk

public extension FeeBumpTransaction {
    func toEnvelopeXdrBase64() -> String? {
        do {
            return try encodedEnvelope()
        } catch {
            return nil
        }
    }
}
