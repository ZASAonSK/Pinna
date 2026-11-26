import Foundation

/// What the app knows about the earbuds, shared with the widgets and Control
/// Center controls through an App Group. Only the app writes it.
struct SharedSnapshot: Codable, Equatable {
    var deviceName: String?
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    /// Raw `NoiseMode` last set in the app (the earbuds don't report it).
    var noiseMode: UInt8?
    var connected = false
    var updated: Date?
}

enum SharedState {
    static let defaultGroup = "group.io.github.zasaonsk.pinna"

    /// AltStore / SideStore rewrite App Group identifiers when they sign the
    /// app and list the real ones under `ALTAppGroups`; use those if present.
    static var groupID: String {
        for bundle in [Bundle.main, containingApp].compactMap({ $0 }) {
            if let groups = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String], let first = groups.first {
                return first
            }
        }
        return defaultGroup
    }

    private static var containingApp: Bundle? {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "appex" else { return nil }
        return Bundle(url: url.deletingLastPathComponent().deletingLastPathComponent())
    }

    private static var defaults: UserDefaults? { UserDefaults(suiteName: groupID) }

    static func load() -> SharedSnapshot {
        guard let data = defaults?.data(forKey: "pinna.snapshot"),
              let snapshot = try? JSONDecoder().decode(SharedSnapshot.self, from: data) else { return SharedSnapshot() }
        return snapshot
    }

    static func save(_ snapshot: SharedSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: "pinna.snapshot")
    }
}
