import SwiftUI

// MARK: - Building blocks

struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @EnvironmentObject private var buds: BudsController

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    if !buds.canControl {
                        Label(L("Earbuds are not connected – changes won't be sent."), systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .glassCard(cornerRadius: 18, tint: .orange)
                    }
                    content
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct GlassSection<Content: View>: View {
    let title: String
    var symbol: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: title, symbol: symbol)
            VStack(spacing: 0) { content }
                .glassCard(cornerRadius: 22)
            if let footer {
                Text(footer).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    let symbol: String
    let isOn: Bool
    let set: (Bool) -> Void
    @EnvironmentObject private var buds: BudsController

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: set)) {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(Palette.accent).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .tint(Palette.accent)
        .disabled(!buds.canControl)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 54) }
}

// MARK: - Sound

struct SoundView: View {
    @EnvironmentObject private var buds: BudsController
    @EnvironmentObject private var store: SettingsStore
    @State private var balance: Double = 16

    private let presets: [(String, String)] = [
        (L("Normal"), "equal"), (L("Bass boost"), "speaker.wave.3"), (L("Soft"), "leaf"),
        (L("Dynamic"), "bolt"), (L("Clear"), "sparkle"), (L("Treble boost"), "arrow.up.right"),
    ]

    var body: some View {
        SettingsPage(title: L("Sound")) {
            if buds.model.has(.equalizer) {
                GlassSection(title: L("Equalizer"), symbol: "slider.vertical.3") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(presets.indices, id: \.self) { i in
                            let selected = store.values.equalizer == i
                            Button { store.setEqualizer(i) } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: presets[i].1).font(.title3)
                                    Text(presets[i].0).font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(selected ? .white : .primary)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(selected ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(.primary.opacity(0.06))))
                            }
                            .buttonStyle(.plain)
                            .disabled(!buds.canControl)
                        }
                    }
                    .padding(12)
                    .animation(Motion.smooth, value: store.values.equalizer)
                }
            }
            if buds.model.has(.balance) {
                GlassSection(title: L("Balance"), symbol: "dial.medium",
                             footer: L("If one earbud sounds quieter, move the balance towards it.")) {
                    VStack(spacing: 10) {
                        HStack {
                            Text(L("L")).font(.headline)
                            Slider(value: $balance, in: 0...32, step: 1) { editing in
                                if !editing { store.setBalance(Int(balance)) }
                            }
                            Text(L("R")).font(.headline)
                        }
                        HStack {
                            Text(balanceText).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                            Spacer()
                            Button(L("Center")) { balance = 16; store.setBalance(16) }.font(.footnote).glassButton()
                        }
                    }
                    .padding(16)
                    .disabled(!buds.canControl)
                }
                .onAppear { balance = Double(store.values.balance) }
            }
            if buds.model.has(.sidetone) {
                GlassSection(title: L("Calls"), symbol: "phone") {
                    ToggleRow(title: L("Ambient sound during calls"), subtitle: L("Hear your own voice more naturally"),
                              symbol: "person.wave.2", isOn: store.values.sidetone) { store.setSidetone($0) }
                }
            }
        }
    }

    private var balanceText: String {
        let v = Int(balance)
        if v == 16 { return L("Center") }
        let r = Int((Double(v) / 32 * 100).rounded())
        return L("Left %ld %% · Right %ld %%", 100 - r, r)
    }
}

// MARK: - Touch & lights

