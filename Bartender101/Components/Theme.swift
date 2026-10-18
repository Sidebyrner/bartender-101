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
            // A neutral track rather than a tinted one. At zero the filled arc
            // is hidden entirely, so the track is the only thing drawn — and a
            // 15%-opacity tint is close to invisible in both appearances.
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)
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

// MARK: - Unit picker

/// The oz/ml switch, in the app's own button idiom rather than a system
/// segmented control.
///
/// The stock `.segmented` picker draws its selection in a system material that
/// reads grey-on-grey over the intro's dark gradient, and `.tint()` doesn't
/// reach it — but which unit you're pouring in is worth seeing at a glance
/// mid-shift. This matches the amber pair already pinned to the recipe page,
/// so the same preference looks the same everywhere it appears.
struct UnitPicker: View {
    @Binding var unitRaw: String
    var minHeight: CGFloat = 44

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MeasurementUnit.allCases) { unit in
                let isSelected = unitRaw == unit.rawValue
                Button {
                    unitRaw = unit.rawValue
                } label: {
                    Text(unit == .oz ? "Ounces" : "Milliliters")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: minHeight)
                        .background(
                            Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .contentShape(Capsule())
                }
                .buttonStyle(.pressable(scale: 0.95))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .animation(Theme.snap, value: unitRaw)
        .accessibilityLabel("Measure in")
    }
}

// MARK: - Flip card

/// A card that turns over in 3D. Both faces live in the same box, and the one
/// facing away is switched off at the exact halfway point of the turn — so no
/// frame ever shows the back's text mirrored through the front.
///
/// SwiftUI has no backface culling, and an opacity driven off a `Bool` fades on
/// its own curve instead of tracking the rotation, which is what lets the back
/// bleed through mid-flip. So this owns the angle: `Animatable` hands the
/// interpolated angle to `body` every frame, making "which face is toward the
/// camera" a fact about the frame rather than a guess about the animation's
/// timing. Reduce Motion skips the turn and crossfades instead.
struct FlipCard<Front: View, Back: View>: View {
    /// false shows the front, true shows the back.
    var isFlipped: Bool
    /// How much the turn foreshortens; 0 is flat.
    var perspective: CGFloat = 0.4
    /// The turn.
    var animation: Animation = .spring(response: 0.55, dampingFraction: 0.78)
    /// The crossfade used instead, under Reduce Motion.
    var reduceMotionAnimation: Animation = .easeInOut(duration: 0.2)

    private let front: Front
    private let back: Back

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isFlipped: Bool,
        perspective: CGFloat = 0.4,
        animation: Animation = .spring(response: 0.55, dampingFraction: 0.78),
        reduceMotionAnimation: Animation = .easeInOut(duration: 0.2),
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) {
        self.isFlipped = isFlipped
        self.perspective = perspective
        self.animation = animation
        self.reduceMotionAnimation = reduceMotionAnimation
        // Built once per update, not once per animation frame.
        self.front = front()
        self.back = back()
    }

    var body: some View {
        if reduceMotion {
            // No turn at all: a straight crossfade, neither face ever mirrored.
            ZStack {
                front.opacity(isFlipped ? 0 : 1)
                back.opacity(isFlipped ? 1 : 0)
            }
            .animation(reduceMotionAnimation, value: isFlipped)
        } else {
            Turn(angle: isFlipped ? 180 : 0, perspective: perspective, front: front, back: back)
                .animation(animation, value: isFlipped)
        }
    }

    /// The turning half. `Animatable` makes `angle` the animated value, so
    /// `body` runs with the in-between angles and can switch off the face that
    /// has turned away.
    private struct Turn: View, Animatable {
        var angle: Double
        var perspective: CGFloat
        var front: Front
        var back: Back

        var animatableData: Double {
            get { angle }
            set { angle = newValue }
        }

        /// Past 90° the back is the face toward the camera. The swap happens
        /// while the card is edge-on and zero pixels wide, so it is never seen
        /// — and a spring overshooting 180° stays on the right side of it.
        private var showingBack: Bool { angle >= 90 }

        var body: some View {
            ZStack {
                front
                    .opacity(showingBack ? 0 : 1)
                    .accessibilityHidden(showingBack)
                back
                    // Pre-mirrored, so it reads correctly once the card has turned.
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(showingBack ? 1 : 0)
                    .accessibilityHidden(!showingBack)
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: perspective)
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
