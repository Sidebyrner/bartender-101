import SwiftUI

/// The Codex's per-drink page: full spec up top, then the scaling panel that
/// is this app's whole reason for existing — a servings multiplier, format
/// presets, a batch/pitcher dilution toggle, and an oz/ml switch, all
/// updating the same ingredient list live.
struct DrinkDetailView: View {
    let drink: Drink
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @State private var servings: Double = 1
    @State private var batchMode = false

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }

    private var scaled: [RecipeScaler.ScaledIngredient] {
        RecipeScaler.scaledIngredients(for: drink, servings: servings)
    }

    private var batchWaterOz: Double {
        Dilution.batchWaterOz(scaledIngredients: scaled, method: drink.method)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ScalePanel(
                    servings: $servings,
                    batchMode: $batchMode,
                    unitRaw: $unitRaw,
                    batchEligible: Dilution.percent(for: drink.method) > 0
                )

                ingredientList

                Divider()
                specGrid

                if !drink.notes.isEmpty {
                    Divider()
                    Text(drink.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(drink.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(drink.name)
                .font(.system(.title, design: .serif, weight: .bold))
            Text("\(drink.family.displayName) · \(drink.method.displayName.lowercased())")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var ingredientList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(scaled) { ingredient in
                ScaledIngredientRow(ingredient: ingredient, unit: unit)
            }
            if batchMode && batchWaterOz > 0 {
                Label(
                    "Add \(Measure.label(oz: batchWaterOz, unit: unit)) water (dilution, batched)",
                    systemImage: "drop.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
    }

    private var specGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                SpecColumn(label: "Glass", value: drink.glass.displayName)
                SpecColumn(label: "Ice", value: drink.ice.displayName)
            }
            HStack(alignment: .top, spacing: 20) {
                SpecColumn(label: "Method", value: drink.method.displayName)
                SpecColumn(label: "Garnish", value: drink.garnish)
            }
        }
    }
}

private struct ScaledIngredientRow: View {
    let ingredient: RecipeScaler.ScaledIngredient
    let unit: MeasurementUnit

    var body: some View {
        HStack {
            Text(ingredient.name)
                .font(.subheadline)
            if ingredient.isImplicit {
                Text("to taste")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(amountLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var amountLabel: String {
        if ingredient.unit == .topWith { return "Top with" }
        if let amountOz = ingredient.amountOz {
            return Measure.label(oz: amountOz, unit: unit)
        }
        return ingredient.countLabel ?? ""
    }
}

private struct SpecColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .tracking(1)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
