# Mac Thermal Monitor

Native SwiftUI macOS monitor, minimum macOS 15.0. Version 1.2.0 adds a control-center-style menu bar panel for temperature status, network speed, system resources, and city-based weather. It reports CPU usage, memory usage, uptime, network throughput, and system thermal state using public APIs. Unsupported temperature interfaces are shown as unsupported; no values are fabricated.

Build with Xcode 16+ using `swift test` and `./Scripts/build-dmg.sh`. The script supports optional `SIGNING_IDENTITY` and `NOTARY_PROFILE` environment variables for Developer ID signing and notarization. Without them, the DMG is an unsigned/unnotarized testing artifact.
