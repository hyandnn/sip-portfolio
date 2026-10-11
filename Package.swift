// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sipfolio",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Sipfolio", targets: ["Sipfolio"]),
        .library(name: "SipfolioCore", targets: ["SipfolioCore"])
    ],
    targets: [
        .target(name: "SipfolioCore"),
        .executableTarget(name: "Sipfolio", dependencies: ["SipfolioCore"], resources: [.copy("Resources")]),
        .target(name: "SipfolioTestSupport", path: "Tests/SipfolioTestSupport", resources: [.copy("Fixtures")]),
        .testTarget(name: "SipfolioCoreTests", dependencies: ["SipfolioCore", "SipfolioTestSupport"]),
        .testTarget(name: "SipfolioUITests", dependencies: ["Sipfolio", "SipfolioCore", "SipfolioTestSupport"])
    ]
)
