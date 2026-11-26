import SwiftUI

struct DeviceView: View {
    @EnvironmentObject private var buds: BudsController
    @State private var confirmForget = false
    @State private var showPicker = false

    var body: some View {
        SettingsPage(title: L("Device")) {
            GlassSection(title: L("Earbuds"), symbol: "earbuds") {
                InfoRow(title: L("Name"), value: buds.deviceName ?? "–")
                RowDivider()
                InfoRow(title: L("Model"), value: buds.model.name)
                RowDivider()
                InfoRow(title: L("Model number"), value: buds.modelNumber ?? "–")
                RowDivider()
                InfoRow(title: L("Firmware"), value: buds.firmware ?? "–")
                RowDivider()
                InfoRow(title: L("Support"), value: buds.model.verified ? L("Verified") : L("Experimental"))
            }
            if !buds.model.verified {
                Text(L("This model has not been tested on real hardware yet. Controls use the same messages as Samsung's app, but something may not work."))
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            }

            GlassSection(title: L("Connection"), symbol: "antenna.radiowaves.left.and.right") {
                Button { showPicker = true } label: {
                    Label(L("Choose other earbuds"), systemImage: "earbuds").frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                RowDivider()
                Button { buds.reconnect() } label: {
                    Label(L("Reconnect"), systemImage: "arrow.clockwise").frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                RowDivider()
                Button(role: .destructive) { confirmForget = true } label: {
                    Label(L("Forget earbuds"), systemImage: "xmark.circle").frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }

            NavigationLink { DiagnosticsView() } label: {
                HStack {
                    Label(L("Diagnostics"), systemImage: "stethoscope")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .padding(16)
                .glassCard(cornerRadius: 22, interactive: true)
            }
            .buttonStyle(.plain)

            NavigationLink { AboutView() } label: {
                HStack {
                    Label(L("About %@", AppInfo.name), systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .padding(16)
                .glassCard(cornerRadius: 22, interactive: true)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPicker) { DevicePickerView() }
        .confirmationDialog(L("Forget earbuds?"), isPresented: $confirmForget, titleVisibility: .visible) {
            Button(L("Forget"), role: .destructive) { buds.forget() }
        } message: {
            Text(L("The app disconnects and finds your earbuds again next time."))
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Connection status and a shareable log for support.
struct DiagnosticsView: View {
    @EnvironmentObject private var buds: BudsController
    @EnvironmentObject private var store: SettingsStore
    @State private var copied = false
    @State private var confirmReset = false

    var body: some View {
        SettingsPage(title: L("Diagnostics")) {
            GlassSection(title: L("Status"), symbol: "waveform.path.ecg") {
                InfoRow(title: L("Connection status"), value: stateText)
                RowDivider()
                InfoRow(title: L("Last sent"), value: buds.lastSendOK.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium) } ?? "–")
                if let e = buds.lastError {
                    RowDivider()
                    InfoRow(title: L("Error"), value: e)
                }
            }

            GlassSection(title: L("Log"), symbol: "list.bullet.rectangle",
                         footer: L("If something doesn't work, send this log. It only contains details about the connection to your earbuds.")) {
                HStack {
                    Button(copied ? L("Copied") : L("Copy")) {
                        UIPasteboard.general.string = buds.logText
                        copied = true
                        Haptics.tap()
                    }
                    .glassButton()
                    ShareLink(item: buds.logText) { Label(L("Share"), systemImage: "square.and.arrow.up") }
                        .glassButton()
                    Spacer()
                }
                .padding(12)
                RowDivider()
                VStack(alignment: .leading, spacing: 4) {
                    if buds.log.isEmpty {
                        Text(L("Empty so far.")).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(buds.log.suffix(80).reversed()) { line in
                        Text("\(line.date.formatted(date: .omitted, time: .standard))  \(line.text)")
                            .font(.caption2.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .textSelection(.enabled)
            }

            Button(role: .destructive) { confirmReset = true } label: {
                Label(L("Clear saved settings"), systemImage: "trash").frame(maxWidth: .infinity)
            }
            .glassButton()
        }
        .confirmationDialog(L("Clear saved settings?"), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(L("Clear"), role: .destructive) { store.resetStored() }
        } message: {
            Text(L("Your earbuds don't change; the app only forgets what you set last."))
        }
    }

    private var stateText: String {
        switch buds.state {
        case .ready: return L("Connected")
        case .connecting: return L("Connecting")
        case .searching: return L("Searching")
        case .noControlPath: return L("No control")
        case .bluetoothOff: return L("Bluetooth off")
        case .unauthorized: return L("Not allowed")
        }
    }
}

struct AboutView: View {
    var body: some View {
        SettingsPage(title: L("About")) {
            VStack(spacing: 12) {
                LogoMark(size: 110)
                Text(AppInfo.name).font(.largeTitle.bold())
                Text(L("Version %@", AppInfo.version)).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .glassCard()

            GlassSection(title: L("What the app can do"), symbol: "checkmark.seal") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L("Control noise modes and settings"), systemImage: "slider.horizontal.3")
                    Label(L("Live battery for earbuds and case"), systemImage: "battery.75percent")
                    Label(L("Live volume, including swipes on the earbud"), systemImage: "speaker.wave.2")
                }
                .font(.subheadline)
                .padding(16)
            }
            GlassSection(title: L("What it can't do"), symbol: "info.circle") {
                Text(L("Samsung earbuds don't send the current noise mode, in-ear state or settings to an iPhone – they only report them to Samsung's app on Android. The app therefore shows what you last set in it."))
                    .font(.subheadline)
                    .padding(16)
            }
            GlassSection(title: L("Supported models"), symbol: "checklist") {
                ForEach(BudsModel.all) { m in
                    HStack {
                        Text(m.name)
                        Spacer()
                        Text(m.verified ? L("Verified") : L("Experimental"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill((m.verified ? Color.green : Color.orange).opacity(0.2)))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if m.id != BudsModel.all.last?.id { RowDivider() }
                }
            }
            GlassSection(title: L("Thanks"), symbol: "heart") {
                Text(L("Protocol: GalaxyBudsClient (timschneeb), Gadgetbridge, SamsungGalaxyBuds2Pro (msrk0320). This app is not a Samsung product."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
            }
        }
    }
}
