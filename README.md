# Mac Thermal Monitor

轻量、原生 SwiftUI 的 macOS 温度与资源监测工具。最低 macOS 15.0，Apple Silicon 优先；所有数据本地处理。

## 当前状态

v1.0.0 提供 CPU 使用率、内存占用、系统热状态、菜单栏与监测窗口。CPU/GPU/电池摄氏温度和风扇转速必须有可靠、可验证的数据源才会显示；当前不使用未公开传感器接口，因此这些项目会显示“不支持”。风扇控制入口暂不启用，不修改系统自动控制。

| 项目 | 状态 | 来源/限制 |
|---|---|---|
| CPU 使用率 | 已实现 | host_processor_info |
| 内存占用 | 已实现 | host_statistics64 |
| 系统热状态 | 已实现 | ProcessInfo.thermalState，不是摄氏温度 |
| CPU/GPU/电池温度 | 待验证 | 无公开且可靠的通用 API |
| 风扇转速/控制 | 待验证 | 不安装驱动、不关闭 SIP、不假造控制 |
| M2 MacBook Air | 能力识别 | 无风扇设计提示依赖系统机型名称 |

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
