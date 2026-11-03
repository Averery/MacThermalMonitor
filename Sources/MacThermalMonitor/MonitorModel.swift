import AppKit
import Darwin
import Foundation
import ServiceManagement
import SwiftUI
enum MetricKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case cpuUsage, memoryUsage, thermalState, uptime, cpuTemperature, gpuTemperature, networkDownload, networkUpload
    var id: String { rawValue }
    func title(chinese: Bool) -> String {
        switch self {
        case .cpuUsage: chinese ? "CPU 使用率" : "CPU usage"
        case .memoryUsage: chinese ? "内存占用" : "Memory usage"
        case .thermalState: chinese ? "系统热状态" : "Thermal state"
        case .uptime: chinese ? "系统运行时间" : "System uptime"
        case .cpuTemperature: chinese ? "CPU 温度" : "CPU temperature"
        case .gpuTemperature: chinese ? "GPU 温度" : "GPU temperature"
        case .networkDownload: chinese ? "下载速度" : "Download speed"
        case .networkUpload: chinese ? "上传速度" : "Upload speed"
        }
    }
}

enum MainSection: String, CaseIterable, Identifiable { case overview, display, data, weather, capabilities, about; var id: String { rawValue } }
enum AppTheme: String, CaseIterable, Identifiable { case system, light, dark; var id: String { rawValue }; var colorScheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } } }
enum AppLanguage: String, CaseIterable, Identifiable { case automatic, chinese, english; var id: String { rawValue } }

struct MetricValue: Identifiable, Sendable {
    let kind: MetricKind; let value: String; let source: String; let isSupported: Bool
    var id: String { kind.id }
}
struct HistorySample: Identifiable, Sendable {
    let date: Date; let cpuPercent: Double; let memoryPercent: Double
    var id: Date { date }
}
struct MetricsSnapshot: Sendable { let metrics: [MetricValue]; let cpuPercent: Double; let memoryPercent: Double }

@MainActor
final class MonitorModel: ObservableObject {
    @Published private(set) var metrics: [MetricValue] = []
    @Published private(set) var history: [HistorySample] = []
    @Published var selectedSection: MainSection = .overview
    @Published var refreshInterval: Double { didSet { save(refreshInterval, Key.refreshInterval) } }
    @Published var alwaysOnTop: Bool { didSet { save(alwaysOnTop, Key.alwaysOnTop); floatingWindow.apply(self) } }
    @Published var joinAllSpaces: Bool { didSet { save(joinAllSpaces, Key.joinAllSpaces); floatingWindow.apply(self) } }
    @Published var floatingOpacity: Double { didSet { save(floatingOpacity, Key.floatingOpacity); floatingWindow.apply(self) } }
    @Published var compactFloatingWindow: Bool { didSet { save(compactFloatingWindow, Key.compactFloatingWindow); floatingWindow.apply(self) } }
    @Published var theme: AppTheme { didSet { save(theme.rawValue, Key.theme) } }
    @Published var language: AppLanguage { didSet { save(language.rawValue, Key.language) } }
    @Published var menuBarMetric: MetricKind { didSet { save(menuBarMetric.rawValue, Key.menuBarMetric) } }
    @Published var weatherEnabled: Bool { didSet { save(weatherEnabled, Key.weatherEnabled) } }
    @Published var weatherCity: String { didSet { save(weatherCity, Key.weatherCity) } }
    @Published var launchAtLogin: Bool { didSet { updateLaunchAtLogin() } }
    @Published private(set) var launchAtLoginMessage = ""
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var weather: WeatherReport?
    @Published private(set) var weatherMessage = ""
    @Published var visibleMetricKinds: Set<MetricKind> { didSet { save(visibleMetricKinds.map(\.rawValue), Key.visibleMetricKinds) } }

    let floatingWindow = FloatingWindowController()
    private let collector = SystemMetricsCollector()
    private let networkCollector = NetworkSpeedCollector()
    private let weatherService = WeatherService()
    private var monitorTask: Task<Void, Never>?
    private var lastWeatherRefresh: Date?
    private let defaults = UserDefaults.standard

