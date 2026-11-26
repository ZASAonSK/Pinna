import SwiftUI

/// Lets the user pick their buds from nearby connectable devices. Buds are
/// shown first; renamed buds still appear in the list.
struct DevicePickerView: View {
    @EnvironmentObject private var buds: BudsController
    @Environment(\.dismiss) private var dismiss
    @State private var showAll = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 10) {
                            Image(systemName: "earbuds")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundStyle(Palette.gradient)
                                .frame(width: 84, height: 84)
                                .glassCard(cornerRadius: 28)
                            Text(L("Choose your earbuds")).font(.title2.bold())
                            Text(L("Keep your earbuds near the phone with the case open or in your ears. If you renamed them, look for your name."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        let list = devices
                        if list.isEmpty {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text(L("Looking for nearby devices…")).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .glassCard()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(list) { device in
                                    Button { pick(device) } label: { DeviceRow(device: device, current: device.id == currentID) }
                                        .buttonStyle(.plain)
                                    if device.id != list.last?.id { Divider().padding(.leading, 62) }
                                }
                            }
                            .glassCard()
                        }

                        Toggle(L("Show all devices"), isOn: $showAll)
                            .tint(Palette.accent)
                            .padding(16)
                            .glassCard(cornerRadius: 20)
                    }
                    .padding(18)
                }
            }
            .navigationTitle(L("Earbuds"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Close")) { dismiss() } }
            }
            .onAppear { buds.refreshNearby() }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    buds.refreshNearby()
                }
            }
        }
    }

    private var currentID: UUID? { buds.state == .ready || buds.state == .connecting ? buds.currentDeviceID : nil }

    private var devices: [NearbyDevice] {
        let recent = buds.nearby.filter { Date().timeIntervalSince($0.lastSeen) < 30 || $0.connectedToPhone }
        return showAll ? recent : recent.filter(\.likelyBuds)
    }

    private func pick(_ device: NearbyDevice) {
        Haptics.tap()
        buds.connect(to: device.id)
        dismiss()
    }
}

private struct DeviceRow: View {
    let device: NearbyDevice
    let current: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: device.likelyBuds ? "earbuds" : "dot.radiowaves.left.and.right")
                .font(.title3)
                .foregroundStyle(device.likelyBuds ? .white : .secondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(device.likelyBuds ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(.primary.opacity(0.08))))
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if current {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                SignalBars(rssi: device.rssi)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var detail: String {
        if device.connectedToPhone { return L("Connected to iPhone") }
        let model = BudsModel.detect(modelNumber: nil, name: device.name)
        return model == .unknown ? (device.likelyBuds ? L("Earbuds") : L("Nearby device")) : model.name
    }
}

private struct SignalBars: View {
    let rssi: Int
    private var level: Int {
        if rssi == 0 { return 3 }
        if rssi > -60 { return 3 }
        if rssi > -75 { return 2 }
        return 1
    }
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i <= level ? Palette.accent : Color.secondary.opacity(0.3))
                    .frame(width: 4, height: CGFloat(4 + i * 4))
            }
        }
        .accessibilityLabel(L("Signal %ld of 3", level))
    }
}
