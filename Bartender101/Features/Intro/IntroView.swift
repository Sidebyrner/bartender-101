import SwiftUI

/// The first-launch intro: what the app is for, one page per area (look it
/// up, learn it, invent your own), and a quick setup of the two preferences
/// that matter most behind the bar. Shown once; Settings can bring it back.
/// Each page has a small live illustration of the real feature, which settles
/// into a still frame under Reduce Motion.
struct IntroView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var finished = 0

    private let pageCount = 5

    var body: some View {
        ZStack {
            IntroBackground(page: page)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pageCount - 1 {
                        Button("Skip") { withAnimation(Theme.spring) { page = pageCount - 1 } }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .transition(.opacity)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 8)

                TabView(selection: $page) {
                    WelcomePage(isActive: page == 0).tag(0)
                    FeaturePage(
                        isActive: page == 1,
                        eyebrow: "LOOK IT UP",
                        title: "Every spec, fast",
                        message: "Search ~180 drinks by name or ingredient. Scale to a shot, a double, or a batch in one tap, and log what you make tonight.",
                        illustration: { LookUpIllustration(isActive: page == 1) }
                    ).tag(1)
                    FeaturePage(
                        isActive: page == 2,
                        eyebrow: "LEARN IT COLD",
                        title: "Drill until it's muscle memory",
                        message: "Spaced review brings back what you miss. Speed Drill beats the clock. Name That Drink trains the guest-describes-it direction.",
                        illustration: { StudyIllustration(isActive: page == 2) }
                    ).tag(2)
                    FeaturePage(
                        isActive: page == 3,
                        eyebrow: "INVENT YOUR OWN",
                        title: "From idea to the menu",
                        message: "Start from a classic ratio, watch the balance meter, and move each idea from testing to the menu — with tasting notes and photos along the way.",
                        illustration: { BuildIllustration(isActive: page == 3) }
                    ).tag(3)
                    SetupPage(isActive: page == 4).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(Theme.spring, value: page)

                footer
                    .readableWidth(520)
            }
        }
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.selection, trigger: page)
        .sensoryFeedback(.success, trigger: finished)
    }

    private var footer: some View {
        VStack(spacing: 22) {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.accentColor : .white.opacity(0.3))
                        .frame(width: index == page ? 24 : 8, height: 8)
                }
            }
            .animation(Theme.snap, value: page)
            .accessibilityElement()
            .accessibilityLabel("Page \(page + 1) of \(pageCount)")

            Button {
                if page < pageCount - 1 {
                    withAnimation(Theme.spring) { page += 1 }
                } else {
                    finished += 1
                    onFinish()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(page < pageCount - 1 ? "Next" : "Get Started")
                        .contentTransition(.interpolate)
                    Image(systemName: page < pageCount - 1 ? "arrow.right" : "checkmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background {
                    Capsule()
                        .fill(Theme.accentGradient())
                        .overlay(
                            Capsule()
                                .fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center))
                                .padding(1.5)
                        )
                }
                .shadow(color: Color.accentColor.opacity(0.5), radius: 16, y: 8)
            }
            .buttonStyle(.pressable(scale: 0.95))
            .animation(Theme.spring, value: page)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
    }
}

// MARK: - Background

/// Deep navy into warm amber — the colors of the app icon — with a soft glow
/// that drifts a little as you page.
private struct IntroBackground: View {
    let page: Int

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.07, blue: 0.13), Color(red: 0.11, green: 0.09, blue: 0.1), Color(red: 0.2, green: 0.11, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.accentColor.opacity(0.45), .clear],
                center: UnitPoint(x: 0.3 + Double(page) * 0.1, y: 0.32),
                startRadius: 10,
                endRadius: 360
            )
            .blendMode(.plusLighter)
            .animation(.easeInOut(duration: 0.8), value: page)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Pages

private struct WelcomePage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.25))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .scaleEffect(floating ? 1.1 : 0.95)
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 110, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(red: 1, green: 0.78, blue: 0.45), .accentColor], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color.accentColor.opacity(0.6), radius: 20)
                    .offset(y: floating ? -8 : 8)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("House Pour")
                    .font(.system(size: 44, weight: .bold, design: .serif))
                Text("Look it up. Learn it cold.\nInvent your own.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))
                Text("For adults of legal drinking age. Please drink responsibly.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
            }
            .modifier(PageEntrance(isActive: isActive))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .readableWidth(560)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { floating = true }
        }
    }
}

private struct FeaturePage<Illustration: View>: View {
    let isActive: Bool
    let eyebrow: String
    let title: String
    let message: String
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 10)
            illustration()
                .frame(height: 260)
                .modifier(PageEntrance(isActive: isActive, delay: 0))
            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow)
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(PageEntrance(isActive: isActive, delay: 0.08))
            Spacer(minLength: 10)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .readableWidth(560)
    }
}

