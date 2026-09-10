// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "PresentationKit",
    platforms: [
        .iOS(.v17),
        // Not a platform this builds for — the sources are UIKit. It is declared
        // only because SwiftPM checks the floor against DomainKit and NukeUI,
        // which both require more than the 10.13 default.
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PresentationKit",
            targets: ["PresentationKit"]
        ),
    ],
    dependencies: [
        .package(path: "../SharedKit"),
        .package(url: "https://github.com/kean/Nuke.git", from: "13.2.0"),
    ],
    targets: [
        .target(
            name: "PresentationKit",
            dependencies: [
                .product(name: "DomainKit", package: "SharedKit"),
                .product(name: "NukeUI", package: "Nuke"),
            ]
        ),
        .testTarget(
            name: "PresentationKitTests",
            dependencies: [
                "PresentationKit",
                .product(name: "DomainKit", package: "SharedKit"),
                .product(name: "DomainKitTestSupport", package: "SharedKit"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
