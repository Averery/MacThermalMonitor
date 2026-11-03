import XCTest
@testable import MacThermalMonitorCore

final class MonitorTests: XCTestCase {
    func testFormatsNetworkRates() {
        XCTAssertEqual(ByteRateFormatter.string(bytesPerSecond: 1_536), "1.5 KB/s")
        XCTAssertEqual(ByteRateFormatter.string(bytesPerSecond: -1), "0 B/s")
    }
}
