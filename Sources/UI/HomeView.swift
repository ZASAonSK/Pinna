import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var buds: BudsController
    @EnvironmentObject private var store: SettingsStore
    @ObservedObject private var layout = HomeLayout.shared
    @State private var showPicker = false
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        HeaderView(showPicker: $showPicker)
                        if buds.state != .ready { ConnectionBanner(showPicker: $showPicker) }
                        ForEach(layout.visible) { card in
                            HomeCardView(card: card)
                        }
                        Button { showEditor = true } label: {
                            Label(L("Edit Home"), systemImage: "square.and.pencil")
                                .font(.subheadline.weight(.medium))
                        }
                        .glassButton()
                        .padding(.top, 4)
                        Text(L("Pinna is not a Samsung product. Galaxy Buds is a trademark of Samsung Electronics."))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                    .animation(Motion.smooth, value: layout.visible)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPicker) { DevicePickerView() }
            .sheet(isPresented: $showEditor) { HomeEditorView() }
            .task {
                // First run: if nothing was found automatically, offer the picker.
                guard !buds.hasKnownDevice else { return }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if buds.state != .ready && buds.state != .connecting { showPicker = true }
            }
        }
    }
}

// MARK: - Cards

/// One card of the editable Home screen. Cards for features the connected
/// model lacks render nothing.
private struct HomeCardView: View {
    let card: HomeCard
    @EnvironmentObject private var buds: BudsController

    var body: some View {
        switch card {
        case .battery: BatteryCard()
        case .volume: if buds.volume != nil { VolumeCard() }
        case .noise: if buds.model.noiseModes.count > 1 { NoiseControlCard() }
        case .equalizer: if buds.model.has(.equalizer) { EqualizerCard() }
        case .tiles: QuickTiles()
        case .menu: MenuLinks()
        }
    }
}

private struct EqualizerCard: View {
    @EnvironmentObject private var buds: BudsController
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        let presets = EqualizerPresets.list(for: buds.model)
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: L("Equalizer"), symbol: "slider.vertical.3")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(presets.indices, id: \.self) { i in
                        let selected = store.values.equalizer == i
                        Button { store.setEqualizer(i) } label: {
                            Label(presets[i].0, systemImage: presets[i].1)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundStyle(selected ? .white : .primary)
                                .background(Capsule().fill(selected ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(.primary.opacity(0.06))))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .animation(Motion.smooth, value: store.values.equalizer)
        }
        .padding(18)
        .glassCard()
        .disabled(!buds.canControl)
    }
}

// MARK: - Header

private struct HeaderView: View {
    @EnvironmentObject private var buds: BudsController
    @Binding var showPicker: Bool

    var body: some View {
        Button { showPicker = true } label: { content }
            .buttonStyle(.plain)
            .accessibilityHint(L("Choose earbuds"))
    }

    private var content: some View {
        HStack(spacing: 14) {
            LogoMark(size: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(buds.deviceName ?? buds.model.name)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 6) {
                    StatusDot(state: buds.state)
                    Text(statusText).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .glassCapsule()
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    private var statusText: String {
        switch buds.state {
        case .ready: return buds.model == .unknown ? L("Connected") : buds.model.name
        case .connecting: return L("Connecting…")
        case .searching: return L("Looking for earbuds…")
        case .noControlPath: return L("Battery only")
        case .bluetoothOff: return L("Bluetooth is off")
        case .unauthorized: return L("No Bluetooth access")
        }
    }
}

struct StatusDot: View {
    let state: LinkState
    @State private var pulse = false
    var color: Color {
        switch state {
        case .ready: return .green
        case .connecting, .searching: return .orange
        case .noControlPath: return .yellow
        case .bluetoothOff, .unauthorized: return .red
        }
    }
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 6).scaleEffect(pulse ? 1.6 : 0.6).opacity(pulse ? 0 : 1))
            .onAppear {
                guard state != .ready else { return }
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
            }
    }
}

// MARK: - Connection banner

