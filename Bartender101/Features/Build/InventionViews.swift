import SwiftUI

/// "Often paired with" chips for the builder. Tapping one adds it at the
/// catalog's usual pour.
struct PairingChipsRow: View {
    let suggestions: [InventionHelpers.Suggestion]
    let onAdd: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onAdd(suggestion.name)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                            Text(suggestion.name)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .foregroundStyle(Color.accentColor)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.pressable(scale: 0.94))
                    .accessibilityLabel("Add \(suggestion.name)")
                    .accessibilityHint(suggestion.reason)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// One line under the balance bar comparing the drink's proportions with
/// its family.
struct RatioCheckView: View {
    let check: InventionHelpers.RatioCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if check.notes.isEmpty {
                Label("Proportions in line with \(check.drinksCompared) \(familyPlural)", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(check.notes.prefix(2), id: \.self) { note in
                    Label(text(for: note), systemImage: "chart.bar.xaxis")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }

    private var familyPlural: String {
        switch check.family {
        case .misc: return "similar drinks"
        case .spritz: return "spritzes"
        case .tiki: return "tiki drinks"
        case .muddled: return "muddled drinks"
        case .cream: return "cream drinks"
        default: return check.family.displayName.lowercased() + "s"
        }
    }

    /// e.g. "Sour 35% — typical sours run 15–23%".
    private func text(for note: InventionHelpers.RatioCheck.Note) -> String {
        let pct = { (x: Double) in Int((x * 100).rounded()) }
        let range = "\(pct(note.typical.lowerBound))–\(pct(note.typical.upperBound))%"
        return "\(note.role.displayName) \(pct(note.share))% — typical \(familyPlural) run \(range)"
    }
}

/// A read-only spec for a close match or a documented riff. When
/// `onFinish` is set (the New Drink flow), it offers to start a new house
/// drink from this spec.
struct ReferenceDrinkView: View {
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    let drink: Drink
    let reference: ReferenceDrink?
    var onFinish: (() -> Void)?

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(drink.name)
                        .font(.system(.title2, design: .serif, weight: .bold))
                    Text([drink.family.displayName, drink.method.displayName, drink.glass.displayName]
                        .joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let abv = reference?.abv {
                        Text("About \(Int(abv.rounded()))% ABV")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Spec") {
                ForEach(drink.ingredients, id: \.self) { ingredient in
                    HStack(alignment: .firstTextBaseline) {
                        Text(amount(ingredient))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .frame(minWidth: 64, alignment: .leading)
                        Text(ingredient.name)
                    }
                }
                if !drink.garnish.isEmpty, drink.garnish != "None" {
                    LabeledContent("Garnish", value: drink.garnish)
                }
            }

            if let reference, !reference.tags.isEmpty {
                Section("Tags") {
                    Text(reference.tags.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                }
            }

            if let onFinish {
                Section {
                    NavigationLink {
                        DrinkBuilderView(drink: riffSpec, isNew: true, onFinish: onFinish)
                    } label: {
                        Label("Start a house drink from this", systemImage: "arrow.triangle.branch")
                            .font(.headline)
                    }
                }
            }

            if let reference {
                Section {
                    if let source = reference.source.flatMap(URL.init(string:)) {
                        Link(destination: source) {
                            Label("Original recipe", systemImage: "safari")
                        }
                    }
                } footer: {
                    Text("Recipe from Bar Assistant's open data (MIT). Amounts converted to the nearest ⅛ oz.")
                }
            }
        }
        .navigationTitle(drink.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var riffSpec: CustomDrink {
        reference.map(DrinkTemplates.riff(on:)) ?? DrinkTemplates.riff(on: drink)
    }

    private func amount(_ ingredient: Ingredient) -> String {
        switch ingredient.unit {
        case .oz: return ingredient.amountOz.map { Measure.label(oz: $0, unit: unit) } ?? ""
        case .topWith: return "Top"
        default: return ingredient.countLabel ?? ""
        }
    }
}
