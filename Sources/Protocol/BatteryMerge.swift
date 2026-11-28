import Foundation

/// Battery values from two sources — the Samsung broadcast (`adv`) and the
/// Battery Service of the connected earbud (`gatt`) — merged per role.
/// The newest change wins: an earbud out of the case keeps reporting the case
/// level it saw last (43 % while the open case already broadcast more, 1.8.2).
struct BatteryMerge {
    enum Source: String { case adv, gatt }
    /// Roles as labelled by the Battery Service `2904` description.
    static let left = 0x010D, right = 0x010E, caseRole = 0x0110

    private var current: [String: Int] = [:]
    /// Kept across reconnects, so a reconnect re-reporting the same old value is not a change.
    private var lastRaw: [String: Int] = [:]
    private var changedAt: [String: Date] = [:]

    mutating func set(_ source: Source, _ role: Int, _ value: Int?, now: Date = Date()) {
        guard let value, (0...100).contains(value) else { return }
        let key = source.rawValue + String(role)
        current[key] = value
        if lastRaw[key] != value { lastRaw[key] = value; changedAt[key] = now }
    }

    /// Drops a source's values (GATT on disconnect); their change history stays.
    mutating func clear(_ source: Source) {
        current = current.filter { !$0.key.hasPrefix(source.rawValue) }
    }

    var hasGATT: Bool { current.keys.contains { $0.hasPrefix(Source.gatt.rawValue) } }

    func value(_ role: Int) -> Int? {
        let a = current["adv\(role)"], g = current["gatt\(role)"]
        guard let g else { return a }
        guard let a else { return g }
        return (changedAt["adv\(role)"] ?? .distantPast) > (changedAt["gatt\(role)"] ?? .distantPast) ? a : g
    }
}

/// Alerts once when an earbud drops to `threshold`, and again only after it
/// has been charged above `rearm` (no repeats while it hovers around 15 %).
struct LowBatteryWatch {
    var threshold = 15
    var rearm = 20
    private var fired: Set<Int> = []

    mutating func shouldAlert(_ role: Int, _ level: Int?) -> Bool {
        guard let level else { return false }
        if level > rearm { fired.remove(role); return false }
        guard level <= threshold, !fired.contains(role) else { return false }
        fired.insert(role)
        return true
    }
}
