import Foundation
import WidgetKit

/// Writes what the app knows to the shared snapshot and asks iOS to refresh
/// widgets and Control Center controls. Reloads are coalesced so frequent
/// battery updates don't use up WidgetKit's refresh budget.
final class WidgetSync {
    static let shared = WidgetSync()
    private var pending = false

    func update(_ change: (inout SharedSnapshot) -> Void) {
        var snapshot = SharedState.load()
        let before = snapshot
        change(&snapshot)
        guard snapshot != before else { return }
        snapshot.updated = Date()
        SharedState.save(snapshot)
        scheduleReload()
    }

    private func scheduleReload() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.pending = false
            WidgetCenter.shared.reloadAllTimelines()
            if #available(iOS 18.0, *) { ControlCenter.shared.reloadAllControls() }
        }
    }
}
