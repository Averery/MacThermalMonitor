# Mac Thermal Monitor

Native SwiftUI macOS monitor, minimum macOS 15.0. Version 1.1.0 adds a configurable main window, interactive menu bar menu, resizable floating monitor, 10-minute in-memory trend chart, login-item setting, and system-language Chinese/English UI. It reports CPU usage, memory usage, uptime, and system thermal state using public APIs. Unsupported or unverified temperature and fan interfaces are shown as unsupported; no fake values or unsafe fan controls are exposed.

Build with Xcode 16+ using `swift test` and `./Scripts/build-dmg.sh`. The script supports optional `SIGNING_IDENTITY` and `NOTARY_PROFILE` environment variables for Developer ID signing and notarization. Without them, the DMG is an unsigned/unnotarized testing artifact.
