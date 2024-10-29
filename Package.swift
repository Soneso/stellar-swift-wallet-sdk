// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "stellar-wallet-sdk",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "stellar-wallet-sdk",
            targets: ["stellar-wallet-sdk"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/Soneso/stellar-ios-mac-sdk", exact: "3.0.1-beta.1"),
        //.package(path: "../stellar-ios-mac-sdk") // if it is not updateing, you can use fix_spm_cache.sh
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "stellar-wallet-sdk",
            dependencies: [
                // Dependencies declare other packages that this package depends on.
                .product(name:"stellarsdk", package:"stellar-ios-mac-sdk"),
            ]
        ),
        .testTarget(
            name: "stellar-wallet-sdkTests",
            dependencies: ["stellar-wallet-sdk"]),
    ]
)