struct TouchView: View {
    @EnvironmentObject private var buds: BudsController
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        let t = store.values.touch
        let advanced = buds.model.touchLayout != .single
        SettingsPage(title: buds.model.has(.lighting) ? L("Gestures & lights") : L("Gestures")) {
            GlassSection(title: L("Touch controls"), symbol: "hand.tap") {
                ToggleRow(title: L("Gestures on"), subtitle: L("Turn off if you often touch the earbuds by accident"),
                          symbol: "hand.raised", isOn: t.enabled) { on in update { $0.enabled = on } }
                if advanced {
                    RowDivider()
                    ToggleRow(title: L("Pinch"), subtitle: L("Play / pause"), symbol: "1.circle", isOn: t.tap) { on in update { $0.tap = on } }
                    RowDivider()
                    ToggleRow(title: L("Double pinch"), subtitle: L("Next track"), symbol: "2.circle", isOn: t.doubleTap) { on in update { $0.doubleTap = on } }
                    RowDivider()
                    ToggleRow(title: L("Triple pinch"), subtitle: L("Previous track"), symbol: "3.circle", isOn: t.tripleTap) { on in update { $0.tripleTap = on } }
                    RowDivider()
                    ToggleRow(title: L("Pinch and hold"), symbol: "hand.point.up.left", isOn: t.hold) { on in update { $0.hold = on } }
                    if buds.model.touchLayout == .advancedLighting {
                        RowDivider()
                        ToggleRow(title: L("Swipe"), subtitle: L("Volume"), symbol: "arrow.up.and.down", isOn: t.swipe) { on in update { $0.swipe = on } }
                    }
                }
            }
            if advanced {
                GlassSection(title: L("During calls"), symbol: "phone") {
                    ToggleRow(title: L("Double pinch"), subtitle: L("Answer / end call"), symbol: "phone.arrow.down.left", isOn: t.callsDoubleTap) { on in update { $0.callsDoubleTap = on } }
                    RowDivider()
                    ToggleRow(title: L("Pinch and hold"), subtitle: L("Decline call"), symbol: "phone.down", isOn: t.callsHold) { on in update { $0.callsHold = on } }
                }
            }
            if buds.model.has(.touchHold) {
                GlassSection(title: L("Pinch and hold actions"), symbol: "hand.point.up.left",
                             footer: L("What pinch and hold does on each earbud.")) {
                    HoldPicker(title: L("Left earbud"), value: store.values.holdLeft) { store.setHold(left: $0, right: store.values.holdRight) }
                    if store.values.holdLeft == 2, buds.model.noiseModes.count > 2 {
                        HoldModesRow(modes: buds.model.noiseModes, selected: store.holdModes(left: true)) {
                            store.setHoldModes(left: $0, right: store.holdModes(left: false))
                        }
                    }
                    RowDivider()
                    HoldPicker(title: L("Right earbud"), value: store.values.holdRight) { store.setHold(left: store.values.holdLeft, right: $0) }
                    if store.values.holdRight == 2, buds.model.noiseModes.count > 2 {
                        HoldModesRow(modes: buds.model.noiseModes, selected: store.holdModes(left: false)) {
                            store.setHoldModes(left: store.holdModes(left: true), right: $0)
                        }
                    }
                }
            }
            if buds.model.has(.lighting) {
                GlassSection(title: L("Lights"), symbol: "light.beacon.max",
                             footer: L("Turn the lights on or off by pinching and holding both earbuds at once. Here you choose how they glow.")) {
                    HStack(spacing: 10) {
                        ForEach(LightStyle.all) { item in
                            let selected = t.lighting == item.id
                            Button { update { $0.lighting = item.id } } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: item.symbol).font(.title3)
                                    Text(item.title).font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(selected ? .white : .primary)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(selected ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(.primary.opacity(0.06))))
                            }
                            .buttonStyle(.plain)
                            .disabled(!buds.canControl)
                        }
                    }
                    .padding(12)
                }
            }
            if advanced {
                Text(L("Gestures are sent as one setting, so every change sends the whole configuration at once."))
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            }
        }
    }

    private func update(_ change: (inout TouchSettings) -> Void) {
        var t = store.values.touch
        change(&t)
        store.setTouch(t)
    }
}

/// Chips for the noise modes pinch-and-hold switches between on one earbud.
/// At least two must stay selected, as in Samsung's app.
private struct HoldModesRow: View {
    let modes: [NoiseMode]
    let selected: Set<NoiseMode>
    let set: (Set<NoiseMode>) -> Void
    @EnvironmentObject private var buds: BudsController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Switches between")).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(modes) { mode in
                    let on = selected.contains(mode)
                    Button {
                        var next = selected
                        if on { next.remove(mode) } else { next.insert(mode) }
                        if next.count >= 2 { set(next) } else { Haptics.select() }
                    } label: {
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .foregroundStyle(on ? .white : .primary)
                            .background(Capsule().fill(on ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(.primary.opacity(0.08))))
                    }
                    .buttonStyle(.plain)
                    .disabled(!buds.canControl)
                }
            }
            Text(L("Choose at least two modes.")).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .animation(Motion.smooth, value: selected)
    }
}

