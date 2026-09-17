import SwiftUI

/// Shared look and motion: the card surface every screen uses, a pressable
/// button style, the springs animations are tuned to, and a few effects
/// (shake, confetti, progress ring). Kept in one place so the app feels like
/// one thing — and so Reduce Motion is honored everywhere at once.
enum Theme {
    /// The default spring for state changes you can see: selections, cards
    /// moving, rows appearing.
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
    /// A quicker, bouncier spring for small confirmations.
    static let snap = Animation.spring(response: 0.28, dampingFraction: 0.68)

    static let cornerRadius: CGFloat = 16

    /// A warm diagonal wash of the accent color, for hero tiles and icons.
    static func accentGradient(_ color: Color = .accentColor) -> LinearGradient {
        LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Readable width

extension View {
    /// Holds content to a comfortable reading width and centers it — a no-op
    /// on iPhone, and keeps lines from stretching across a full iPad screen.
    func readableWidth(_ maxWidth: CGFloat = 680) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Card surface

private struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat
    var elevated: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 1)
            )
            // Shadows read as grime on dark backgrounds; the hairline carries it there.
            .shadow(color: .black.opacity(elevated && colorScheme == .light ? 0.08 : 0), radius: 12, y: 5)
    }
}

extension View {
    /// The app's card: rounded, filled, a hairline edge, and an optional soft lift.
    func cardSurface(cornerRadius: CGFloat = Theme.cornerRadius, elevated: Bool = false) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius, elevated: elevated))
    }
}

// MARK: - Pressable buttons

/// Squeezes slightly and dims while held, springing back on release — the
/// tactile "this is a button" cue for custom-drawn buttons that `.plain`
/// style otherwise leaves dead.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Theme.snap, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle { PressableButtonStyle(scale: scale) }
}

// MARK: - Shake

/// A horizontal wobble for a wrong answer. Drive it by incrementing
/// `trigger`; with Reduce Motion on it does nothing (color and haptics
/// still say "wrong").
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes * 2), y: 0))
    }
}

extension View {
    func shake(trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

private struct ShakeModifier: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: reduceMotion ? 0 : CGFloat(trigger)))
            .animation(reduceMotion ? nil : .linear(duration: 0.4), value: trigger)
    }
}

// MARK: - Progress ring

/// A rounded ring that fills to `progress` (0…1), animating as it changes.
struct ProgressRing<Label: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = .accentColor
    @ViewBuilder var label: () -> Label

    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, shown)))
                .stroke(Theme.accentGradient(tint), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // A round cap on an empty ring draws a stray dot.
                .opacity(shown > 0.002 ? 1 : 0)
            label()
        }
        .onAppear { update(animated: !reduceMotion) }
        .onChange(of: progress) { update(animated: !reduceMotion) }
        .accessibilityElement(children: .combine)
    }

    private func update(animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { shown = progress }
        } else {
            shown = progress
        }
    }
}

// MARK: - Confetti

/// A one-shot burst of little amber, copper, and gold pieces, for a moment
/// worth celebrating (a drink going on the menu). Increment `trigger` to
/// fire. Skipped entirely under Reduce Motion.
struct ConfettiBurst: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pieces: [Piece] = []
    @State private var launched = false

    private struct Piece: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let spin: Double
        let color: Color
        let size: CGSize
    }

    private static let palette: [Color] = [.accentColor, .orange, .yellow, Color(red: 0.72, green: 0.42, blue: 0.2), .pink]

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(piece.color)
                    .frame(width: piece.size.width, height: piece.size.height)
                    .rotationEffect(.degrees(launched ? piece.spin : 0))
                    .offset(
                        x: launched ? cos(piece.angle) * piece.distance : 0,
                        y: launched ? sin(piece.angle) * piece.distance + 60 : 0
                    )
                    .opacity(launched ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { fire() }
    }

    private func fire() {
        guard !reduceMotion else { return }
        launched = false
        pieces = (0..<36).map { _ in
            Piece(
                angle: Double.random(in: 0...(2 * .pi)),
                distance: CGFloat.random(in: 90...220),
                spin: Double.random(in: -540...540),
                color: Self.palette.randomElement()!,
                size: CGSize(width: CGFloat.random(in: 5...9), height: CGFloat.random(in: 8...14))
            )
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 1.1)) { launched = true }
        }
    }
}

// MARK: - Icon tile

/// A rounded, gradient-filled square holding an SF Symbol — used for drill
/// entries and section heroes.
struct IconTile: View {
    let systemImage: String
    var tint: Color = .accentColor
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.accentGradient(tint), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .shadow(color: tint.opacity(0.35), radius: 6, y: 3)
    }
}

extension TestStage {
    /// One distinct color per board column, so a card's stage reads at a glance.
    var tint: Color {
        switch self {
        case .idea: return .yellow
        case .testing: return .blue
        case .dialedIn: return .purple
        case .onMenu: return .green
        case .shelved: return .gray
        }
    }
}

extension DrinkFamily {
    /// An SF Symbol for each family, for tiles and pickers.
    var systemImage: String {
        switch self {
        case .highball: return "takeoutbag.and.cup.and.straw"
        case .mule: return "mug"
        case .sour: return "circle.lefthalf.filled"
        case .oldFashioned: return "cube"
        case .martini: return "wineglass"
        case .manhattan: return "moon.stars"
        case .spritz: return "bubbles.and.sparkles"
        case .tiki: return "sun.max"
        case .muddled: return "leaf"
        case .cream: return "birthday.cake"
        case .shot: return "bolt"
        case .misc: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .highball: return .teal
        case .mule: return .brown
        case .sour: return .yellow
        case .oldFashioned: return .orange
        case .martini: return .indigo
        case .manhattan: return .red
        case .spritz: return .pink
        case .tiki: return .green
        case .muddled: return .mint
        case .cream: return .purple
        case .shot: return .blue
        case .misc: return .gray
        }
    }
}
