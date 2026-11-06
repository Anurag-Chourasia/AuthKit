// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AuthKit",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [
        .library(name: "AuthKit", targets: ["AuthKit"]),
        .library(name: "AuthKitUI", targets: ["AuthKitUI"]),
        .library(name: "AuthKitSupabase", targets: ["AuthKitSupabase"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.55.6"),
        .package(url: "https://github.com/Anurag-Chourasia/UIComponentsKit.git", "1.3.0"..<"2.0.0"),
        .package(url: "https://github.com/Anurag-Chourasia/DesignTokensKit.git", "1.20.0"..<"2.0.0")
    ],
    targets: [
        .target(name: "AuthKit"),
        .target(name: "AuthKitSupabase", dependencies: ["AuthKit", .product(name: "Supabase", package: "supabase-swift")]),
        .target(name: "AuthKitUI", dependencies: ["AuthKit", "UIComponentsKit", "DesignTokensKit"], resources: [.process("Resources")]),
        .testTarget(name: "AuthKitTests", dependencies: ["AuthKit", "AuthKitSupabase", .product(name: "Supabase", package: "supabase-swift")]),
        .testTarget(name: "AuthKitUITests", dependencies: ["AuthKitUI", "AuthKit"])
    ]
)
