import Foundation
import UserNotifications

/// Local "earbud battery low" notification (opt-in under More features).
/// Works with the app closed because background Bluetooth keeps delivering battery changes.
enum BatteryAlerts {
    static let enabledKey = "pinna.lowBatteryAlert"

    /// Asks for permission when the user turns the alert on; returns whether it was granted.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func post(side: String, level: Int) {
        let content = UNMutableNotificationContent()
        content.title = L("Earbud battery low")
        content.body = "\(side): \(level) %"
        content.sound = .default
        // Same identifier per earbud: a new alert replaces the old one.
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "pinna.lowbattery.\(side)", content: content, trigger: nil))
    }
}
