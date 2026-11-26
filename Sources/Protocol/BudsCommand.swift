import Foundation

/// A settings message for the buds. IDs follow Samsung's manager plugins and
/// GalaxyBudsClient (`SppMessageEnums.cs`); see docs/PROTOCOL.md.
struct BudsCommand: Equatable {
    let id: UInt8
    let payload: Data
    let name: String

    init(_ id: UInt8, _ payload: [UInt8] = [], _ name: String) {
        self.id = id
        self.payload = Data(payload)
        self.name = name
    }

    var frame: Data { FrameCodec.encode(id: id, payload: payload) }

    // MARK: Message IDs
    enum ID {
        static let ancOneEarbud: UInt8 = 0x6F
        static let inEarPauseMedia: UInt8 = 0x6C
        static let inEarCalls: UInt8 = 0x6E
        static let noiseControls: UInt8 = 0x78
        static let voiceDetect: UInt8 = 0x7A
        static let ancLevel: UInt8 = 0x83
        static let ambientLevel: UInt8 = 0x84
        static let gamingMode: UInt8 = 0x85
        static let equalizer: UInt8 = 0x86
        static let sidetone: UInt8 = 0x8B
        static let balance: UInt8 = 0x8F
        static let lockTouchpad: UInt8 = 0x90
        static let touchHold: UInt8 = 0x92
        static let touchHoldNoiseModes: UInt8 = 0x79
        static let edgeVolume: UInt8 = 0x95
        static let findStart: UInt8 = 0xA0
        static let findStop: UInt8 = 0xA1
        static let seamless: UInt8 = 0xAF
        static let neckStretch: UInt8 = 0xC9
    }

    private static func flag(_ on: Bool) -> UInt8 { on ? 1 : 0 }
    private static func clamp(_ v: Int, _ hi: Int) -> UInt8 { UInt8(max(0, min(hi, v))) }

    // MARK: Builders
    static func noise(_ mode: NoiseMode) -> BudsCommand { .init(ID.noiseControls, [mode.rawValue], "Noise mode \(mode.rawValue)") }
    static func ancLevel(_ level: Int, levels: Int) -> BudsCommand { .init(ID.ancLevel, [clamp(level, max(0, levels - 1))], "ANC level") }
    static func ambientLevel(_ level: Int, levels: Int) -> BudsCommand { .init(ID.ambientLevel, [clamp(level, max(0, levels - 1))], "Ambient level") }
    static func voiceDetect(_ on: Bool) -> BudsCommand { .init(ID.voiceDetect, [flag(on)], "Voice detect") }
    static func ancOneEarbud(_ on: Bool, padded: Bool) -> BudsCommand {
        .init(ID.ancOneEarbud, padded ? [0, 0, flag(on)] : [flag(on)], "ANC with one earbud")
    }
    static func equalizer(_ preset: Int) -> BudsCommand { .init(ID.equalizer, [clamp(preset, 5)], "Equalizer") }
    static func balance(_ value: Int) -> BudsCommand { .init(ID.balance, [clamp(value, 32)], "Balance") }
    static func sidetone(_ on: Bool) -> BudsCommand { .init(ID.sidetone, [flag(on)], "Sidetone") }
    static func gamingMode(_ on: Bool) -> BudsCommand { .init(ID.gamingMode, [flag(on)], "Game mode") }
    static func pauseMediaOnRemove(_ on: Bool) -> BudsCommand { .init(ID.inEarPauseMedia, [flag(on)], "Pause on removal") }
    /// The buds store "disabled", hence the inversion.
    static func inEarCalls(_ on: Bool) -> BudsCommand { .init(ID.inEarCalls, [flag(!on)], "Calls on insertion") }
    static func seamless(_ on: Bool) -> BudsCommand { .init(ID.seamless, [flag(!on)], "Seamless switching") }
    static func neckStretch(_ on: Bool) -> BudsCommand { .init(ID.neckStretch, [flag(on)], "Neck reminder") }
    static func edgeVolume(_ on: Bool) -> BudsCommand { .init(ID.edgeVolume, [flag(on)], "Edge volume") }
    static func touchHold(left: Int, right: Int) -> BudsCommand { .init(ID.touchHold, [UInt8(left), UInt8(right)], "Touch and hold") }

    /// Which noise modes pinch-and-hold cycles through, per earbud (Samsung
    /// "Switch noise controls"): bit 0x08 ANC, 0x04 off, 0x02 adaptive, 0x01 ambient.
    static func noiseModeMask(_ modes: Set<NoiseMode>) -> UInt8 {
        var mask: UInt8 = 0
        if modes.contains(.anc) { mask |= 0x08 }
        if modes.contains(.off) { mask |= 0x04 }
        if modes.contains(.adaptive) { mask |= 0x02 }
        if modes.contains(.ambient) { mask |= 0x01 }
        return mask
    }
    static func touchHoldNoiseModes(left: Set<NoiseMode>, right: Set<NoiseMode>) -> BudsCommand {
        .init(ID.touchHoldNoiseModes, [noiseModeMask(left), noiseModeMask(right)], "Touch and hold noise modes")
    }
    static func find(_ start: Bool) -> BudsCommand { .init(start ? ID.findStart : ID.findStop, [], start ? "Find start" : "Find stop") }

    static func touch(_ t: TouchSettings, layout: TouchLockLayout) -> BudsCommand {
        let gestures = [t.tap, t.doubleTap, t.tripleTap, t.hold].map(flag)
        let payload: [UInt8]
        switch layout {
        case .single:
            payload = [flag(!t.enabled)]
        case .advanced:
            payload = [flag(t.enabled)] + gestures + [flag(t.callsDoubleTap), flag(t.callsHold)]
        case .advancedLighting:
            payload = [flag(t.enabled)] + gestures + [flag(t.callsDoubleTap), flag(t.callsHold), flag(t.swipe),
                                                       UInt8(max(1, min(3, t.lighting))), 0]
        }
        return .init(ID.lockTouchpad, payload, "Gestures")
    }
}

/// Touch/gesture configuration sent as one LOCK_TOUCHPAD message.
struct TouchSettings: Codable, Equatable {
    var enabled = true
    var tap = true
    var doubleTap = true
    var tripleTap = true
    var hold = true
    var callsDoubleTap = true
    var callsHold = true
    var swipe = true
    /// 1 steady, 2 solid, 3 breathing (Buds3 Pro plugin).
    var lighting = 1
}
