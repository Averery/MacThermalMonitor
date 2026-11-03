// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacThermalMonitor",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "MacThermalMonitor", targets: ["MacThermalMonitor"])],
    targets: [
        .target(name: "MacThermalMonitorCore", path: "Sources/MacThermalMonitorCore"),
        .executableTarget(name: "MacThermalMonitor", dependencies: ["MacThermalMonitorCore"], path: "Sources/MacThermalMonitor"),
        .testTarget(name: "MacThermalMonitorTests", dependencies: ["MacThermalMonitorCore"], path: "Tests/MacThermalMonitorTests")
    ]
)
