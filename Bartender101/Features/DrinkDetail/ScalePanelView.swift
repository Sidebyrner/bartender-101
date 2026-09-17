import SwiftUI

/// The recipe page's bottom bar: Shot/1×/2×/Batch, a servings −/+, an oz/ml
/// switch, and the "Made it" button that logs the drink at exactly these
/// settings — pinned within thumb reach and sized for Bartending Mode.
/// Presets just set `servings` to 0.5/1/2; there's no separate "double"
/// recipe path, so the presets and the −/+ can never drift out of sync.
struct ScalePanel: View {
    @Binding var servings: Double
    @Binding var batchMode: Bool
    @Binding var unitRaw: String
    /// Whether batch mode would actually add any dilution — false for
    /// built/blended/layered drinks, so the Batch button hides itself rather
    /// than offering a control that does nothing.
    let batchEligible: Bool
    let metrics: BarMetrics
    /// How many times this drink has been logged tonight.
    let madeTonight: Int
    /// True for a few seconds after logging, while Undo is offered.
    let justLogged: Bool
    let onMadeIt: () -> Void
    let onUndo: () -> Void

    static let servingsRange: ClosedRange<Double> = 0.5...24
    /// Servings Batch jumps to when turned on from a single-drink count.
    static let defaultBatchServings: Double = 8

    private static let presets: [(title: String, servings: Double)] = [
        ("Shot", 0.5), ("1×", 1), ("2×", 2)
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Self.presets, id: \.title) { preset in
                    BarButton(title: preset.title, isSelected: !batchMode && servings == preset.servings, metrics: metrics) {
                        batchMode = false
                        servings = preset.servings
                    }
                }
                if batchEligible {
                    BarButton(title: "Batch", systemImage: "drop.fill", isSelected: batchMode, metrics: metrics) {
                        batchMode.toggle()
                        if batchMode && servings < 4 {
                            servings = Self.defaultBatchServings
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                BarButton(systemImage: "minus", isSelected: false, metrics: metrics) {
                    servings = max(Self.servingsRange.lowerBound, servings - 0.5)
                }
                .disabled(servings <= Self.servingsRange.lowerBound)
                .accessibilityLabel("Fewer servings")

                Text("×\(Measure.ozFraction(servings))")
                    .font(metrics.buttonFont.monospacedDigit())
                    .contentTransition(.numericText(value: servings))
                    .frame(minWidth: metrics.isOn ? 64 : 48)
                    .accessibilityLabel("\(Measure.ozFraction(servings)) servings")

                BarButton(systemImage: "plus", isSelected: false, metrics: metrics) {
                    servings = min(Self.servingsRange.upperBound, servings + 0.5)
                }
                .disabled(servings >= Self.servingsRange.upperBound)
                .accessibilityLabel("More servings")

                Spacer(minLength: 8)

                HStack(spacing: 0) {
                    ForEach(MeasurementUnit.allCases) { option in
                        BarButton(title: option.displayName, isSelected: unitRaw == option.rawValue, metrics: metrics) {
                            unitRaw = option.rawValue
                        }
                    }
                }
                .frame(width: metrics.isOn ? 150 : 116)
            }

            HStack(spacing: 8) {
                Button(action: onMadeIt) {
                    HStack(spacing: 8) {
                        Image(systemName: justLogged ? "checkmark.circle.fill" : "checkmark.circle")
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.bounce, value: madeTonight)
                        Text(justLogged ? "Logged" : "Made it")
                            .contentTransition(.interpolate)
                        if madeTonight > 0 {
                            Text("· \(madeTonight) tonight")
                                .fontWeight(.regular)
                                .contentTransition(.numericText(value: Double(madeTonight)))
                        }
                    }
                    .font(metrics.buttonFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: metrics.tapHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.72, blue: 0.38), Color(red: 0.13, green: 0.6, blue: 0.3)], startPoint: .top, endPoint: .bottom))
                    )
                    .foregroundStyle(.white)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.pressable(scale: 0.97))
                .accessibilityHint("Logs this drink at the servings and units shown")

                if justLogged {
                    BarButton(title: "Undo", systemImage: "arrow.uturn.backward", isSelected: false, metrics: metrics, action: onUndo)
                        .frame(width: metrics.isOn ? 130 : 100)
                }
            }
        }
        .padding(.horizontal)
        .readableWidth()
        .padding(.vertical, 10)
        .background(.bar)
        .animation(Theme.snap, value: servings)
        .animation(Theme.snap, value: batchMode)
        .animation(Theme.spring, value: justLogged)
        .animation(Theme.snap, value: madeTonight)
        .sensoryFeedback(.selection, trigger: servings)
        .sensoryFeedback(.selection, trigger: unitRaw)
    }
}

/// A big, fully tappable button — the whole rounded rect is the hit area,
/// not just the label.
private struct BarButton: View {
    var title: String?
    var systemImage: String?
    let isSelected: Bool
    let metrics: BarMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                if let title { Text(title) }
            }
            .font(metrics.buttonFont)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: metrics.tapHeight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressable(scale: 0.94))
    }
}
