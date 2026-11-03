import XCTest
@testable import MacThermalMonitorCore

final class MonitorTests: XCTestCase {
    func testFanlessSummaryIsExplicit() { XCTAssertEqual(FanCapability.fanless.summary, "此设备采用无风扇设计") }
    func testMacBookAirIsDetectedAsFanless() { XCTAssertEqual(FanCapability.detect(hostName: "MacBook Air (M2, 2022)"), .fanless) }
    func testHistoryLimitConcept() { XCTAssertEqual(Array((0..<250)).suffix(200).count, 200) }
}
