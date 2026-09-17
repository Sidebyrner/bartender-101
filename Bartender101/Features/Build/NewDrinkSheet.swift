import SwiftUI

/// The start of a new drink: three ways in — a family's classic ratio, a
/// riff on any drink in the deck, or a blank canvas. Every path ends in
/// `DrinkBuilderView`, and saving or cancelling there closes the whole sheet.
struct NewDrinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What are you making?")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                        Text("Every house drink starts somewhere. Pick a way in — you can change anything later.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)
                    .modifier(StaggeredAppear(index: 0, appeared: appeared))

                    NavigationLink {
                        FamilyGridView { dismiss() }
                    } label: {
                        PathCard(
                            title: "From a classic ratio",
                            subtitle: "Sour, Old Fashioned, highball and more — the proven proportions, ready to riff on.",
                            systemImage: "square.grid.2x2.fill",
                            tint: .accentColor
                        )
                    }
                    .modifier(StaggeredAppear(index: 1, appeared: appeared))

                    NavigationLink {
                        RiffPickerView { dismiss() }
                    } label: {
                        PathCard(
                            title: "Riff on a drink",
                            subtitle: "Start from any drink you know and make it your own.",
                            systemImage: "arrow.triangle.branch",
                            tint: .purple
                        )
                    }
                    .modifier(StaggeredAppear(index: 2, appeared: appeared))

                    NavigationLink {
                        DrinkBuilderView(drink: DrinkTemplates.blank(), isNew: true) { dismiss() }
                    } label: {
                        PathCard(
                            title: "Blank canvas",
                            subtitle: "Nothing but an idea. Build it ingredient by ingredient.",
                            systemImage: "sparkles",
                            tint: .teal
                        )
                    }
                    .modifier(StaggeredAppear(index: 3, appeared: appeared))
                }
                .buttonStyle(.pressable(scale: 0.97))
                .padding(20)
                .readableWidth()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if reduceMotion { appeared = true } else { withAnimation { appeared = true } }
            }
        }
    }
}

private struct StaggeredAppear: ViewModifier {
    let index: Int
    let appeared: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
            .animation(Theme.spring.delay(Double(index) * 0.06), value: appeared)
    }
}

private struct PathCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            IconTile(systemImage: systemImage, tint: tint, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .cardSurface(cornerRadius: 20, elevated: true)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Every family's classic ratio as a tile.
private struct FamilyGridView: View {
    let onFinish: () -> Void
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(DrinkFamily.allCases) { family in
                    let template = DrinkTemplates.template(for: family)
                    NavigationLink {
                        DrinkBuilderView(drink: template, isNew: true, onFinish: onFinish)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            IconTile(systemImage: family.systemImage, tint: family.tint, size: 40)
                            Text(family.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(ratioSummary(template))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3, reservesSpace: true)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .cardSurface(cornerRadius: 18)
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.pressable(scale: 0.95))
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Classic Ratios")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "2 oz · ¾ oz · ¾ oz" style: each line's pour, in order.
    private func ratioSummary(_ template: CustomDrink) -> String {
        template.ingredients.map { ingredient in
            if ingredient.unit == .oz, let oz = ingredient.amountOz {
                return "\(Measure.ozFraction(oz)) oz \(ingredient.name.lowercased())"
            }
            return "\(ingredient.countLabel?.lowercased() ?? "") \(ingredient.name.lowercased())"
        }
        .joined(separator: " · ")
    }
}

private struct RiffPickerView: View {
    @EnvironmentObject private var library: DrinkLibrary
    let onFinish: () -> Void
    @State private var query = ""

    var body: some View {
        List(library.search(query).sorted { $0.name < $1.name }) { drink in
            NavigationLink {
                DrinkBuilderView(drink: DrinkTemplates.riff(on: drink), isNew: true, onFinish: onFinish)
            } label: {
                HStack(spacing: 12) {
                    IconTile(systemImage: drink.family.systemImage, tint: drink.family.tint, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drink.name)
                            .font(.system(.body, design: .serif, weight: .semibold))
                        Text(drink.ingredientSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Drink or ingredient")
        .navigationTitle("Riff on…")
        .navigationBarTitleDisplayMode(.inline)
    }
}