private struct HoldPicker: View {
    let title: String
    let value: Int
    let set: (Int) -> Void
    @EnvironmentObject private var buds: BudsController

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: Binding(get: { value }, set: set)) {
                Text(L("Noise control")).tag(2)
                Text(L("Voice assistant")).tag(1)
                Text(L("Volume")).tag(3)
            }
            .pickerStyle(.menu)
            .disabled(!buds.canControl)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - More

struct MoreView: View {
    @EnvironmentObject private var buds: BudsController
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        let m = buds.model
        SettingsPage(title: L("More features")) {
            if m.has(.ancOneEarbud) || m.has(.voiceDetect) {
                GlassSection(title: L("Noise control"), symbol: "waveform") {
                    if m.has(.voiceDetect) {
                        ToggleRow(title: L("Voice detect"), subtitle: L("Switches to ambient sound when you start talking"),
                                  symbol: "waveform.badge.mic", isOn: store.values.voiceDetect) { store.setVoiceDetect($0) }
                    }
                    if m.has(.voiceDetect) && m.has(.ancOneEarbud) { RowDivider() }
                    if m.has(.ancOneEarbud) {
                        ToggleRow(title: L("With one earbud"), subtitle: L("ANC even with just one earbud in"),
                                  symbol: "ear", isOn: store.values.ancOneEarbud) { store.setAncOneEarbud($0) }
                    }
                }
            }
            if m.has(.inEarDetection) {
                GlassSection(title: L("In-ear detection"), symbol: "ear.badge.checkmark") {
                    ToggleRow(title: L("Pause when removed"), subtitle: L("Music pauses when you take an earbud out"),
                              symbol: "pause.circle", isOn: store.values.pauseMediaOnRemove) { store.setPauseMedia($0) }
                    RowDivider()
                    ToggleRow(title: L("Calls to earbuds"), subtitle: L("Moves a call to the earbuds when you put them in"),
                              symbol: "phone.connection", isOn: store.values.inEarCalls) { store.setInEarCalls($0) }
                }
            }
            if m.has(.gamingMode) || m.has(.edgeVolume) {
                GlassSection(title: L("Sound & controls"), symbol: "gamecontroller") {
                    if m.has(.gamingMode) {
                        ToggleRow(title: L("Game mode"), subtitle: L("Lower audio latency"),
                                  symbol: "gamecontroller", isOn: store.values.gamingMode) { store.setGamingMode($0) }
                    }
                    if m.has(.gamingMode) && m.has(.edgeVolume) { RowDivider() }
                    if m.has(.edgeVolume) {
                        ToggleRow(title: L("Double-tap edge for volume"), symbol: "speaker.plus",
                                  isOn: store.values.edgeVolume) { store.setEdgeVolume($0) }
                    }
                }
            }
            if m.has(.seamless) || m.has(.neckStretch) {
                GlassSection(title: L("Comfort"), symbol: "heart") {
                    if m.has(.seamless) {
                        ToggleRow(title: L("Seamless switching"), subtitle: L("Between Samsung devices on your account"),
                                  symbol: "arrow.triangle.swap", isOn: store.values.seamless) { store.setSeamless($0) }
                    }
                    if m.has(.seamless) && m.has(.neckStretch) { RowDivider() }
                    if m.has(.neckStretch) {
                        ToggleRow(title: L("Neck stretch reminder"), subtitle: L("Reminds you when your head has been tilted down for a long time"),
                                  symbol: "figure.cooldown", isOn: store.values.neckStretch) { store.setNeckStretch($0) }
                    }
                }
            }
        }
    }
}

struct LightStyle: Identifiable {
    let id: Int
    let title: String
    let symbol: String
    static let all = [
        LightStyle(id: 1, title: L("Steady"), symbol: "light.max"),
        LightStyle(id: 2, title: L("Solid"), symbol: "sun.max.fill"),
        LightStyle(id: 3, title: L("Breathing"), symbol: "wind"),
    ]
}
