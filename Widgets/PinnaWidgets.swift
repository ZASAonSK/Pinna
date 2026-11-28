import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Bundle

@main
struct PinnaWidgetBundle: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
        NoiseWidget()
        BudsWidget()
        if #available(iOS 18.0, *) {
            NoiseCancellingControl()
            AmbientControl()
            NoiseOffControl()
            AdaptiveControl()
        }
    }
}

// MARK: - Timeline

struct BudsEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot

    var mode: NoiseMode? { snapshot.noiseMode.flatMap(NoiseMode.init(rawValue:)) }
    var hasData: Bool { snapshot.left != nil || snapshot.right != nil || snapshot.caseLevel != nil || snapshot.noiseMode != nil }

    static let preview = BudsEntry(date: Date(), snapshot: SharedSnapshot(
        deviceName: "Galaxy Buds3 Pro", left: 85, right: 90, caseLevel: 60,
        noiseMode: NoiseMode.anc.rawValue, connected: true, updated: Date()))
}

struct BudsProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudsEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (BudsEntry) -> Void) {
        let entry = BudsEntry(date: Date(), snapshot: SharedState.load())
        completion(context.isPreview && !entry.hasData ? .preview : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudsEntry>) -> Void) {
        // The app pushes fresh data and reloads; this is only a fallback.
        let entry = BudsEntry(date: Date(), snapshot: SharedState.load())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

// MARK: - Style

enum WStyle {
    static let indigo = Color(red: 0.20, green: 0.16, blue: 0.62)
    static let teal = Color(red: 0.05, green: 0.72, blue: 0.70)
    static let gradient = LinearGradient(colors: [indigo, teal], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func battery(_ level: Int?) -> Color {
        guard let level else { return .white.opacity(0.4) }
        if level <= 15 { return .red }
        if level <= 35 { return .orange }
        return .green
    }
}

extension View {
    /// Widget background: required container background on iOS 17+.
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { WStyle.gradient }
        } else {
            self.background(WStyle.gradient)
        }
    }
}

// MARK: - Pieces

struct Ring: View {
    let level: Int?
    let label: String
    var size: CGFloat = 46

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(.white.opacity(0.2), lineWidth: size * 0.11)
                Circle()
                    .trim(from: 0, to: CGFloat(level ?? 0) / 100)
                    .stroke(WStyle.battery(level), style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(level.map { "\($0)" } ?? "–")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
            .frame(width: size, height: size)
            Text(label).font(.caption2.weight(.medium)).opacity(0.85).lineLimit(1)
        }
        .foregroundStyle(.white)
    }
}

struct ModeButton: View {
    let option: NoiseModeOption
    let selected: Bool

    var body: some View {
        let content = VStack(spacing: 3) {
            Image(systemName: option.mode.symbol).font(.system(size: 15, weight: .semibold))
            Text(option.mode.title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(selected ? WStyle.indigo : .white)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(selected ? Color.white : Color.white.opacity(0.16)))

        if #available(iOS 17.0, *) {
            Button(intent: WidgetSetNoiseModeIntent(mode: option)) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

private func modeOptions() -> [NoiseModeOption] {
    // Without a known model show the common modes; adaptive only when it was used.
    [.off, .anc, .ambient, .adaptive]
}

struct EmptyHint: View {
    var body: some View {
        Text(L("Open Pinna once to connect."))
            .font(.caption)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Battery widget (Home Screen + Lock Screen)

struct BatteryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "io.github.zasaonsk.pinna.battery", provider: BudsProvider()) { entry in
            BatteryWidgetView(entry: entry)
        }
        .configurationDisplayName(L("Battery"))
        .description(L("Battery of your earbuds and the case."))
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct BatteryWidgetView: View {
    let entry: BudsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(L("L")) \(text(entry.snapshot.left)) · \(L("R")) \(text(entry.snapshot.right)) · \(L("Case")) \(text(entry.snapshot.caseLevel))")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    side(L("L"), entry.snapshot.left)
                    side(L("R"), entry.snapshot.right)
                }
            }
            .lockScreenBackground()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label(entry.snapshot.deviceName ?? "Pinna", systemImage: "earbuds").font(.caption.weight(.semibold)).lineLimit(1)
                Text("\(L("Left")) \(text(entry.snapshot.left)) · \(L("Right")) \(text(entry.snapshot.right))").font(.caption)
                Text("\(L("Case")) \(text(entry.snapshot.caseLevel))").font(.caption)
            }
            .lockScreenBackground()
        default:
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "earbuds").font(.caption.weight(.bold))
                    Text(entry.snapshot.deviceName ?? "Pinna").font(.caption.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                if entry.hasData {
                    HStack(spacing: 6) {
                        Ring(level: entry.snapshot.left, label: L("L"), size: 38)
                        Ring(level: entry.snapshot.right, label: L("R"), size: 38)
                    }
                    Ring(level: entry.snapshot.caseLevel, label: L("Case"), size: 30)
                } else {
                    Spacer()
                    EmptyHint()
                    Spacer()
                }
            }
            .widgetBackground()
        }
    }

    private func text(_ v: Int?) -> String { v.map { "\($0)%" } ?? "–" }

    /// One line of the circular Lock Screen widget, e.g. "Ľ 85".
    private func side(_ label: String, _ level: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(label).font(.system(size: 11, weight: .semibold)).opacity(0.7)
            Text(level.map { "\($0)" } ?? "–").font(.system(size: 17, weight: .bold, design: .rounded))
        }
        .minimumScaleFactor(0.7)
        .widgetAccentable()
    }
}

