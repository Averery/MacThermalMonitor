import XCTest
@testable import MacThermalMonitor

final class MonitorTests: XCTestCase {
    func testFanlessSummaryIsExplicit() { XCTAssertEqual(FanCapability.fanless.summary, "此设备采用无风扇设计") }
    func testHistoryLimitConcept() { XCTAssertEqual(Array((0..<250)).suffix(200).count, 200) }
}
