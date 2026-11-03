import AppKit
import SwiftUI

@MainActor
final class FloatingWindowController: NSObject {
    private var panel: NSPanel?

    func show(model: MonitorModel) {
        if panel == nil {
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 190),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            newPanel.title = "Mac Thermal Monitor"
            newPanel.titleVisibility = .hidden
            newPanel.titlebarAppearsTransparent = true
            newPanel.isReleasedWhenClosed = false
            newPanel.minSize = NSSize(width: 260, height: 140)
            newPanel.setFrameAutosaveName("MacThermalMonitorFloatingPanel")
            newPanel.contentView = NSHostingView(rootView: FloatingMonitorView(model: model))
            panel = newPanel
        }
        guard let panel else { return }
        if !panel.frameIntersectsVisibleScreen { panel.center() }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() { panel?.orderOut(nil) }

    func apply(_ model: MonitorModel) {
        guard let panel else { return }
        panel.level = model.alwaysOnTop ? .floating : .normal
        panel.alphaValue = model.floatingOpacity
        panel.collectionBehavior = model.joinAllSpaces ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.managed]
        panel.appearance = switch model.theme { case .system: nil; case .light: NSAppearance(named: .aqua); case .dark: NSAppearance(named: .darkAqua) }
        panel.contentView = NSHostingView(rootView: FloatingMonitorView(model: model))
    }
}

private extension NSWindow {
    var frameIntersectsVisibleScreen: Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }
}

@MainActor
private struct FloatingMonitorView: View {
    @ObservedObject var model: MonitorModel
    var body: some View {
        Group {
            if model.compactFloatingWindow {
                HStack(spacing: 14) {
                    ForEach(model.floatingMetrics.prefix(3)) { metric in CompactMetric(metric: metric, chinese: model.isChinese) }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "thermometer.medium").foregroundStyle(.tint)
                        Text("Mac Thermal Monitor").font(.headline)
                        Spacer()
                        Text(model.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "—").font(.caption2).foregroundStyle(.secondary)
                    }
                    Divider()
                    ForEach(model.floatingMetrics) { metric in
                        HStack {
                            Text(metric.kind.title(chinese: model.isChinese)).foregroundStyle(.secondary)
                            Spacer()
                            Text(metric.value).font(.body.monospacedDigit())
                        }
                    }
                    if model.floatingMetrics.isEmpty {
                        Text(model.text("正在读取系统数据…", "Reading system data…")).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(model.compactFloatingWindow ? 10 : 16)
        .frame(minWidth: model.compactFloatingWindow ? 250 : 280, minHeight: model.compactFloatingWindow ? 34 : 140)
        .background(.regularMaterial)
    }
}

private struct CompactMetric: View {
    let metric: MetricValue
    let chinese: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(metric.kind.title(chinese: chinese)).font(.caption2).foregroundStyle(.secondary)
            Text(metric.value).font(.caption.monospacedDigit()).lineLimit(1)
        }
    }
}
