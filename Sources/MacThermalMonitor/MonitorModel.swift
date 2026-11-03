import Foundation
import Darwin
import AppKit
import MacThermalMonitorCore

struct MetricValue: Identifiable, Sendable { let id: String; let name: String; let displayValue: String; let source: String }
struct HistorySample: Sendable { let date: Date; let memoryPercent: Double }

@MainActor final class MonitorModel: ObservableObject {
    @Published private(set) var visibleMetrics: [MetricValue] = []
    @Published private(set) var history: [HistorySample] = []
    @Published var refreshInterval: Double = 3
    @Published var alwaysOnTop = false
    @Published var joinAllSpaces = false
    @Published var appearance = "system"
    private var task: Task<Void, Never>?
    private let collector = SystemMetricsCollector()

    var menuBarTitle: String { visibleMetrics.first?.displayValue ?? "监测中" }
    var hardwareSummary: String { collector.hardwareSummary }

    func start() async { guard task == nil else { return }; await refresh(); task = Task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(refreshInterval)); await refresh() } } }
    private func refresh() async {
        let snapshot = await Task.detached(priority: .utility) { SystemMetricsCollector().collect() }.value
        visibleMetrics = snapshot.metrics
        history.append(HistorySample(date: .now, memoryPercent: snapshot.memoryPercent))
        history = Array(history.suffix(200))
    }
}

struct MetricsSnapshot: Sendable { let metrics: [MetricValue]; let memoryPercent: Double }

final class SystemMetricsCollector: Sendable {
    let hardwareSummary: String
    init() { hardwareSummary = FanCapability.detect().summary }
    func collect() -> MetricsSnapshot {
        let cpu = cpuUsage()
        let memory = memoryUsage()
        let thermal = ProcessInfo.processInfo.thermalState
        let metrics = [
            MetricValue(id: "cpu", name: "CPU 使用率", displayValue: String(format: "%.1f%%", cpu), source: "host_processor_info / macOS 公共 API"),
            MetricValue(id: "memory", name: "内存占用", displayValue: String(format: "%.1f%%", memory), source: "host_statistics64 / macOS 公共 API"),
            MetricValue(id: "thermal", name: "系统热状态", displayValue: thermalLabel(thermal), source: "ProcessInfo.thermalState（不是摄氏温度）"),
            MetricValue(id: "cpuTemp", name: "CPU 温度", displayValue: "不支持", source: "未使用未公开/未验证传感器接口"),
            MetricValue(id: "gpuTemp", name: "GPU 温度", displayValue: "不支持", source: "未使用未公开/未验证传感器接口"),
            MetricValue(id: "fan", name: "风扇转速", displayValue: FanCapability.detect().isFanless ? "无风扇设计" : "不支持", source: "硬件能力检测；未接入控制驱动")
        ]
        return MetricsSnapshot(metrics: metrics, memoryPercent: memory)
    }
    private func thermalLabel(_ state: ProcessInfo.ThermalState) -> String { switch state { case .nominal: "正常"; case .fair: "较高"; case .serious: "严重"; case .critical: "临界"; @unknown default: "未知" } }
    private func memoryUsage() -> Double { var info = vm_statistics64(); var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride); let result = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) } }; guard result == KERN_SUCCESS else { return 0 }; var pageSize: vm_size_t = 0; guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS, pageSize > 0 else { return 0 }; let used = Double(info.active_count + info.wire_count + info.compressor_page_count); let total = Double(ProcessInfo.processInfo.physicalMemory) / Double(pageSize); return total > 0 ? used / total * 100 : 0 }
    private func cpuUsage() -> Double { var load = host_cpu_load_info(); var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride); let result = withUnsafeMutablePointer(to: &load) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }; }; guard result == KERN_SUCCESS else { return 0 }; let total = Double(load.cpu_ticks.0 + load.cpu_ticks.1 + load.cpu_ticks.2 + load.cpu_ticks.3); return total > 0 ? Double(load.cpu_ticks.0 + load.cpu_ticks.1 + load.cpu_ticks.2) / total * 100 : 0 }
}

