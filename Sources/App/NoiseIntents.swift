import AppIntents
import Foundation

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case notConnected
    var localizedStringResource: LocalizedStringResource { "Earbuds are not connected" }
}

/// Runs a noise-mode change in the app process, waiting briefly for the
/// Bluetooth link (it is usually already up thanks to background Bluetooth).
@MainActor
enum NoiseIntentRunner {
    static func waitForLink(seconds: Double = 15) async -> Bool {
        let buds = BudsController.shared
        let deadline = Date().addingTimeInterval(seconds)
        while !buds.canControl && Date() < deadline {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return buds.canControl
    }

    static func set(_ mode: NoiseMode) async throws -> String {
        guard await waitForLink() else { throw IntentError.notConnected }
        SettingsStore.shared.setNoise(mode)
        return L("Noise control: %@", mode.title)
    }

    /// ANC ↔ Ambient (ANC ↔ Off on models without ambient sound).
    static func toggle() async throws -> String {
        let modes = BudsController.shared.model.noiseModes
        let other: NoiseMode = modes.contains(.ambient) ? .ambient : .off
        let next: NoiseMode = SettingsStore.shared.values.noiseMode == .anc ? other : .anc
        return try await set(next)
    }
}

struct SetNoiseModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set noise control"
    static var description = IntentDescription("Sets the noise control mode of your earbuds.")
    static var openAppWhenRun = false

    @Parameter(title: "Noise mode", default: .anc)
    var mode: NoiseModeOption

    init() {}
    init(mode: NoiseModeOption) { self.mode = mode }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = try await NoiseIntentRunner.set(mode.mode)
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: text)))
    }
}

struct ToggleNoiseCancellingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle noise cancelling"
    static var description = IntentDescription("Switches the earbuds between noise cancelling and ambient sound.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = try await NoiseIntentRunner.toggle()
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: text)))
    }
}

struct PinnaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ToggleNoiseCancellingIntent(), phrases: [
            "Toggle noise cancelling in \(.applicationName)",
            "Toggle ANC in \(.applicationName)",
        ])
        AppShortcut(intent: SetNoiseModeIntent(), phrases: [
            "Set \(\.$mode) in \(.applicationName)",
            "Switch \(.applicationName) to \(\.$mode)",
        ])
    }
}
