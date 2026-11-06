// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "core_ads",
    platforms: [.iOS("15.0")],
    products: [.library(name: "core-ads", targets: ["core_ads"])],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads", from: "13.3.0"),
    ],
    targets: [
        .target(
            name: "core_ads",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            ],
            resources: [.process("Resources")]
        ),
    ]
)
