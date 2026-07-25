// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "APISignals",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "APISignalsApp", targets: ["APISignalsApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.0")
    ],
    targets: [
        .target(
            name: "APISignalsCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "APISignalsNetwork",
            dependencies: ["APISignalsCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "APISignalsPersistence",
            dependencies: [
                "APISignalsCore",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "APISignalsScripting",
            dependencies: ["APISignalsCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "APISignalsUI",
            dependencies: [
                "APISignalsCore",
                "APISignalsNetwork",
                "APISignalsPersistence"
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "APISignalsApp",
            dependencies: [
                "APISignalsCore",
                "APISignalsNetwork",
                "APISignalsPersistence",
                "APISignalsScripting",
                "APISignalsUI"
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "APISignalsCoreTests",
            dependencies: ["APISignalsCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "APISignalsNetworkTests",
            dependencies: ["APISignalsNetwork"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "APISignalsPersistenceTests",
            dependencies: ["APISignalsPersistence"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "APISignalsScriptingTests",
            dependencies: ["APISignalsScripting"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
