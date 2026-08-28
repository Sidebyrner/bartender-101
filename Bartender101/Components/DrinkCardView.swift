import SwiftUI

/// The index card. Front shows just the name and family — enough to test
/// yourself before peeking. Tap (or the chevron) flips it to the full spec.
/// This one view is reused by Browse, Review, and as the "answer reveal" in
/// both quiz modes, so any spec formatting change only happens here.
struct DrinkCardView: View {
    let drink: Drink
    @Binding var isFlipped: Bool
    var unit: MeasurementUnit = .oz

    var body: some View {
        ZStack {
            cardFace(showBack: false)
                .opacity(isFlipped ? 0 : 1)
            cardFace(showBack: true)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.easeInOut(duration: 0.35), value: isFlipped)
        .onTapGesture { isFlipped.toggle() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isFlipped ? "\(drink.name), spec shown. Tap to flip back." : "\(drink.name), tap to reveal spec.")
    }

    @ViewBuilder
    private func cardFace(showBack: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .overlay {
                if showBack {
                    backContent.padding(20)
                } else {
                    frontContent.padding(20)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private var frontContent: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(drink.name)
                .font(.system(.title, design: .serif, weight: .bold))
                .multilineTextAlignment(.center)
            Text(drink.family.displayName.uppercased())
                .font(.caption)
                .tracking(1.5)
                .foregroundStyle(.secondary)
            Spacer()
            Label("Tap to reveal", systemImage: "hand.tap.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var backContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(drink.name)
                    .font(.system(.title2, design: .serif, weight: .bold))
                Text("\(drink.family.displayName) · \(drink.method.displayName.lowercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(drink.ingredients) { ingredient in
                    IngredientRow(ingredient: ingredient, unit: unit)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 20) {
                SpecColumn(label: "Glass", value: drink.glass.displayName)
                SpecColumn(label: "Ice", value: drink.ice.displayName)
            }
            HStack(alignment: .top, spacing: 20) {
                SpecColumn(label: "Method", value: drink.method.displayName)
                SpecColumn(label: "Garnish", value: drink.garnish)
            }

            if !drink.notes.isEmpty {
                Divider()
                Text(drink.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IngredientRow: View {
    let ingredient: Ingredient
    let unit: MeasurementUnit

    var body: some View {
        HStack {
            Text(ingredient.name)
                .font(.subheadline)
            Spacer()
            Text(amountLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var amountLabel: String {
        if let amountOz = ingredient.amountOz {
            let base = Measure.label(oz: amountOz, unit: unit)
            if ingredient.unit == .topWith { return "Top with" }
            return base
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
