import Foundation

enum NoiseMode: UInt8, CaseIterable, Identifiable, Codable {
    case off = 0, anc = 1, ambient = 2, adaptive = 3
    var id: UInt8 { rawValue }
    var title: String {
        switch self {
        case .off: return L("Off")
        case .anc: return L("ANC")
        case .ambient: return L("Ambient")
        case .adaptive: return L("Adaptive")
        }
    }
    var subtitle: String {
        switch self {
        case .off: return L("No change to surrounding sound")
        case .anc: return L("Noise cancelling")
        case .ambient: return L("Hear the world around you")
        case .adaptive: return L("Adapts to your surroundings")
        }
    }
    var symbol: String {
        switch self {
        case .off: return "speaker.wave.1"
        case .anc: return "person.wave.2.fill"
        case .ambient: return "ear"
        case .adaptive: return "wand.and.stars"
        }
    }
}

enum Feature: String, CaseIterable, Codable {
    case ancLevel, ambientLevel, voiceDetect, ancOneEarbud, equalizer, balance, sidetone
    case gamingMode, inEarDetection, touchLock, touchHold, findMyBuds, seamless
    case neckStretch, lighting, edgeVolume
}

/// Layout of LOCK_TOUCHPAD (0x90), which differs per generation.
enum TouchLockLayout: Equatable {
    /// `[locked]` — Buds, Buds+, Buds Live, Buds Pro.
    case single
    /// `[on, tap, double, triple, hold, (calls double, calls hold)]` — Buds2 … Buds3.
    case advanced
    /// Buds3 Pro plugin: advanced + swipe, lighting mode, double pinch-and-hold.
    case advancedLighting
}

/// Per-model capabilities. Message IDs are shared by all FD…DD models; what
/// differs is which features exist, value ranges and a few payload layouts.
/// Sources: observed behaviour of Samsung's manager apps (docs/PROTOCOL.md) and
/// GalaxyBudsClient device specs. `verified` = confirmed by ear over BLE.
struct BudsModel: Equatable, Identifiable {
    let id: String
    let name: String
    let modelNumbers: [String]
    let names: [String]
    let colorIDs: [Int]
    let legacyFrame: Bool
    let noiseModes: [NoiseMode]
    let ancLevels: Int
    let ambientLevels: Int
    let features: Set<Feature>
    let touchLayout: TouchLockLayout
    /// Buds3 Pro sends ANC_WITH_ONE_EARBUD as `[0, 0, on]`; older as `[on]`.
    let paddedAncOneEarbud: Bool
    let verified: Bool
    let symbol: String

    func has(_ f: Feature) -> Bool { features.contains(f) }

    static let unknown = BudsModel(
        id: "unknown", name: "Galaxy Buds", modelNumbers: [], names: [], colorIDs: [],
        legacyFrame: false, noiseModes: [.off, .anc, .ambient], ancLevels: 0, ambientLevels: 3,
        features: [.equalizer, .findMyBuds], touchLayout: .advanced, paddedAncOneEarbud: false,
        verified: false, symbol: "earbuds")

