import ActivityKit
import Foundation

/// Battery Live Activity, shared by the app (starts and updates it) and the
/// widget extension (draws it on the Lock Screen and in the Dynamic Island).
@available(iOS 16.1, *)
struct BatteryActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var left: Int?
        var right: Int?
        var caseLevel: Int?
    }

    var deviceName: String
}
