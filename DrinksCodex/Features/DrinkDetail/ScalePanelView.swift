import SwiftUI

/// Servings stepper, shot/single/double presets, the batch toggle, and the
/// oz/ml switch — every piece of the scaling feature lives in this one
/// panel. Presets just set `servings` to 0.5/1/2; there's no separate
/// "double" recipe path, so the stepper and the presets can never drift out
/// of sync with each other.
struct ScalePanel: View {
    @Binding var servings: Double
    @Binding var batchMode: Bool
    @Binding var unitRaw: String
    /// Whether toggling batch mode would actually add any dilution — false
    /// for built/blended/layered drinks, so the toggle hides itself rather
    /// than offering a control that does nothing.
    let batchEligible: Bool

    private static let presets: [ScalePreset] = [
        ScalePreset(title: "Shot", servings: 0.5),
        ScalePreset(title: "Single", servings: 1),
        ScalePreset(title: "Double", servings: 2),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Servings")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Stepper(value: $servings, in: 0.5...24, step: 0.5) {
                    Text(servingsLabel)
                        .font(.subheadline.monospacedDigit())
                        .frame(minWidth: 32)
                }
                .fixedSize()
            }

            HStack(spacing: 8) {
                ForEach(Self.presets) { preset in
                    PresetButton(title: preset.title, isSelected: servings == preset.servings) {
                        servings = preset.servings
                    }
                }
                Spacer()
                Picker("Unit", selection: $unitRaw) {
                    Text("oz").tag(MeasurementUnit.oz.rawValue)
                    Text("ml").tag(MeasurementUnit.ml.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }

            if batchEligible {
                Toggle("Batch for a pitcher", isOn: $batchMode)
                    .font(.subheadline)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    /// "1", "1.5", "2" — no trailing ".0" for whole servings counts.
    private var servingsLabel: String {
        servings.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(servings))"
            : String(format: "%.1f", servings)
    }
}

/// A servings shortcut shown as a capsule button. A named struct rather than
/// a tuple because Swift key paths can't address tuple elements, so a tuple
/// array can't be fed to `ForEach`.
private struct ScalePreset: Identifiable {
    var id: String { title }
    let title: String
    let servings: Double
}

private struct PresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? Color.accentColor : Color(.tertiarySystemBackground)))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
