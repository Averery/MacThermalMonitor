import Foundation

public enum ByteRateFormatter {
    public static func string(bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var scaled = value
        var index = 0
        while scaled >= 1024, index < units.count - 1 {
            scaled /= 1024
            index += 1
        }
        return index == 0 ? String(format: "%.0f %@", scaled, units[index]) : String(format: "%.1f %@", scaled, units[index])
    }
}
