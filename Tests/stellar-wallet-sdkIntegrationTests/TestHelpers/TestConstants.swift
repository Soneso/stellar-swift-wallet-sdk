//
//  TestConstants.swift
//  stellar-wallet-sdkIntegrationTests
//
//  Integration test constants and configuration
//

import Foundation
import stellarsdk

struct TestConstants {
    
    // MARK: - Network Configuration
    
    static let network = Network.testnet
    
    // MARK: - Anchor Configuration
    
    /// Live anchor platform for SEP testing
    static let anchorDomain = "anchor-sep-server-dev.stellar.org"
    
    // MARK: - Docker Service URLs
    
    struct DockerServices {
        // Recovery servers (SEP-30)
        static let recoveryServer1Endpoint = "http://localhost:8000"
        static let recoveryServer1AuthEndpoint = "http://localhost:8001"
        static let recoveryServer2Endpoint = "http://localhost:8002"
        static let recoveryServer2AuthEndpoint = "http://localhost:8003"
        
    }
    
    // MARK: - Test Assets
    
    struct Assets {
        /// USDC asset used in anchor platform tests
        static let usdcAssetCode = "USDC"
        static let usdcIssuer = "GDQOE23CFSUMSVQK4Y5JHPPYK73VYCNHZHA7ENKCV37P6SUEO6XQBKPP"
        
        static var usdcAsset: Asset {
            return Asset(type: AssetType.ASSET_TYPE_CREDIT_ALPHANUM4,
                        code: usdcAssetCode,
                        issuer: try! KeyPair(accountId: usdcIssuer))!
        }
    }
    
    // MARK: - Test Accounts
    
    struct TestAccounts {
        /// Seeds for generating test keypairs
        static let testSeed1 = "SAWDHXQG6ROJSU4QGCW7NSTYFHPTPIVC2NC7QKVTO7PZCSO2WEBGM54W"
        static let testSeed2 = "SCJFFNMWF7XWFZXWYHQINRFZIBQFXIMVYCNLW5UMSW5V2L5K5UIVQVFB"
        static let testSeed3 = "SAKMXFQKZ6LZRFTPAIQKZNTSV6HL5ZMVDUWV4JWHS5DQIYCLHCKBX7SS"
        static let testSeed4 = "SD5W5MLFISTDVVSSYZWPZCDIXUPSCQMS6UVCRP37UCQIMFMQ4BQG5FYD"
        
        /// Public keys for test accounts
        static let testPublicKey1 = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
        static let testPublicKey2 = "GAIVQGYHI7G7QE5M37M5RQN2YTRQJPAQZGXDB5FRUQW4OPWIOQNOZBOL"
        static let testPublicKey3 = "GCR2V5VON3EWSTDICDLJV6NK7OCNT2P5UXI7F2SDXUQ3M64P6FN2IOU2"
        static let testPublicKey4 = "GDMXQEHJYQISLFWOLHNUJ5B4G7RN5C45V3JLG6L473CPXESMJCEH3BYU"
    }
    
    // MARK: - Timeouts
    
    struct Timeouts {
        /// Short timeout for simple operations (30 seconds)
        static let short: TimeInterval = 30
        
        /// Medium timeout for transaction submission (60 seconds)
        static let medium: TimeInterval = 60
        
        /// Long timeout for complex operations like SEP-6/24 flows (300 seconds)
        static let long: TimeInterval = 300
        
        /// Docker service startup timeout (120 seconds)
        static let dockerStartup: TimeInterval = 120
        
        /// Polling interval for async operations (2 seconds)
        static let pollingInterval: TimeInterval = 2
    }
    
    // MARK: - SEP-12 Test Data
    
    struct Sep12TestData {
        static let firstName = "John"
        static let lastName = "Smith"
        static let emailAddress = "test@stellar.org"
        static let bankNumber = "12345"
        static let bankAccountNumber = "67890"
        
        static var sep9Info: [String: String] {
            return [
                "first_name": firstName,
                "last_name": lastName,
                "email_address": emailAddress,
                "bank_number": bankNumber,
                "bank_account_number": bankAccountNumber
            ]
        }
    }
}