private struct ConnectionBanner: View {
    @EnvironmentObject private var buds: BudsController
    @Binding var showPicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            HStack {
                if buds.state == .bluetoothOff || buds.state == .unauthorized {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: { Label(L("Settings"), systemImage: "gear") }
                    .glassButton(prominent: true)
                } else {
                    Button { showPicker = true } label: { Label(L("Choose earbuds"), systemImage: "earbuds") }
                        .glassButton(prominent: true)
                    Button { buds.reconnect() } label: { Label(L("Retry"), systemImage: "arrow.clockwise") }
                        .glassButton()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(tint: .orange)
    }

    private var title: String {
        switch buds.state {
        case .bluetoothOff: return L("Turn on Bluetooth")
        case .unauthorized: return L("Allow Bluetooth")
        case .noControlPath: return L("This model can't be controlled")
        case .connecting: return L("Connecting")
        default: return L("Earbuds are not connected")
        }
    }
    private var symbol: String {
        switch buds.state {
        case .bluetoothOff, .unauthorized: return "antenna.radiowaves.left.and.right.slash"
        case .noControlPath: return "exclamationmark.triangle"
        default: return "earbuds"
        }
    }
    private var message: String {
        switch buds.state {
        case .bluetoothOff: return L("Pinna needs Bluetooth to find your earbuds.")
        case .unauthorized: return L("Allow Bluetooth in Settings → Pinna.")
        case .noControlPath: return L("This device has no Samsung data channel. If these aren't your earbuds, choose others.")
        case .connecting: return L("One moment… If it takes long, open the case or put the earbuds in your ears.") + "\n" + L("Still not connecting? Put the earbuds in pairing mode – Pinna connects right away.")
        default: return L("Keep your earbuds near the phone (case open or in your ears) and pick them from the list. Next time Pinna connects on its own.")
        }
    }
}

// MARK: - Battery

private struct BatteryCard: View {
    @EnvironmentObject private var buds: BudsController

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                SectionTitle(text: L("Battery"), symbol: "battery.75percent")
                if let date = buds.battery.updated {
                    Text(date, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 0) {
                BatteryRing(label: L("Left"), symbol: "l.circle", level: buds.battery.left)
                BatteryRing(label: L("Right"), symbol: "r.circle", level: buds.battery.right)
                BatteryRing(label: L("Case"), symbol: "earbuds.case", level: buds.battery.caseLevel)
            }
        }
        .padding(18)
        .glassCard()
    }
}

private struct BatteryRing: View {
    let label: String
    let symbol: String
    let level: Int?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.primary.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(level ?? 0) / 100)
                    .stroke(Palette.battery(level).gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(Motion.smooth, value: level)
                VStack(spacing: 0) {
                    Text(level.map { "\($0)" } ?? "–").font(.title3.bold()).contentTransition(.numericText())
                    if level != nil { Text("%").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            .frame(width: 74, height: 74)
            Label(label, systemImage: symbol).font(.caption).foregroundStyle(.secondary).labelStyle(.titleOnly)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(level.map { "\($0) %" } ?? L("unknown"))")
    }
}

// MARK: - Noise control

private struct NoiseControlCard: View {
    @EnvironmentObject private var buds: BudsController
    @EnvironmentObject private var store: SettingsStore
    @Namespace private var ns

    var body: some View {
        let modes = buds.model.noiseModes
        let current = store.values.noiseMode
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: L("Noise control"), symbol: "waveform")
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(modes) { mode in
                        Button { store.setNoise(mode) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: mode.symbol).font(.title3)
                                Text(mode.title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(current == mode ? .white : .primary)
                            .background {
                                if current == mode {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Palette.gradient)
                                        .matchedGeometryEffect(id: "sel", in: ns)
                                }
                            }
                            .glassCard(cornerRadius: 18, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(!buds.canControl)
                    }
                }
            }
            .animation(Motion.smooth(duration: 0.35), value: current)

            if let mode = current {
                Label(L("%@ · set in the app", mode.subtitle), systemImage: "checkmark.circle").font(.footnote).foregroundStyle(.secondary)
            } else {
                Text(L("Pick a mode. The earbuds don't report their current mode to the iPhone, so the app shows the one you set here."))
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if current == .anc, buds.model.has(.ancLevel), buds.model.ancLevels > 1 {
                LevelPicker(title: L("Cancelling strength"), levels: buds.model.ancLevels,
                            value: store.values.ancLevel) { store.setAncLevel($0) }
            }
            if current == .ambient, buds.model.has(.ambientLevel), buds.model.ambientLevels > 1 {
                LevelPicker(title: L("Ambient volume"), levels: buds.model.ambientLevels,
                            value: store.values.ambientLevel) { store.setAmbientLevel($0) }
            }
        }
        .padding(18)
        .glassCard()
    }
}

/// Discrete level control (e.g. 5 ANC steps) with large, tappable segments.
struct LevelPicker: View {
    let title: String
    let levels: Int
    let value: Int
    let set: (Int) -> Void
    @EnvironmentObject private var buds: BudsController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(value + 1) / \(levels)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(0..<levels, id: \.self) { i in
                    Button { set(i) } label: {
                        Capsule()
                            .fill(i <= value ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(.primary.opacity(0.1)))
                            .frame(height: 10 + CGFloat(i) * 3)
                            .frame(maxWidth: .infinity, minHeight: 30, alignment: .bottom)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!buds.canControl)
                }
            }
            .animation(Motion.smooth, value: value)
        }
    }
}

// MARK: - Quick tiles

