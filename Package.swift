// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AuthKit",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [
        .library(name: "AuthKit", targets: ["AuthKit"]),
        .library(name: "AuthKitUI", targets: ["AuthKitUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.55.6"),
        .package(url: "https://github.com/Anurag-Chourasia/UIComponentsKit.git", exact: "1.3.0"),
        .package(url: "https://github.com/Anurag-Chourasia/DesignTokensKit.git", exact: "1.3.0")
    ],
    targets: [
        .target(name: "AuthKit", dependencies: [.product(name: "Supabase", package: "supabase-swift")]),
        .target(name: "AuthKitUI", dependencies: ["AuthKit", "UIComponentsKit", "DesignTokensKit"], resources: [.process("Resources")]),
        .testTarget(name: "AuthKitTests", dependencies: ["AuthKit"]),
        .testTarget(name: "AuthKitUITests", dependencies: ["AuthKitUI", "AuthKit"])
    ]
)
