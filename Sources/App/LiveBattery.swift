import ActivityKit
import Foundation

/// Battery as a Live Activity (opt-in under More features). Unlike widgets,
/// which iOS refreshes only about every 30 minutes, a Live Activity can be
/// updated from the background on every battery change.
/// iOS only lets it start while the app is open and ends it after 8 hours.
enum LiveBattery {
    static let enabledKey = "pinna.liveActivity"

    static func sync(name: String?, battery: BatteryLevels, connected: Bool, appActive: Bool) {
        guard #available(iOS 16.2, *) else { return }
        let enabled = UserDefaults.standard.bool(forKey: enabledKey)
        let state = BatteryActivityAttributes.ContentState(left: battery.left, right: battery.right, caseLevel: battery.caseLevel)
        Task { @MainActor in
            let running = Activity<BatteryActivityAttributes>.activities
            guard enabled, battery.left != nil || battery.right != nil else {
                for activity in running { await activity.end(nil, dismissalPolicy: .immediate) }
                return
            }
            // While disconnected keep the last values, marked stale (dimmed).
            let content = ActivityContent(state: state, staleDate: connected ? nil : Date())
            if running.isEmpty {
                guard connected, appActive, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
                _ = try? Activity.request(attributes: BatteryActivityAttributes(deviceName: name ?? "Pinna"), content: content)
            } else {
                for activity in running where activity.content.state != state || (activity.content.staleDate == nil) != connected {
                    await activity.update(content)
                }
            }
        }
    }
}
