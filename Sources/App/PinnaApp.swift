import SwiftUI

@main
struct PinnaApp: App {
    @StateObject private var controller: BudsController
    @StateObject private var store: SettingsStore

    init() {
        _controller = StateObject(wrappedValue: BudsController.shared)
        _store = StateObject(wrappedValue: SettingsStore.shared)
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
