import AppIntents
import Foundation

// Intents used by widget buttons and Control Center controls. They are
// compiled into the app and the widget extension; as `LiveActivityIntent`s
// the system runs them in the app's process, where the Bluetooth link lives.

@available(iOS 17.0, *)
struct WidgetSetNoiseModeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Set noise control"
    static var isDiscoverable = false

    @Parameter(title: "Noise mode")
    var mode: NoiseModeOption

    init() {}
    init(mode: NoiseModeOption) { self.mode = mode }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        _ = try await NoiseIntentRunner.set(mode.mode)
        #endif
        return .result()
    }
}

@available(iOS 18.0, *)
struct SetNoiseCancellingIntent: SetValueIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Noise cancelling"
    static var isDiscoverable = false

    @Parameter(title: "Noise cancelling")
    var value: Bool

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let modes = BudsController.shared.model.noiseModes
        let off: NoiseMode = modes.contains(.ambient) ? .ambient : .off
        _ = try await NoiseIntentRunner.set(value ? .anc : off)
        #endif
        return .result()
    }
}