extension View {
    /// Lock Screen widgets need an (empty) container background on iOS 17+.
    @ViewBuilder
    func lockScreenBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}

// MARK: - Noise control widget

struct NoiseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "io.github.zasaonsk.pinna.noise", provider: BudsProvider()) { entry in
            NoiseWidgetView(entry: entry)
        }
        .configurationDisplayName(L("Noise control"))
        .description(L("Switch noise control from the Home Screen."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NoiseWidgetView: View {
    let entry: BudsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: entry.mode?.symbol ?? "waveform").font(.subheadline.weight(.bold))
                Text(entry.mode?.title ?? L("Noise control")).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            if family == .systemSmall {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(modeOptions(), id: \.self) { option in
                        ModeButton(option: option, selected: entry.mode == option.mode)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(modeOptions(), id: \.self) { option in
                        ModeButton(option: option, selected: entry.mode == option.mode)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .widgetBackground()
    }
}

// MARK: - Battery + noise widget

struct BudsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "io.github.zasaonsk.pinna.buds", provider: BudsProvider()) { entry in
            BudsWidgetView(entry: entry)
        }
        .configurationDisplayName(L("Battery & noise control"))
        .description(L("Battery of your earbuds and the case."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct BudsWidgetView: View {
    let entry: BudsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 16 : 10) {
            HStack(spacing: 6) {
                Image(systemName: "earbuds").font(.caption.weight(.bold))
                Text(entry.snapshot.deviceName ?? "Pinna").font(.caption.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 0)
                if let updated = entry.snapshot.updated {
                    Text(updated, style: .relative).font(.caption2).opacity(0.7)
                }
            }
            .foregroundStyle(.white)
            HStack(spacing: 0) {
                let size: CGFloat = family == .systemLarge ? 64 : 40
                Ring(level: entry.snapshot.left, label: L("Left"), size: size).frame(maxWidth: .infinity)
                Ring(level: entry.snapshot.right, label: L("Right"), size: size).frame(maxWidth: .infinity)
                Ring(level: entry.snapshot.caseLevel, label: L("Case"), size: size).frame(maxWidth: .infinity)
            }
            HStack(spacing: 6) {
                ForEach(modeOptions(), id: \.self) { option in
                    ModeButton(option: option, selected: entry.mode == option.mode)
                }
            }
            if family == .systemLarge { Spacer(minLength: 0) }
        }
        .widgetBackground()
    }
}

// MARK: - Control Center (iOS 18)

@available(iOS 18.0, *)
struct NoiseCancellingProvider: ControlValueProvider {
    var previewValue: Bool { true }
    func currentValue() async throws -> Bool {
        SharedState.load().noiseMode == NoiseMode.anc.rawValue
    }
}

@available(iOS 18.0, *)
struct NoiseCancellingControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "io.github.zasaonsk.pinna.control.anc", provider: NoiseCancellingProvider()) { isOn in
            ControlWidgetToggle(L("Noise cancelling"), isOn: isOn, action: SetNoiseCancellingIntent()) { on in
                Label(on ? L("ANC") : L("Ambient"), systemImage: on ? "person.wave.2.fill" : "ear")
            }
            .tint(WStyle.teal)
        }
        .displayName(LocalizedStringResource(stringLiteral: L("Noise cancelling")))
        .description(LocalizedStringResource(stringLiteral: L("Switches noise cancelling on or off.")))
    }
}

@available(iOS 18.0, *)
struct AmbientControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "io.github.zasaonsk.pinna.control.ambient") {
            ControlWidgetButton(action: WidgetSetNoiseModeIntent(mode: .ambient)) {
                Label(NoiseMode.ambient.title, systemImage: NoiseMode.ambient.symbol)
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: NoiseMode.ambient.title))
        .description(LocalizedStringResource(stringLiteral: L("Sets this noise mode.")))
    }
}

@available(iOS 18.0, *)
struct NoiseOffControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "io.github.zasaonsk.pinna.control.off") {
            ControlWidgetButton(action: WidgetSetNoiseModeIntent(mode: .off)) {
                Label(NoiseMode.off.title, systemImage: NoiseMode.off.symbol)
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: L("Noise control") + ": " + NoiseMode.off.title))
        .description(LocalizedStringResource(stringLiteral: L("Sets this noise mode.")))
    }
}

@available(iOS 18.0, *)
struct AdaptiveControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "io.github.zasaonsk.pinna.control.adaptive") {
            ControlWidgetButton(action: WidgetSetNoiseModeIntent(mode: .adaptive)) {
                Label(NoiseMode.adaptive.title, systemImage: NoiseMode.adaptive.symbol)
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: NoiseMode.adaptive.title))
        .description(LocalizedStringResource(stringLiteral: L("Sets this noise mode.")))
    }
}
