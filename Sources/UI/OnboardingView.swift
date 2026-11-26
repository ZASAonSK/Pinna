import SwiftUI

struct OnboardingView: View {
    let finish: () -> Void
    @State private var page = 0

    private let pages: [(symbol: String, title: String, text: String)] = [
        ("earbuds", L("Welcome to Pinna"),
         L("Control your Samsung Galaxy Buds right from your iPhone: noise cancelling, ambient sound, equalizer, gestures and more.")),
        ("iphone.radiowaves.left.and.right", L("Pair them as usual"),
         L("Connect your earbuds in Settings → Bluetooth. Pinna then finds them on its own, no extra pairing.")),
        ("hand.raised.fingers.spread", L("How it works"),
         L("Pinna sends settings to your earbuds. The earbuds don't report their state back over Bluetooth LE, so the app shows what you set last.")),
    ]

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 24) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 22) {
                            Spacer()
                            if i == 0 {
                                LogoMark(size: 132)
                            } else {
                                Image(systemName: pages[i].symbol)
                                    .font(.system(size: 64, weight: .medium))
                                    .foregroundStyle(Palette.gradient)
                                    .frame(width: 132, height: 132)
                                    .glassCard(cornerRadius: 40)
                            }
                            Text(pages[i].title)
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            Text(pages[i].text)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    Haptics.tap()
                    if page < pages.count - 1 { withAnimation { page += 1 } } else { finish() }
                } label: {
                    Text(page < pages.count - 1 ? L("Continue") : L("Get started"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .glassButton(prominent: true)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }
}

/// The app logo drawn in SwiftUI (matches the app icon).
struct LogoMark: View {
    var size: CGFloat = 96
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Palette.gradient)
            Circle().fill(.white.opacity(0.12)).frame(width: size * 0.68)
            Circle().strokeBorder(.white.opacity(0.35), lineWidth: max(1, size * 0.008)).frame(width: size * 0.68)
            Image(systemName: "earbuds")
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(.white)
            Image(systemName: "wave.3.right")
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundStyle(Palette.mint)
                .offset(x: size * 0.25, y: -size * 0.06)
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.indigo.opacity(0.35), radius: size * 0.12, y: size * 0.06)
    }
}
