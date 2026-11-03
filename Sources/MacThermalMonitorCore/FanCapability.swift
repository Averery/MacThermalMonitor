import Foundation

public enum FanCapability: Sendable, Equatable {
    case fanless
    case unknown

    public var isFanless: Bool { self == .fanless }
    public var summary: String { isFanless ? "此设备采用无风扇设计" : "风扇能力未验证" }

    public static func detect(hostName: String = Host.current().localizedName ?? "") -> FanCapability {
        hostName.lowercased().contains("macbook air") ? .fanless : .unknown
    }
}
