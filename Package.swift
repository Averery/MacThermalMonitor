// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacThermalMonitor",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "MacThermalMonitor", targets: ["MacThermalMonitor"])],
    targets: [
        .executableTarget(name: "MacThermalMonitor", path: "Sources/MacThermalMonitor"),
        .testTarget(name: "MacThermalMonitorTests", dependencies: ["MacThermalMonitor"], path: "Tests/MacThermalMonitorTests")
    ]
)
