# Mac Thermal Monitor

轻量、原生 SwiftUI 的 macOS 温度与资源监测工具。最低 macOS 15.0，Apple Silicon 优先；所有数据本地处理。

## 当前状态

v1.2.0 提供实时 CPU 使用率、内存占用、系统热状态、运行时间、网速、十分钟趋势、可配置主窗口、控制中心式菜单栏和独立悬浮监测窗。天气按用户手动选择的城市获取；CPU/GPU/电池摄氏温度必须有可靠、可验证的数据源才会显示，当前没有可靠的公开通用接口，因此会显示“不支持”。

| 项目 | 状态 | 来源/限制 |
|---|---|---|
| CPU 使用率 | 已实现 | host_statistics 差分采样 |
| 内存占用 | 已实现 | host_statistics64 |
| 系统热状态 | 已实现 | ProcessInfo.thermalState，不是摄氏温度 |
| 实时网速 | 已实现 | 本机网卡字节计数差分 |
| 天气 | 已实现 | 用户手动城市；仅发送城市名称/坐标到 Open-Meteo |
| CPU/GPU/电池温度 | 待验证 | 无公开且可靠的通用 API |

## 构建

需要 Xcode 16 或更新版本、macOS 15 SDK。

```bash
swift test
./Scripts/build-dmg.sh
```

脚本会在 macOS 上执行 Release 构建、生成应用包、创建 DMG 与 SHA-256 文件。没有 Developer ID 时产物是未公证测试包；不会声称通过 Apple 验证。

## 架构与签名

默认使用当前 runner 架构。GitHub Actions 的发布工作流在 arm64 runner 上构建 arm64 包，并明确标记为 unsigned/unnotarized；Universal 2 需要同时存在并经验证的 arm64 与 x86_64 构建环境，不能仅凭 arm64 runner 声称支持。

## 开源

MIT License。贡献方式见 [CONTRIBUTING.md](CONTRIBUTING.md)。
