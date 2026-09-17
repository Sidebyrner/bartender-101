import SwiftUI

/// The floating button that starts a new drink. Built to be noticed and to
/// feel good to press: an amber capsule with a soft glow, a light sweep of
/// shimmer every few seconds, a breathing glow when there's nothing built
/// yet, and a squeeze, bounce, and haptic on tap. Collapses to a round
/// button while a list scrolls. All the idle motion stops under Reduce Motion.
struct NewDrinkButton: View {
    var collapsed: Bool
    /// Breathes to draw the eye — for empty states.
    var emphasize: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0
    @State private var shimmerPhase: CGFloat = -1
    @State private var breathing = false

    var body: some View {
        Button {
            taps += 1
            // Let the bounce land before the sheet slides over it.
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.12)) { action() }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .black))
                        .symbolEffect(.bounce.up, value: taps)
                }
                if !collapsed {
                    Text("New Drink")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .fixedSize()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .foregroundStyle(.white)
            .padding(.leading, collapsed ? 0 : 12)
            .padding(.trailing, collapsed ? 0 : 20)
            .frame(width: collapsed ? 60 : nil, height: 60)
            .background {
                Capsule()
                    .fill(Theme.accentGradient())
                    .overlay {
                        // A top-lit highlight, so the button reads as a raised object.
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                            .padding(1.5)
                    }
                    .overlay { shimmer }
                    .clipShape(Capsule())
            }
            .shadow(color: Color.accentColor.opacity(breathing ? 0.65 : 0.4), radius: breathing ? 22 : 12, y: 8)
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.9))
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .animation(Theme.spring, value: collapsed)
        .accessibilityLabel("New Drink")
        .accessibilityHint("Start building a new house drink")
        .task(id: reduceMotion) { await runShimmer() }
        .onAppear(perform: updateBreathing)
        .onChange(of: emphasize) { updateBreathing() }
    }

    private var shimmer: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.45)
                .rotationEffect(.degrees(20))
                .offset(x: shimmerPhase * proxy.size.width * 1.3)
        }
        .allowsHitTesting(false)
    }

    private func runShimmer() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(emphasize ? 2.2 : 4))
            guard !Task.isCancelled else { return }
            shimmerPhase = -1
            withAnimation(.easeInOut(duration: 1.0)) { shimmerPhase = 1.2 }
        }
    }

    private func updateBreathing() {
        guard emphasize, !reduceMotion else {
            breathing = false
            return
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            breathing = true
        }
    }
}
