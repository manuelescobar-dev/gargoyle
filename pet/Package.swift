// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Gargoyle",
  platforms: [.macOS(.v14)],
  targets: [
    // Everything real lives here so it can be tested without launching an app.
    .target(name: "GargoyleCore"),
    // A thin shell: activation policy, wiring, run loop.
    .executableTarget(name: "Gargoyle", dependencies: ["GargoyleCore"]),
    .testTarget(name: "GargoyleCoreTests", dependencies: ["GargoyleCore"]),
  ]
)
