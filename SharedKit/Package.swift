// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "DomainKit",
            targets: ["DomainKit"]
        ),
        .library(
            name: "DataKit",
            targets: ["DataKit"]
        ),
        // Domain stubs and fixtures: a separate product so the test targets of
        // the six -App projects do not rewrite the same mocks.
        .library(
            name: "DomainKitTestSupport",
            targets: ["DomainKitTestSupport"]
        ),
    ],
    targets: [
        .target(
            name: "DomainKit"
        ),
        .target(
            name: "DataKit",
            dependencies: ["DomainKit"]
        ),
        .target(
            name: "DomainKitTestSupport",
            dependencies: ["DomainKit"]
        ),
        .testTarget(
            name: "DomainKitTests",
            dependencies: ["DomainKit", "DomainKitTestSupport"]
        ),
        .testTarget(
            name: "DataKitTests",
            dependencies: ["DataKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