    init() {
        refreshInterval = defaults.double(forKey: Key.refreshInterval).nonZero(or: 3)
        alwaysOnTop = defaults.object(forKey: Key.alwaysOnTop) as? Bool ?? true
        joinAllSpaces = defaults.object(forKey: Key.joinAllSpaces) as? Bool ?? false
        floatingOpacity = defaults.object(forKey: Key.floatingOpacity) as? Double ?? 0.96
        compactFloatingWindow = defaults.object(forKey: Key.compactFloatingWindow) as? Bool ?? false
        theme = AppTheme(rawValue: defaults.string(forKey: Key.theme) ?? "system") ?? .system
        language = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "automatic") ?? .automatic
        menuBarMetric = MetricKind(rawValue: defaults.string(forKey: Key.menuBarMetric) ?? "cpuUsage") ?? .cpuUsage
        weatherEnabled = defaults.object(forKey: Key.weatherEnabled) as? Bool ?? true
        weatherCity = defaults.string(forKey: Key.weatherCity) ?? TimeZone.current.identifier.split(separator: "/").last.map(String.init) ?? "Shanghai"
        launchAtLogin = SMAppService.mainApp.status == .enabled
        let stored = defaults.stringArray(forKey: Key.visibleMetricKinds) ?? [MetricKind.cpuUsage.rawValue, MetricKind.memoryUsage.rawValue, MetricKind.thermalState.rawValue, MetricKind.uptime.rawValue]
        var visible = Set(stored.compactMap(MetricKind.init(rawValue:)))
        visible.formUnion([.networkDownload, .networkUpload])
        visibleMetricKinds = visible
    }

    var isChinese: Bool {
        switch language {
        case .chinese: true
        case .english: false
        case .automatic: Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
        }
    }
    func text(_ zh: String, _ en: String) -> String { isChinese ? zh : en }
    var hardwareSummary: String { text("本机实时采集 · 不上传系统数据", "Local real-time collection · no system data upload") }
    var menuBarTitle: String { metric(for: menuBarMetric)?.value ?? text("读取中", "Loading") }
    var visibleMetrics: [MetricValue] { metrics.filter { visibleMetricKinds.contains($0.kind) } }
    var floatingMetrics: [MetricValue] {
        visibleMetrics.filter { [.cpuUsage, .memoryUsage, .networkDownload, .networkUpload].contains($0.kind) }.prefix(4).map { $0 }
    }

    func start() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.refreshInterval))
            }
        }
    }
    func refreshNow() async { await refresh() }
    func setMetric(_ kind: MetricKind, visible: Bool) {
        if visible { visibleMetricKinds.insert(kind) }
        else if visibleMetricKinds.count > 1 { visibleMetricKinds.remove(kind) }
    }
    func showFloatingWindow() { floatingWindow.show(model: self); floatingWindow.apply(self) }
    func hideFloatingWindow() { floatingWindow.hide() }
    func configure(section: MainSection) { selectedSection = section }
    func refreshWeatherNow() async {
        guard weatherEnabled else { return }
        let city = weatherCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty else {
            weatherMessage = text("请输入城市名称", "Enter a city name")
            return
        }
        do {
            weather = try await weatherService.currentWeather(for: city)
            weatherMessage = ""
            lastWeatherRefresh = .now
        } catch {
            weatherMessage = text("天气读取失败：\(error.localizedDescription)", "Could not fetch weather: \(error.localizedDescription)")
        }
    }

    private func refresh() async {
        let snapshot = await collector.collect(chinese: isChinese)
        let network = await networkCollector.collect()
        guard !Task.isCancelled else { return }
        metrics = snapshot.metrics + [
            MetricValue(kind: .networkDownload, value: network.downloadText(chinese: isChinese), source: network.interfaceName ?? text("未检测到活动网络接口", "No active network interface"), isSupported: true),
            MetricValue(kind: .networkUpload, value: network.uploadText(chinese: isChinese), source: network.interfaceName ?? text("未检测到活动网络接口", "No active network interface"), isSupported: true)
        ]
        lastUpdated = .now
        history.append(HistorySample(date: .now, cpuPercent: snapshot.cpuPercent, memoryPercent: snapshot.memoryPercent))
        history.removeAll { $0.date < Date.now.addingTimeInterval(-600) }
        if weatherEnabled, lastWeatherRefresh?.addingTimeInterval(900) ?? .distantPast < .now {
            await refreshWeatherNow()
        }
    }
    func metric(for kind: MetricKind) -> MetricValue? { metrics.first { $0.kind == kind } }
    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginMessage = text("已更新登录项设置", "Login item updated")
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginMessage = text("无法更新登录项：\(error.localizedDescription)", "Could not update login item: \(error.localizedDescription)")
        }
    }
    private func save<T>(_ value: T, _ key: String) { defaults.set(value, forKey: key) }
    private enum Key {
        static let refreshInterval = "refreshInterval", alwaysOnTop = "alwaysOnTop", joinAllSpaces = "joinAllSpaces", floatingOpacity = "floatingOpacity", compactFloatingWindow = "compactFloatingWindow", theme = "theme", language = "language", menuBarMetric = "menuBarMetric", visibleMetricKinds = "visibleMetricKinds", weatherEnabled = "weatherEnabled", weatherCity = "weatherCity"
    }
}

