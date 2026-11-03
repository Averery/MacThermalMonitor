import AppKit
import Charts
import SwiftUI

@main @MainActor
struct MacThermalMonitorApp: App {
    @StateObject private var model = MonitorModel()
    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Label(model.menuBarTitle, systemImage: "thermometer.medium")
        }
        .menuBarExtraStyle(.menu)

        WindowGroup(id: "main") {
            MainWindowView(model: model)
                .preferredColorScheme(model.theme.colorScheme)
                .task { model.start() }
        }
        .defaultSize(width: 900, height: 620)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(model.text("设置…", "Settings…")) { model.configure(section: .display) }
                    .keyboardShortcut(",")
            }
        }
    }
}

@MainActor
private struct MenuContent: View {
    @ObservedObject var model: MonitorModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button(model.text("打开主窗口", "Open main window")) { openWindow(id: "main") }
        Button(model.text("显示悬浮监测窗", "Show floating monitor")) { model.showFloatingWindow() }
        Button(model.text("隐藏悬浮监测窗", "Hide floating monitor")) { model.hideFloatingWindow() }
        Divider()
        ForEach(model.visibleMetrics.prefix(4)) { metric in
            Text("\(metric.kind.title(chinese: model.isChinese)): \(metric.value)")
        }
        Divider()
        Button(model.text("立即刷新", "Refresh now")) { Task { await model.refreshNow() } }
        Button(model.text("显示设置", "Open settings")) { model.configure(section: .display); openWindow(id: "main") }
        Divider()
        Button(model.text("退出 Mac Thermal Monitor", "Quit Mac Thermal Monitor")) { NSApp.terminate(nil) }
    }
}

