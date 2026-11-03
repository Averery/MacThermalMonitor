import Darwin
import Foundation
import MacThermalMonitorCore

struct NetworkUsage: Sendable {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let interfaceName: String?

    func downloadText(chinese: Bool) -> String { "↓ (ByteRateFormatter.string(bytesPerSecond: downloadBytesPerSecond))" }
    func uploadText(chinese: Bool) -> String { "↑ (ByteRateFormatter.string(bytesPerSecond: uploadBytesPerSecond))" }
}

actor NetworkSpeedCollector {
    private var previous: InterfaceCounters?

    func collect() -> NetworkUsage {
        let current = InterfaceCounters.read()
        defer { previous = current }
        guard let previous else {
            return NetworkUsage(downloadBytesPerSecond: 0, uploadBytesPerSecond: 0, interfaceName: current.primaryInterface)
        }
        let seconds = max(current.date.timeIntervalSince(previous.date), 0.001)
        let downloaded = Double(current.received &- previous.received) / seconds
        let uploaded = Double(current.sent &- previous.sent) / seconds
        return NetworkUsage(downloadBytesPerSecond: downloaded, uploadBytesPerSecond: uploaded, interfaceName: current.primaryInterface)
    }
}

private struct InterfaceCounters: Sendable {
    let date: Date
    let received: UInt64
    let sent: UInt64
    let primaryInterface: String?

    static func read() -> InterfaceCounters {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let interfaces else {
            return InterfaceCounters(date: .now, received: 0, sent: 0, primaryInterface: nil)
        }
        defer { freeifaddrs(interfaces) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var primary: String?
        var cursor: UnsafeMutablePointer<ifaddrs>? = interfaces
        while let item = cursor {
            defer { cursor = item.pointee.ifa_next }
            let flags = Int32(item.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let dataPointer = item.pointee.ifa_data,
                  let namePointer = item.pointee.ifa_name else { continue }
            let name = String(cString: namePointer)
            guard name.hasPrefix("en") || name.hasPrefix("bridge") else { continue }
            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            received &+= UInt64(data.ifi_ibytes)
            sent &+= UInt64(data.ifi_obytes)
            if primary == nil, name.hasPrefix("en") { primary = name }
        }
        return InterfaceCounters(date: .now, received: received, sent: sent, primaryInterface: primary)
    }
}
