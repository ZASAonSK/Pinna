import Foundation
import Combine

/// Last values *sent* to the buds, per model. The buds never report their
/// state over BLE, so this is the only state the app can show.
struct BudsSettings: Codable, Equatable {
    var noiseMode: NoiseMode?
    var ancLevel = 2
    var ambientLevel = 1
    var voiceDetect = false
    var ancOneEarbud = false
    var equalizer = 0
    /// Custom equalizer curve, 9 bands −10…+10; nil = flat.
    var customEqualizer: [Int]?
    var balance = 16
    var sidetone = false
    var gamingMode = false
    var pauseMediaOnRemove = true
    var inEarCalls = true
    var seamless = true
    var neckStretch = false
    var edgeVolume = false
    var holdLeft = 2
    var holdRight = 2
    /// Noise modes pinch-and-hold switches between; nil = default (ANC, ambient).
    var holdModesLeft: Set<NoiseMode>?
    var holdModesRight: Set<NoiseMode>?
    var touch = TouchSettings()
}

final class SettingsStore: ObservableObject {
    @Published private(set) var values = BudsSettings()
    @Published private(set) var findingBuds = false
    private let controller: BudsController
    private var modelID = BudsModel.unknown.id
    private var cancellables: Set<AnyCancellable> = []

    init(controller: BudsController) {
        self.controller = controller
        controller.$model
            .map(\.id)
            .removeDuplicates()
            .sink { [weak self] id in self?.load(modelID: id) }
            .store(in: &cancellables)
    }

    var model: BudsModel { controller.model }

    private func key(_ id: String) -> String { "pinna.settings.\(id)" }

    private func load(modelID id: String) {
        modelID = id
        if let data = UserDefaults.standard.data(forKey: key(id)),
           let decoded = try? JSONDecoder().decode(BudsSettings.self, from: data) {
            values = decoded
        } else {
            values = BudsSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(values) { UserDefaults.standard.set(data, forKey: key(modelID)) }
    }

    /// Sends the command and, if the write was issued, stores the new value.
    private func apply(_ command: BudsCommand, _ update: (inout BudsSettings) -> Void) {
        guard controller.send(command) else { return }
        update(&values)
        save()
        Haptics.tap()
    }

    // MARK: - Setters used by the UI

    func setNoise(_ mode: NoiseMode) { apply(.noise(mode)) { $0.noiseMode = mode } }
    func setAncLevel(_ v: Int) { apply(.ancLevel(v, levels: model.ancLevels)) { $0.ancLevel = v } }
    func setAmbientLevel(_ v: Int) { apply(.ambientLevel(v, levels: model.ambientLevels)) { $0.ambientLevel = v } }
    func setVoiceDetect(_ on: Bool) { apply(.voiceDetect(on)) { $0.voiceDetect = on } }
    func setAncOneEarbud(_ on: Bool) { apply(.ancOneEarbud(on, padded: model.paddedAncOneEarbud)) { $0.ancOneEarbud = on } }
    func setEqualizer(_ v: Int) {
        if v == BudsCommand.customPreset { setCustomEqualizer(customBands); return }
        apply(.equalizer(v)) { $0.equalizer = v }
    }
    var customBands: [Int] { values.customEqualizer ?? Array(repeating: 0, count: BudsCommand.customBands.count) }
    /// Like Samsung's app: send the curve, then select the custom preset.
    func setCustomEqualizer(_ bands: [Int]) {
        guard controller.send(.customEqualizer(bands)) else { return }
        controller.send(.equalizer(BudsCommand.customPreset))
        values.customEqualizer = bands
        values.equalizer = BudsCommand.customPreset
        save()
        Haptics.tap()
    }
    func setBalance(_ v: Int) { apply(.balance(v)) { $0.balance = v } }
    func setSidetone(_ on: Bool) { apply(.sidetone(on)) { $0.sidetone = on } }
    func setGamingMode(_ on: Bool) { apply(.gamingMode(on)) { $0.gamingMode = on } }
    func setPauseMedia(_ on: Bool) { apply(.pauseMediaOnRemove(on)) { $0.pauseMediaOnRemove = on } }
    func setInEarCalls(_ on: Bool) { apply(.inEarCalls(on)) { $0.inEarCalls = on } }
    func setSeamless(_ on: Bool) { apply(.seamless(on)) { $0.seamless = on } }
    func setNeckStretch(_ on: Bool) { apply(.neckStretch(on)) { $0.neckStretch = on } }
    func setEdgeVolume(_ on: Bool) { apply(.edgeVolume(on)) { $0.edgeVolume = on } }
    static let defaultHoldModes: Set<NoiseMode> = [.anc, .ambient]
    func holdModes(left: Bool) -> Set<NoiseMode> {
        (left ? values.holdModesLeft : values.holdModesRight) ?? Self.defaultHoldModes
    }
    func setHoldModes(left: Set<NoiseMode>, right: Set<NoiseMode>) {
        apply(.touchHoldNoiseModes(left: left, right: right)) { $0.holdModesLeft = left; $0.holdModesRight = right }
    }
    func setHold(left: Int, right: Int) { apply(.touchHold(left: left, right: right)) { $0.holdLeft = left; $0.holdRight = right } }
    func setTouch(_ t: TouchSettings) { apply(.touch(t, layout: model.touchLayout)) { $0.touch = t } }

    func toggleFind() {
        let start = !findingBuds
        if controller.send(.find(start)) {
            findingBuds = start
            Haptics.tap()
        }
    }

    func resetStored() {
        values = BudsSettings()
        UserDefaults.standard.removeObject(forKey: key(modelID))
    }
}