@MainActor
private struct MainWindowView: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedSection) {
                Section(model.text("监测", "Monitor")) {
                    Label(model.text("概览", "Overview"), systemImage: "rectangle.grid.2x2").tag(MainSection.overview)
                    Label(model.text("显示与悬浮窗", "Display & floating"), systemImage: "macwindow").tag(MainSection.display)
                    Label(model.text("数据与刷新", "Data & refresh"), systemImage: "chart.xyaxis.line").tag(MainSection.data)
                }
                Section(model.text("设备", "Device")) {
                    Label(model.text("能力与限制", "Capabilities"), systemImage: "cpu").tag(MainSection.capabilities)
                    Label(model.text("关于", "About"), systemImage: "info.circle").tag(MainSection.about)
                }
            }
            .navigationTitle("Mac Thermal Monitor")
        } detail: {
            Group {
                switch model.selectedSection {
                case .overview: OverviewView(model: model)
                case .display: DisplaySettingsView(model: model)
                case .data: DataSettingsView(model: model)
                case .capabilities: CapabilitiesView(model: model)
                case .about: AboutView(model: model)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { model.showFloatingWindow() } label: {
                        Label(model.text("显示悬浮窗", "Show floating"), systemImage: "macwindow.on.rectangle")
                    }
                    Button { Task { await model.refreshNow() } } label: {
                        Label(model.text("刷新", "Refresh"), systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

@MainActor
private struct OverviewView: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.text("系统概览", "System overview")).font(.largeTitle.bold())
                        Text(model.hardwareSummary).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(model.text("最后更新", "Last updated")).font(.caption).foregroundStyle(.secondary)
                        Text(model.lastUpdated?.formatted(date: .omitted, time: .standard) ?? "—").monospacedDigit()
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                    ForEach(model.visibleMetrics) { metric in
                        MetricCard(metric: metric, chinese: model.isChinese)
                    }
                }
                GroupBox(model.text("最近 10 分钟趋势", "10-minute trends")) {
                    TrendChart(samples: model.history, chinese: model.isChinese)
                        .frame(height: 230).padding(.top, 6)
                }
                HStack {
                    Button(model.text("显示悬浮监测窗", "Show floating monitor")) { model.showFloatingWindow() }
                        .buttonStyle(.borderedProminent)
                    Button(model.text("配置显示内容", "Configure display")) { model.configure(section: .display) }
                    Spacer()
                    Text(model.text("所有数据只在本机内存中处理。", "All data is processed locally in memory."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
        .navigationTitle(model.text("概览", "Overview"))
    }
}

@MainActor
private struct DisplaySettingsView: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        Form {
            Section(model.text("悬浮监测窗", "Floating monitor")) {
                HStack {
                    Button(model.text("显示监测窗口", "Show monitor window")) { model.showFloatingWindow() }
                        .buttonStyle(.borderedProminent)
                    Button(model.text("隐藏", "Hide")) { model.hideFloatingWindow() }
                }
                Toggle(model.text("始终置顶", "Always on top"), isOn: $model.alwaysOnTop)
                Toggle(model.text("跨桌面与全屏空间显示", "Show across Spaces and full-screen apps"), isOn: $model.joinAllSpaces)
                Toggle(model.text("紧凑模式", "Compact mode"), isOn: $model.compactFloatingWindow)
                HStack {
                    Text(model.text("透明度", "Opacity"))
                    Slider(value: $model.floatingOpacity, in: 0.55...1)
                    Text(model.floatingOpacity, format: .percent.precision(.fractionLength(0))).monospacedDigit().frame(width: 42)
                }
                Text(model.text("窗口可拖动、可调整大小；位置由系统保存。显示器变化后会自动回到可见区域。", "The window can be dragged and resized. Its position is saved and restored to a visible screen when displays change."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(model.text("界面外观", "Appearance")) {
                Picker(model.text("外观", "Appearance"), selection: $model.theme) {
                    Text(model.text("跟随系统", "System")).tag(AppTheme.system)
                    Text(model.text("浅色", "Light")).tag(AppTheme.light)
                    Text(model.text("深色", "Dark")).tag(AppTheme.dark)
                }
                Picker(model.text("语言", "Language"), selection: $model.language) {
                    Text(model.text("跟随系统", "System")).tag(AppLanguage.automatic)
                    Text("简体中文").tag(AppLanguage.chinese)
                    Text("English").tag(AppLanguage.english)
                }
            }
            Section(model.text("启动", "Startup")) {
                Toggle(model.text("登录时启动", "Launch at login"), isOn: $model.launchAtLogin)
                if !model.launchAtLoginMessage.isEmpty { Text(model.launchAtLoginMessage).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle(model.text("显示与悬浮窗", "Display & floating"))
    }
}

@MainActor
private struct DataSettingsView: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        Form {
            Section(model.text("刷新与菜单栏", "Refresh & menu bar")) {
                Picker(model.text("刷新频率", "Refresh interval"), selection: $model.refreshInterval) {
                    Text(model.text("1 秒", "1 second")).tag(1.0)
                    Text(model.text("3 秒", "3 seconds")).tag(3.0)
                    Text(model.text("5 秒", "5 seconds")).tag(5.0)
                    Text(model.text("10 秒", "10 seconds")).tag(10.0)
                }
                Picker(model.text("菜单栏显示", "Menu bar metric"), selection: $model.menuBarMetric) {
                    ForEach(MetricKind.allCases.filter { $0 != .cpuTemperature && $0 != .gpuTemperature && $0 != .fanSpeed }) {
                        Text($0.title(chinese: model.isChinese)).tag($0)
                    }
                }
            }
            Section(model.text("显示指标", "Visible metrics")) {
                ForEach(MetricKind.allCases) { kind in
                    Toggle(kind.title(chinese: model.isChinese), isOn: Binding(
                        get: { model.visibleMetricKinds.contains(kind) },
                        set: { model.setMetric(kind, visible: $0) }
                    ))
                }
                Text(model.text("温度和风扇项只会在具备可靠、可验证来源时显示数值；当前不使用私有接口或猜测传感器含义。", "Temperature and fan values are only shown when a reliable, validated source is available. This app does not use private APIs or guess sensor meanings."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(model.text("数据保留", "Data retention")) {
                Text(model.text("趋势数据仅保存在内存中，最多保留最近 10 分钟。关闭应用后自动清除，不会持续写入磁盘。", "Trend data stays in memory only for up to ten minutes and is discarded when the app quits."))
            }
        }
        .formStyle(.grouped).padding()
        .navigationTitle(model.text("数据与刷新", "Data & refresh"))
    }
}

@MainActor
private struct CapabilitiesView: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        List {
            Section(model.text("当前设备", "Current device")) {
                LabeledContent(model.text("风扇设计", "Fan design"), value: model.hardwareSummary)
                LabeledContent(model.text("最低系统版本", "Minimum system version"), value: "macOS 15.0")
            }
            Section(model.text("已验证能力", "Validated capabilities")) {
                Label(model.text("CPU 瞬时使用率", "Instant CPU usage"), systemImage: "checkmark.circle.fill")
                Label(model.text("内存占用、系统热状态、运行时间", "Memory usage, thermal state, and uptime"), systemImage: "checkmark.circle.fill")
                Label(model.text("菜单栏、主窗口、可调整悬浮窗", "Menu bar, main window, and resizable floating monitor"), systemImage: "checkmark.circle.fill")
            }
            Section(model.text("保守降级", "Conservative fallback")) {
                Label(model.text("CPU/GPU/电池摄氏温度：不支持", "CPU/GPU/battery Celsius: unsupported"), systemImage: "exclamationmark.triangle")
                Label(model.text("风扇转速/控制：暂不支持", "Fan speed/control: not supported yet"), systemImage: "exclamationmark.triangle")
                Text(model.text("这些功能在没有公开、可靠且能覆盖当前硬件的实现前不会启用，也不会请求关闭 SIP 或把应用作为 root 运行。", "These features remain disabled until a public, reliable implementation covers the current hardware. The app never asks to disable SIP or run as root."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(model.text("能力与限制", "Capabilities"))
    }
}

@MainActor
private struct AboutView: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "thermometer.medium").font(.system(size: 40)).foregroundStyle(.tint)
            Text("Mac Thermal Monitor").font(.largeTitle.bold())
            Text(model.text("轻量、原生、仅本地处理的 macOS 监测工具。", "A lightweight native macOS monitoring tool that processes data locally.")).foregroundStyle(.secondary)
            LabeledContent(model.text("版本", "Version"), value: "1.1.0")
            LabeledContent(model.text("许可证", "License"), value: "MIT")
            HStack {
                Link(model.text("打开 GitHub 仓库", "Open GitHub repository"), destination: URL(string: "https://github.com/Averery/MacThermalMonitor")!)
                Link(model.text("查看 Releases", "View Releases"), destination: URL(string: "https://github.com/Averery/MacThermalMonitor/releases")!)
            }
            Spacer()
        }.padding(32).navigationTitle(model.text("关于", "About"))
    }
}

private struct MetricCard: View {
    let metric: MetricValue
    let chinese: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).foregroundStyle(metric.isSupported ? Color.accentColor : .secondary)
                Text(metric.kind.title(chinese: chinese)).font(.headline)
                Spacer()
                if !metric.isSupported { Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary) }
            }
            Text(metric.value).font(.title2.monospacedDigit()).lineLimit(1)
            Text(metric.source).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading).padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.quaternary))
    }
    private var icon: String {
        switch metric.kind {
        case .cpuUsage: "cpu"; case .memoryUsage: "memorychip"; case .thermalState: "thermometer.medium"; case .uptime: "clock"; case .cpuTemperature, .gpuTemperature: "thermometer"; case .fanSpeed: "fan"
        }
    }
}

private struct TrendChart: View {
    let samples: [HistorySample]; let chinese: Bool
    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(x: .value(chinese ? "时间" : "Time", sample.date), y: .value("CPU", sample.cpuPercent))
                    .foregroundStyle(by: .value(chinese ? "指标" : "Metric", "CPU"))
                LineMark(x: .value(chinese ? "时间" : "Time", sample.date), y: .value(chinese ? "内存" : "Memory", sample.memoryPercent))
                    .foregroundStyle(by: .value(chinese ? "指标" : "Metric", chinese ? "内存" : "Memory"))
            }
        }
        .chartYScale(domain: 0...100)
        .chartLegend(position: .bottom)
        .chartXAxis { AxisMarks(values: .stride(by: .minute, count: 2)) }
    }
}