private extension Double { func nonZero(or fallback: Double) -> Double { self == 0 ? fallback : self } }

actor SystemMetricsCollector {
    private var previousTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    func collect(chinese: Bool) -> MetricsSnapshot {
        let cpu = cpuUsage(), memory = memoryUsage()
        let unsupported = chinese ? "不支持" : "Unsupported"
        let publicAPI = chinese ? "macOS 公共 API" : "macOS public API"
        let metrics = [
            MetricValue(kind: .cpuUsage, value: String(format: "%.1f%%", cpu), source: "host_statistics / \(publicAPI)", isSupported: true),
            MetricValue(kind: .memoryUsage, value: String(format: "%.1f%%", memory), source: "host_statistics64 / \(publicAPI)", isSupported: true),
            MetricValue(kind: .thermalState, value: thermalText(ProcessInfo.processInfo.thermalState, chinese: chinese), source: "ProcessInfo.thermalState", isSupported: true),
            MetricValue(kind: .uptime, value: uptimeText(chinese: chinese), source: "ProcessInfo.systemUptime", isSupported: true),
            MetricValue(kind: .cpuTemperature, value: unsupported, source: chinese ? "无可靠的公开通用传感器接口" : "No reliable public sensor API", isSupported: false),
            MetricValue(kind: .gpuTemperature, value: unsupported, source: chinese ? "无可靠的公开通用传感器接口" : "No reliable public sensor API", isSupported: false)
        ]
        return MetricsSnapshot(metrics: metrics, cpuPercent: cpu, memoryPercent: memory)
    }
    private func cpuUsage() -> Double {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &load) { pointer in pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) } }
        guard result == KERN_SUCCESS else { return 0 }
        let ticks = (load.cpu_ticks.0, load.cpu_ticks.1, load.cpu_ticks.2, load.cpu_ticks.3)
        defer { previousTicks = (ticks.0, ticks.1, ticks.2, ticks.3) }
        guard let previousTicks else { return 0 }
        let user = ticks.0 &- previousTicks.user, system = ticks.1 &- previousTicks.system, idle = ticks.2 &- previousTicks.idle, nice = ticks.3 &- previousTicks.nice
        let total = Double(user &+ system &+ idle &+ nice)
        return total > 0 ? Double(user &+ system &+ nice) / total * 100 : 0
    }
    private func memoryUsage() -> Double {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) } }
        guard result == KERN_SUCCESS else { return 0 }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS, pageSize > 0 else { return 0 }
        let usedPages = Double(info.active_count + info.wire_count + info.compressor_page_count)
        let totalPages = Double(ProcessInfo.processInfo.physicalMemory) / Double(pageSize)
        return totalPages > 0 ? usedPages / totalPages * 100 : 0
    }
    private func thermalText(_ state: ProcessInfo.ThermalState, chinese: Bool) -> String {
        switch state { case .nominal: chinese ? "正常" : "Nominal"; case .fair: chinese ? "较高" : "Fair"; case .serious: chinese ? "严重" : "Serious"; case .critical: chinese ? "临界" : "Critical"; @unknown default: chinese ? "未知" : "Unknown" }
    }
    private func uptimeText(chinese: Bool) -> String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime), hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return chinese ? "\(hours) 小时 \(minutes) 分" : "\(hours)h \(minutes)m"
    }
}