private struct SetupPage: View {
    let isActive: Bool
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @AppStorage(SettingsKeys.bartendingMode) private var barMode = true

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text("MAKE IT YOURS")
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Color.accentColor)
                Text("Set up for your bar")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                Text("You can change these any time in Settings.")
                    .foregroundStyle(.white.opacity(0.72))
            }
            .modifier(PageEntrance(isActive: isActive))

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Measure in", systemImage: "ruler")
                        .font(.headline)
                    Picker("Units", selection: $unitRaw) {
                        Text("Ounces").tag(MeasurementUnit.oz.rawValue)
                        Text("Milliliters").tag(MeasurementUnit.ml.rawValue)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))

                Toggle(isOn: $barMode) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Bartending Mode", systemImage: "wineglass")
                            .font(.headline)
                        Text("Big text and big buttons, readable at arm's length mid-shift.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .tint(.accentColor)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
            }
            .modifier(PageEntrance(isActive: isActive, delay: 0.08))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .readableWidth(560)
    }
}

/// Content rises and fades in each time its page becomes current.
private struct PageEntrance: ViewModifier {
    let isActive: Bool
    var delay: Double = 0.04
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(y: isActive || reduceMotion ? 0 : 24)
            .animation(Theme.spring.delay(isActive ? delay : 0), value: isActive)
    }
}

// MARK: - Illustrations

/// A mini recipe card that scales itself between 1× and 2×, numbers rolling.
private struct LookUpIllustration: View {
    let isActive: Bool
    @State private var doubled = false

    private let lines: [(Double, String)] = [(2, "White rum"), (0.75, "Lime juice"), (0.75, "Simple syrup")]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daiquiri")
                    .font(.system(.title2, design: .serif, weight: .bold))
                Spacer()
                HStack(spacing: 4) {
                    ForEach([false, true], id: \.self) { isDouble in
                        Text(isDouble ? "2×" : "1×")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(doubled == isDouble ? Color.accentColor : .white.opacity(0.1)))
                    }
                }
            }
            ForEach(lines, id: \.1) { oz, name in
                HStack(spacing: 12) {
                    Text("\(Measure.ozFraction(doubled ? oz * 2 : oz)) oz")
                        .font(.system(.title3, design: .rounded, weight: .bold).monospacedDigit())
                        .contentTransition(.numericText(value: doubled ? oz * 2 : oz))
                        .frame(width: 80, alignment: .leading)
                    Text(name)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            HStack {
                Spacer()
                Label("Made it", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.green.opacity(0.85)))
            }
        }
        .padding(22)
        .background(IllustrationCard())
        .accessibilityElement()
        .accessibilityLabel("A daiquiri recipe scaling from single to double")
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
                withAnimation(Theme.spring) { doubled.toggle() }
            }
        }
    }
}

/// A mini flashcard that turns over and back.
private struct StudyIllustration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flipped = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                cardFace {
                    VStack(spacing: 8) {
                        Text("Negroni")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                        Text("MANHATTAN FAMILY")
                            .font(.caption2.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .opacity(flipped ? 0 : 1)

                cardFace {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(["1 oz  Gin", "1 oz  Campari", "1 oz  Sweet vermouth"], id: \.self) { line in
                            Text(line).font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        Text("Stir · rocks · orange peel")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(flipped && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .frame(width: 250, height: 170)

            HStack(spacing: 8) {
                ForEach([("brain.head.profile", "Review"), ("timer", "Speed"), ("text.magnifyingglass", "Name It")], id: \.1) { icon, title in
                    Label(title, systemImage: icon)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("A flashcard turning over to show the Negroni's spec")
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.6, dampingFraction: 0.8)) {
                    flipped.toggle()
                }
            }
        }
    }

    private func cardFace<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(IllustrationCard())
            .overlay(alignment: .top) {
                Capsule().fill(Theme.accentGradient()).frame(width: 60, height: 4).padding(.top, 10)
            }
    }
}

/// Three board columns with a drink card stepping from idea to the menu.
private struct BuildIllustration: View {
    let isActive: Bool
    @State private var step = 0

    private let stages: [TestStage] = [.idea, .testing, .onMenu]

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 10
            let columnWidth = (proxy.size.width - spacing * 2) / 3
            ZStack(alignment: .topLeading) {
                HStack(spacing: spacing) {
                    ForEach(stages) { stage in
                        VStack(spacing: 8) {
                            Image(systemName: stage.systemImage)
                                .font(.title3)
                                .foregroundStyle(stage.tint)
                            Text(stage.displayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                        }
                        .padding(.top, 14)
                        .frame(width: columnWidth, height: proxy.size.height)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white.opacity(stages[step] == stage ? 0.12 : 0.06))
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Garden Sour")
                        .font(.system(.subheadline, design: .serif, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Gin · basil")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                    HStack(spacing: 2) {
                        ForEach(0..<5) { star in
                            Image(systemName: star < 2 + step ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                .padding(10)
                .frame(width: columnWidth - 12, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.16, green: 0.15, blue: 0.17))
                        .overlay(alignment: .leading) {
                            UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12)
                                .fill(stages[step].tint)
                                .frame(width: 4)
                        }
                )
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .offset(x: CGFloat(step) * (columnWidth + spacing) + 6, y: 80)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("A house drink moving from idea, to testing, to the menu")
        .task(id: isActive) {
            guard isActive else { return }
            step = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    step = (step + 1) % stages.count
                }
            }
        }
    }
}

private struct IllustrationCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(red: 0.13, green: 0.12, blue: 0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}
