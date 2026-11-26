import AppIntents
import Foundation

/// Noise modes as offered to Shortcuts, Siri, the Action button and the
/// Shortcuts control in Control Center.
enum NoiseModeOption: String, AppEnum {
    case off, anc, ambient, adaptive

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Noise mode"
    static var caseDisplayRepresentations: [NoiseModeOption: DisplayRepresentation] = [
        .off: "Off", .anc: "ANC", .ambient: "Ambient", .adaptive: "Adaptive",
    ]

    var mode: NoiseMode {
        switch self {
        case .off: return .off
        case .anc: return .anc
        case .ambient: return .ambient
        case .adaptive: return .adaptive
        }
    }
}
