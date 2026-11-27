import SwiftUI

/// Cards the Home screen can show, in the user's order.
enum HomeCard: String, CaseIterable, Identifiable {
    case battery, volume, noise, equalizer, tiles, menu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: return L("Battery")
        case .volume: return L("Earbud volume")
        case .noise: return L("Noise control")
        case .equalizer: return L("Equalizer")
        case .tiles: return L("Quick toggles")
        case .menu: return L("Settings")
        }
    }

    var symbol: String {
        switch self {
        case .battery: return "battery.75percent"
        case .volume: return "speaker.wave.2"
        case .noise: return "waveform"
        case .equalizer: return "slider.vertical.3"
        case .tiles: return "square.grid.2x2"
        case .menu: return "list.bullet"
        }
    }

    /// The settings menu is the only way to the other screens, so it always stays.
    var canHide: Bool { self != .menu }

    static let defaultOrder: [HomeCard] = [.battery, .volume, .noise, .tiles, .menu]
}

/// Visible cards and their order, stored locally.
final class HomeLayout: ObservableObject {
    static let shared = HomeLayout()
    private static let key = "pinna.home.cards"

    @Published var visible: [HomeCard] {
        didSet { UserDefaults.standard.set(visible.map(\.rawValue), forKey: Self.key) }
    }

    var hidden: [HomeCard] { HomeCard.allCases.filter { !visible.contains($0) } }

    private init() {
        let saved = (UserDefaults.standard.stringArray(forKey: Self.key) ?? []).compactMap(HomeCard.init(rawValue:))
        var cards = saved.isEmpty ? HomeCard.defaultOrder : saved
        if !cards.contains(.menu) { cards.append(.menu) }
        visible = cards
    }

    func show(_ card: HomeCard) {
        guard !visible.contains(card) else { return }
        visible.append(card)
    }

    func hide(_ card: HomeCard) {
        guard card.canHide else { return }
        visible.removeAll { $0 == card }
    }

    func reset() { visible = HomeCard.defaultOrder }
}

struct HomeEditorView: View {
    @ObservedObject private var layout = HomeLayout.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layout.visible) { card in
                        CardRow(card: card)
                            .deleteDisabled(!card.canHide)
                    }
                    .onMove { layout.visible.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        offsets.map { layout.visible[$0] }.forEach(layout.hide)
                    }
                } header: {
                    Text(L("On Home"))
                } footer: {
                    Text(L("Drag to reorder, tap – to hide. Cards for features your earbuds don't have are not shown."))
                }

                if !layout.hidden.isEmpty {
                    Section(L("More cards")) {
                        ForEach(layout.hidden) { card in
                            Button { withAnimation { layout.show(card) } } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .green)
                                    CardRow(card: card)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.primary)
                        }
                    }
                }

                Section {
                    Button(L("Reset"), role: .destructive) { withAnimation { layout.reset() } }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(L("Edit Home"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
    }
}

private struct CardRow: View {
    let card: HomeCard

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: card.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.gradient))
            Text(card.title)
        }
    }
}