    static let all: [BudsModel] = [
        BudsModel(id: "buds", name: "Galaxy Buds", modelNumbers: ["SM-R170"], names: ["Galaxy Buds ("],
                  colorIDs: [257, 14336], legacyFrame: true, noiseModes: [.off, .ambient], ancLevels: 0, ambientLevels: 5,
                  features: [.ambientLevel, .equalizer, .touchLock, .findMyBuds, .seamless, .inEarDetection],
                  touchLayout: .single, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "budsplus", name: "Galaxy Buds+", modelNumbers: ["SM-R175"], names: ["Galaxy Buds+", "Buds+"],
                  colorIDs: Array(258...266), legacyFrame: false, noiseModes: [.off, .ambient], ancLevels: 0, ambientLevels: 3,
                  features: [.ambientLevel, .equalizer, .touchLock, .sidetone, .seamless, .gamingMode, .edgeVolume, .findMyBuds, .inEarDetection],
                  touchLayout: .single, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "budslive", name: "Galaxy Buds Live", modelNumbers: ["SM-R180"], names: ["Buds Live"],
                  colorIDs: Array(278...284), legacyFrame: false, noiseModes: [.off, .anc], ancLevels: 0, ambientLevels: 0,
                  features: [.equalizer, .touchLock, .seamless, .gamingMode, .balance, .findMyBuds, .inEarDetection],
                  touchLayout: .single, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "budspro", name: "Galaxy Buds Pro", modelNumbers: ["SM-R190"], names: ["Buds Pro"],
                  colorIDs: Array(298...301), legacyFrame: false, noiseModes: [.off, .anc, .ambient], ancLevels: 2, ambientLevels: 4,
                  features: [.ancLevel, .ambientLevel, .voiceDetect, .equalizer, .touchLock, .sidetone, .seamless, .gamingMode, .balance, .ancOneEarbud, .edgeVolume, .findMyBuds, .inEarDetection],
                  touchLayout: .single, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "buds2", name: "Galaxy Buds2", modelNumbers: ["SM-R177"], names: ["Buds2"],
                  colorIDs: Array(313...321) + [14337], legacyFrame: false, noiseModes: [.off, .anc, .ambient], ancLevels: 0, ambientLevels: 3,
                  features: [.ambientLevel, .equalizer, .touchLock, .touchHold, .sidetone, .seamless, .gamingMode, .balance, .ancOneEarbud, .edgeVolume, .findMyBuds, .inEarDetection],
                  touchLayout: .advanced, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "buds2pro", name: "Galaxy Buds2 Pro", modelNumbers: ["SM-R510"], names: ["Buds2 Pro"],
                  colorIDs: Array(325...328), legacyFrame: false, noiseModes: [.off, .anc, .ambient], ancLevels: 0, ambientLevels: 3,
                  features: [.ambientLevel, .voiceDetect, .equalizer, .touchLock, .touchHold, .sidetone, .seamless, .gamingMode, .balance, .ancOneEarbud, .edgeVolume, .findMyBuds, .inEarDetection],
                  touchLayout: .advanced, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "budsfe", name: "Galaxy Buds FE", modelNumbers: ["SM-R400"], names: ["Buds FE"],
                  colorIDs: [330, 331], legacyFrame: false, noiseModes: [.off, .anc, .ambient], ancLevels: 2, ambientLevels: 3,
                  features: [.ancLevel, .ambientLevel, .equalizer, .touchLock, .touchHold, .sidetone, .seamless, .gamingMode, .balance, .ancOneEarbud, .edgeVolume, .findMyBuds, .inEarDetection],
                  touchLayout: .advanced, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "budscore", name: "Galaxy Buds Core", modelNumbers: ["SM-R410"], names: ["Buds Core"],
                  colorIDs: [322, 323], legacyFrame: false, noiseModes: [.off, .anc, .ambient], ancLevels: 2, ambientLevels: 3,
                  features: [.ancLevel, .ambientLevel, .equalizer, .touchLock, .touchHold, .sidetone, .seamless, .gamingMode, .balance, .ancOneEarbud, .edgeVolume, .findMyBuds, .inEarDetection],
                  touchLayout: .advanced, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "buds3", name: "Galaxy Buds3", modelNumbers: ["SM-R530"], names: ["Buds3"],
                  colorIDs: [333, 334], legacyFrame: false, noiseModes: [.off, .anc, .ambient], ancLevels: 0, ambientLevels: 3,
                  features: [.ambientLevel, .equalizer, .touchLock, .touchHold, .sidetone, .seamless, .gamingMode, .balance, .ancOneEarbud, .findMyBuds, .inEarDetection],
                  touchLayout: .advanced, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "buds3pro", name: "Galaxy Buds3 Pro", modelNumbers: ["SM-R630"], names: ["Buds3 Pro"],
                  colorIDs: [340, 341], legacyFrame: false, noiseModes: [.off, .anc, .ambient, .adaptive], ancLevels: 5, ambientLevels: 5,
                  features: [.ancLevel, .ambientLevel, .voiceDetect, .ancOneEarbud, .equalizer, .balance, .sidetone, .gamingMode,
                             .inEarDetection, .touchLock, .touchHold, .findMyBuds, .seamless, .neckStretch, .lighting],
                  touchLayout: .advancedLighting, paddedAncOneEarbud: true, verified: true, symbol: "earbuds"),
        BudsModel(id: "buds3fe", name: "Galaxy Buds3 FE", modelNumbers: ["SM-R420"], names: ["Buds3 FE"],
                  colorIDs: [347, 348], legacyFrame: false, noiseModes: [.off, .anc, .ambient], ancLevels: 2, ambientLevels: 3,
                  features: [.ancLevel, .ambientLevel, .equalizer, .touchLock, .touchHold, .sidetone, .seamless, .gamingMode, .balance, .ancOneEarbud, .findMyBuds, .inEarDetection],
                  touchLayout: .advanced, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "buds4", name: "Galaxy Buds4", modelNumbers: ["SM-R540"], names: ["Buds4"],
                  colorIDs: [355, 356], legacyFrame: false, noiseModes: [.off, .anc, .ambient, .adaptive], ancLevels: 0, ambientLevels: 3,
                  features: [.ambientLevel, .equalizer, .touchLock, .touchHold, .sidetone, .seamless, .gamingMode, .balance, .ancOneEarbud, .findMyBuds, .inEarDetection],
                  touchLayout: .advanced, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
        BudsModel(id: "buds4pro", name: "Galaxy Buds4 Pro", modelNumbers: ["SM-R640"], names: ["Buds4 Pro"],
                  colorIDs: [359, 360, 361], legacyFrame: false, noiseModes: [.off, .anc, .ambient, .adaptive], ancLevels: 0, ambientLevels: 5,
                  features: [.ambientLevel, .voiceDetect, .equalizer, .touchLock, .touchHold, .sidetone, .seamless, .gamingMode, .balance, .ancOneEarbud, .findMyBuds, .inEarDetection],
                  touchLayout: .advanced, paddedAncOneEarbud: false, verified: false, symbol: "earbuds"),
    ]

    /// Most specific name first ("Buds3 Pro" before "Buds3").
    private static var byNameLength: [BudsModel] {
        all.sorted { ($0.names.map(\.count).max() ?? 0) > ($1.names.map(\.count).max() ?? 0) }
    }

    static func detect(modelNumber: String?, name: String? = nil) -> BudsModel {
        if let number = modelNumber?.uppercased(),
           let m = all.first(where: { $0.modelNumbers.contains(where: { number.hasPrefix($0) }) }) {
            return m
        }
        if let name = name?.lowercased(),
           let m = byNameLength.first(where: { $0.names.contains(where: { name.contains($0.lowercased()) }) }) {
            return m
        }
        return .unknown
    }

    static func detect(colorID: Int) -> BudsModel {
        all.first(where: { $0.colorIDs.contains(colorID) }) ?? .unknown
    }

    static func looksLikeBuds(_ name: String?) -> Bool {
        guard let n = name?.lowercased() else { return false }
        return n.contains("buds")
    }
}
