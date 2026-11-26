import SwiftUI

@main
struct PinnaApp: App {
    @StateObject private var controller: BudsController
    @StateObject private var store: SettingsStore

    init() {
        let controller = BudsController()
        _controller = StateObject(wrappedValue: controller)
        _store = StateObject(wrappedValue: SettingsStore(controller: controller))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
                .environmentObject(store)
                .tint(Palette.accent)
        }
    }
}

struct RootView: View {
    @AppStorage("pinna.onboarded") private var onboarded = false

    var body: some View {
        if onboarded {
            HomeView()
        } else {
            OnboardingView { withAnimation(Motion.smooth) { onboarded = true } }
        }
    }
}