private struct QuickTiles: View {
    @EnvironmentObject private var buds: BudsController
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        let m = buds.model
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            if m.has(.voiceDetect) {
                ToggleTile(title: L("Voice detect"), symbol: "waveform.badge.mic", on: store.values.voiceDetect) { store.setVoiceDetect($0) }
            }
            if m.has(.gamingMode) {
                ToggleTile(title: L("Game mode"), symbol: "gamecontroller", on: store.values.gamingMode) { store.setGamingMode($0) }
            }
            if m.has(.touchLock) {
                ToggleTile(title: L("Gestures"), symbol: "hand.tap", on: store.values.touch.enabled) { on in
                    var t = store.values.touch; t.enabled = on; store.setTouch(t)
                }
            }
            if m.has(.findMyBuds) {
                ToggleTile(title: store.findingBuds ? L("Beeping…") : L("Find earbuds"), symbol: "dot.radiowaves.left.and.right",
                           on: store.findingBuds, tint: .orange) { _ in store.toggleFind() }
            }
        }
    }
}

struct ToggleTile: View {
    let title: String
    let symbol: String
    let on: Bool
    var tint: Color = Palette.accent
    let set: (Bool) -> Void
    @EnvironmentObject private var buds: BudsController

    var body: some View {
        Button { set(!on) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(on ? .white : tint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(on ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.15))))
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(on ? L("On") : L("Off")).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard(cornerRadius: 22, interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(!buds.canControl)
        .opacity(buds.canControl ? 1 : 0.6)
        .animation(Motion.smooth, value: on)
    }
}

// MARK: - Menu

private struct MenuLinks: View {
    @EnvironmentObject private var buds: BudsController

    var body: some View {
        let m = buds.model
        VStack(spacing: 0) {
            if m.has(.equalizer) || m.has(.balance) || m.has(.sidetone) {
                MenuRow(title: L("Sound"), subtitle: L("Equalizer, balance, calls"), symbol: "slider.vertical.3", color: .pink) { SoundView() }
                Divider().padding(.leading, 60)
            }
            if m.has(.touchLock) || m.has(.touchHold) || m.has(.lighting) {
                MenuRow(title: m.has(.lighting) ? L("Gestures & lights") : L("Gestures"), subtitle: L("Pinches, hold, swipe"), symbol: "hand.tap.fill", color: .purple) { TouchView() }
                Divider().padding(.leading, 60)
            }
            if m.has(.inEarDetection) || m.has(.ancOneEarbud) || m.has(.seamless) || m.has(.neckStretch) {
                MenuRow(title: L("More features"), subtitle: L("In-ear detection, switching, health"), symbol: "sparkles", color: .blue) { MoreView() }
                Divider().padding(.leading, 60)
            }
            MenuRow(title: L("Device"), subtitle: L("Model, firmware, diagnostics"), symbol: "info.circle.fill", color: .gray) { DeviceView() }
        }
        .glassCard()
    }
}

struct MenuRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(color.gradient))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Volume (Bluetooth LE Audio Volume Control Service)

private struct VolumeCard: View {
    @EnvironmentObject private var buds: BudsController
    @State private var value: Double = 0
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: L("Earbud volume"), symbol: "speaker.wave.2")
                Text("\(percent) %").font(.subheadline.monospacedDigit().weight(.semibold))
            }
            HStack(spacing: 12) {
                Button { buds.stepVolume(up: false); Haptics.select() } label: {
                    Image(systemName: "minus").font(.body.weight(.bold)).frame(width: 40, height: 40)
                }
                .buttonStyle(.plain).glassCapsule()
                Slider(value: $value, in: 0...255) { isEditing in
                    editing = isEditing
                    if !isEditing { buds.setVolume(Int(value)); Haptics.select() }
                }
                .tint(Palette.accent)
                Button { buds.stepVolume(up: true); Haptics.select() } label: {
                    Image(systemName: "plus").font(.body.weight(.bold)).frame(width: 40, height: 40)
                }
                .buttonStyle(.plain).glassCapsule()
                Button { buds.setMuted(!buds.muted); Haptics.tap() } label: {
                    Image(systemName: buds.muted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.body).frame(width: 40, height: 40)
                        .foregroundStyle(buds.muted ? .red : .primary)
                }
                .buttonStyle(.plain).glassCapsule()
            }
            Text(L("Reported by the earbuds themselves – it changes when you swipe on an earbud too."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .glassCard()
        .disabled(!buds.canControl)
        .onAppear { value = Double(buds.volume ?? 0) }
        .onValueChange(of: buds.volume) { new in if !editing, let new { withAnimation(Motion.smooth) { value = Double(new) } } }
    }

    private var percent: Int { Int((Double(editing ? Int(value) : (buds.volume ?? 0)) / 255 * 100).rounded()) }
}
