// swift-tools-version: 6.0
// Tools 6.0 builds the target in the Swift 6 language mode.

import PackageDescription

let package = Package(
  name: "alarm_kit",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(name: "alarm-kit", targets: ["alarm_kit"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "alarm_kit",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
