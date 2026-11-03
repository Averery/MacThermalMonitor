import SwiftUI
import AppKit
import MacThermalMonitorCore

@main @MainActor
struct MacThermalMonitorApp: App {
    @StateObject private var model = MonitorModel()
    var body: some Scene {
        MenuBarExtra { MenuContent(model: model) } label: {
            Label(model.menuBarTitle, systemImage: "thermometer.medium")
        }
        .menuBarExtraStyle(.window)

        Window("Mac Thermal Monitor", id: "main") { DashboardView(model: model) }
            .defaultSize(width: 520, height: 420)
            .windowResizability(.contentSize)

        Settings { SettingsView(model: model) }
    }
}

@MainActor struct MenuContent: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mac Thermal Monitor").font(.headline)
            ForEach(model.visibleMetrics) { metric in MetricRow(metric: metric) }
            Divider()
            Button("显示监测窗口") { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first { $0.title == "Mac Thermal Monitor" }?.makeKeyAndOrderFront(nil) }
            SettingsLink { Text("设置…") }
            Button("退出") { NSApp.terminate(nil) }
        }.padding(14).frame(minWidth: 260)
    }
}

@MainActor struct DashboardView: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Mac Thermal Monitor").font(.title2.bold()); Spacer(); Text(model.hardwareSummary).foregroundStyle(.secondary) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 12) {
                ForEach(model.visibleMetrics) { metric in MetricCard(metric: metric) }
            }
            Divider()
            Text("最近 10 分钟").font(.headline)
            HistoryChart(samples: model.history)
                .frame(minHeight: 120)
            Text("风扇控制：暂不支持。应用不会写入未验证的硬件控制接口，系统自动控制保持不变。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(minWidth: 480, minHeight: 360)
            .task { await model.start() }
    }
}

struct MetricRow: View { let metric: MetricValue; var body: some View { HStack { Text(metric.name); Spacer(); Text(metric.displayValue).monospacedDigit() } } }
struct MetricCard: View { let metric: MetricValue; var body: some View { VStack(alignment: .leading) { Text(metric.name).font(.caption).foregroundStyle(.secondary); Text(metric.displayValue).font(.title3.monospacedDigit()); Text(metric.source).font(.caption2).foregroundStyle(.tertiary) }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10)) } }

struct HistoryChart: View {
    let samples: [HistorySample]
    var body: some View {
        GeometryReader { geo in
            let values = samples.map(\.memoryPercent)
            let maxValue = max(values.max() ?? 100, 1)
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat(value / maxValue))
                    index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
            }.stroke(Color.accentColor, lineWidth: 2)
        }.overlay(alignment: .topLeading) { Text("内存使用率").font(.caption2).foregroundStyle(.secondary) }
    }
}

@MainActor struct SettingsView: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        Form {
            Picker("刷新频率", selection: $model.refreshInterval) { Text("1 秒").tag(1.0); Text("3 秒").tag(3.0); Text("5 秒").tag(5.0); Text("10 秒").tag(10.0) }
            Toggle("置顶显示", isOn: $model.alwaysOnTop)
            Toggle("跨桌面与全屏空间", isOn: $model.joinAllSpaces)
            Picker("外观", selection: $model.appearance) { Text("跟随系统").tag("system"); Text("浅色").tag("light"); Text("深色").tag("dark") }
            Text("传感器说明：本版本仅展示通过公开 macOS API 可可靠获得的 CPU 使用率、内存与热状态。CPU/GPU/电池摄氏温度和风扇转速若无受支持来源会明确显示不支持，不会猜测传感器含义。")
                .font(.caption).foregroundStyle(.secondary)
            HStack { Text("版本 1.0.0"); Spacer(); Button("打开 GitHub Releases") { NSWorkspace.shared.open(URL(string: "https://github.com/OWNER/MacThermalMonitor/releases")!) } }
        }.padding(20).frame(width: 480)
    }
}
