import SwiftUI
import UIKit

enum AppInfo {
    static let name = "Pinna"
    static var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    /// New GitHub issue with the log filled in; the user reviews it before sending.
    /// Only the header and the last lines fit: GitHub cuts off long URLs.
    static func issueURL(log: String) -> URL? {
        let lines = log.components(separatedBy: "\n")
        let excerpt = (lines.prefix(1) + lines.dropFirst().suffix(60)).joined(separator: "\n")
        guard var c = URLComponents(string: "https://github.com/ZASAonSK/Pinna/issues/new") else { return nil }
        c.queryItems = [URLQueryItem(name: "body", value: "**What happened?**\n\n\n**Log**\n```\n\(excerpt)\n```\n")]
        let query = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        c.percentEncodedQuery = query
        return c.url
    }
}

/// Animations that match iOS 17's `.smooth` and fall back to a close
/// equivalent on iOS 16, so newer systems look exactly as before.
enum Motion {
    static var smooth: Animation { smooth(duration: 0.5) }
    static func smooth(duration: Double) -> Animation {
        if #available(iOS 17.0, *) { return .smooth(duration: duration) }
        return .spring(response: duration, dampingFraction: 1)
    }
}

extension View {
    /// `onChange` with the new value: the iOS 17 API where available, the
    /// iOS 16 one otherwise.
    @ViewBuilder
    func onValueChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, new in action(new) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}

enum Palette {
    static let indigo = Color(red: 0.20, green: 0.16, blue: 0.62)
    static let teal = Color(red: 0.05, green: 0.72, blue: 0.70)
    static let mint = Color(red: 0.55, green: 0.95, blue: 0.90)
    static let accent = Color(red: 0.30, green: 0.82, blue: 0.80)
    static let gradient = LinearGradient(colors: [indigo, teal], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func battery(_ level: Int?) -> Color {
        guard let level else { return .secondary }
        if level <= 15 { return .red }
        if level <= 35 { return .orange }
        return .green
    }
}

/// Soft animated backdrop that gives the glass something to refract.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    var body: some View {
        ZStack {
            (scheme == .dark ? Color.black : Color(white: 0.96)).ignoresSafeArea()
            // Radial gradients instead of blur(radius: 90): the same soft glow without a costly blur pass.
            glow(Palette.indigo.opacity(scheme == .dark ? 0.55 : 0.35), size: 600)
                .offset(x: phase ? -120 : -60, y: phase ? -260 : -200)
            glow(Palette.teal.opacity(scheme == .dark ? 0.45 : 0.30), size: 560)
                .offset(x: phase ? 140 : 90, y: phase ? 120 : 220)
        }
        .ignoresSafeArea()
        .onAppear {
            // A moving backdrop makes every frosted card re-blur each frame: unusable on iOS 16 devices (iPhone X, 1.9.1).
            guard #available(iOS 17.0, *), !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { phase.toggle() }
        }
    }

    private func glow(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
    }
}

// MARK: - Liquid Glass with graceful fallback

extension View {
    /// Liquid Glass on iOS 26+, frosted material with a hairline on older systems.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 26, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let base: Glass = tint.map { Glass.regular.tint($0.opacity(0.35)) } ?? .regular
            self.glassEffect(interactive ? base.interactive() : base, in: .rect(cornerRadius: cornerRadius))
        } else {
            materialCard(cornerRadius: cornerRadius, tint: tint)
        }
        #else
        materialCard(cornerRadius: cornerRadius, tint: tint)
        #endif
    }

    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let base: Glass = tint.map { Glass.regular.tint($0) } ?? .regular
            self.glassEffect(interactive ? base.interactive() : base, in: .capsule)
        } else {
            capsuleFallback(tint: tint)
        }
        #else
        capsuleFallback(tint: tint)
        #endif
    }

    @ViewBuilder
    private func materialCard(cornerRadius: CGFloat, tint: Color?) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 17.0, *) {
            self.background {
                shape.fill(.ultraThinMaterial).overlay(shape.fill((tint ?? .clear).opacity(0.18)))
            }
            .overlay(shape.strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        } else {
            // iOS 16 devices (iPhone 8/X) can't afford a blur and a shadow per card while scrolling.
            self.background { shape.fill(Color(.secondarySystemBackground)).overlay(shape.fill((tint ?? .clear).opacity(0.18))) }
                .overlay(shape.strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
        }
    }

    /// Capsule fallback below iOS 26: material on iOS 17+, solid on iOS 16 (see `materialCard`).
    @ViewBuilder
    fileprivate func capsuleFallback(tint: Color?) -> some View {
        if #available(iOS 17.0, *) {
            self.background(Capsule().fill(tint ?? Color.clear).background(.ultraThinMaterial, in: Capsule()))
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        } else {
            self.background(Capsule().fill(tint ?? Color.clear).background(Color(.secondarySystemBackground), in: Capsule()))
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        }
    }

    /// Glass button style on iOS 26, bordered on older systems.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
        #else
        if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        #endif
    }
}

/// Groups glass elements so they blend and morph together on iOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Section header used on glass screens.
struct SectionTitle: View {
    let text: String
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).foregroundStyle(Palette.accent) }
            Text(text).font(.footnote.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 6)
    }
}
