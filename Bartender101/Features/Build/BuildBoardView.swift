import SwiftUI

/// The Build tab: every house drink on a board with one column per testing
/// stage. Drag a card to another column, or long-press it for Move To (more
/// reliable one-handed behind the bar). Tapping a card opens its recipe
/// page, where it can be made, logged, tasted, and edited. The + button
/// starts a new drink from a family template, a riff on a deck drink, or
/// nothing.
struct BuildBoardView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var customDrinks: CustomDrinkStore
    @State private var showNewDrink = false
    @State private var blockedMove: BlockedMove?
    @State private var targetedStage: TestStage?

    private struct BlockedMove: Identifiable {
        let id = UUID()
        let name: String
        let problems: [String]
    }

    var body: some View {
        Group {
            if customDrinks.drinks.isEmpty {
                ContentUnavailableView {
                    Label("No house drinks yet", systemImage: "flask")
                } description: {
                    Text("Start from a classic ratio or riff on a drink you know, then test it until it's ready for the menu.")
                } actions: {
                    Button("New Drink") { showNewDrink = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                board
            }
        }
        .navigationTitle("Build")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewDrink = true
                } label: {
                    Label("New Drink", systemImage: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showNewDrink) {
            NewDrinkSheet()
        }
        .alert(item: $blockedMove) { blocked in
            Alert(
                title: Text("\(blocked.name) isn't ready for the menu"),
                message: Text(blocked.problems.joined(separator: "\n")),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var board: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(TestStage.allCases) { stage in
                    column(stage)
                        // Narrower than the screen so the next stage peeks in from the side.
                        .containerRelativeFrame(.horizontal, count: 5, span: 4, spacing: 12)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }

    private func column(_ stage: TestStage) -> some View {
        let drinks = customDrinks.drinks(in: stage)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(stage.displayName, systemImage: stage.systemImage)
                    .font(.headline)
                Spacer()
                Text("\(drinks.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            ScrollView(.vertical) {
                VStack(spacing: 10) {
                    ForEach(drinks) { drink in
                        NavigationLink {
                            DrinkDetailView(drink: drink.asDrink())
                        } label: {
                            BoardCard(drink: drink)
                        }
                        .buttonStyle(.plain)
                        .draggable(drink.id)
                        .contextMenu { cardMenu(drink) }
                    }
                    if drinks.isEmpty {
                        Text("Drop a drink here")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(targetedStage == stage ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
        )
        .dropDestination(for: String.self) { ids, _ in
            for id in ids { attemptMove(id: id, to: stage) }
            return true
        } isTargeted: { isTargeted in
            if isTargeted {
                targetedStage = stage
            } else if targetedStage == stage {
                targetedStage = nil
            }
        }
    }

    @ViewBuilder
    private func cardMenu(_ drink: CustomDrink) -> some View {
        Menu("Move To") {
            ForEach(TestStage.allCases.filter { $0 != drink.stage }) { stage in
                Button {
                    attemptMove(id: drink.id, to: stage)
                } label: {
                    Label(stage.displayName, systemImage: stage.systemImage)
                }
            }
        }
        Button {
            customDrinks.duplicate(id: drink.id)
        } label: {
            Label("Duplicate as New Version", systemImage: "plus.square.on.square")
        }
        Button(role: .destructive) {
            customDrinks.delete(id: drink.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func attemptMove(id: String, to stage: TestStage) {
        guard let drink = customDrinks.drink(id: id) else { return }
        if stage == .onMenu {
            let problems = library.menuProblems(for: drink)
            guard problems.isEmpty else {
                blockedMove = BlockedMove(name: drink.displayName, problems: problems)
                return
            }
        }
        withAnimation(.snappy) {
            customDrinks.move(id: id, to: stage)
        }
    }
}

private struct BoardCard: View {
    let drink: CustomDrink

    private var averageRating: Double? {
        let ratings = drink.tastings.compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(drink.displayName)
                .font(.headline)
                .foregroundStyle(.primary)
            Text("\(drink.family.displayName) · \(drink.method.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !drink.ingredients.isEmpty {
                Text(drink.asDrink().ingredientSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !drink.labels.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(drink.labels, id: \.self) { label in
                        Text(label)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }
            }
            if !drink.tastings.isEmpty {
                HStack(spacing: 8) {
                    Label("\(drink.tastings.count)", systemImage: "text.bubble")
                    if let averageRating {
                        Label(String(format: "%.1f", averageRating), systemImage: "star.fill")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.systemBackground)))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Long-press to move to another stage")
    }
}

/// Where a new drink starts: a family's classic ratio, a copy of any drink in
/// the deck, or an empty spec. Each path ends in `DrinkBuilderView`, and
/// saving or cancelling there closes the whole sheet.
struct NewDrinkSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DrinkFamily.allCases) { family in
                        NavigationLink {
                            DrinkBuilderView(drink: DrinkTemplates.template(for: family), isNew: true) { dismiss() }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(family.displayName)
                                Text(DrinkTemplates.template(for: family).asDrink().ingredientSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text("Start from a classic ratio")
                }

                Section {
                    NavigationLink {
                        RiffPickerView { dismiss() }
                    } label: {
                        Label("Riff on a drink", systemImage: "arrow.triangle.branch")
                    }
                    NavigationLink {
                        DrinkBuilderView(drink: DrinkTemplates.blank(), isNew: true) { dismiss() }
                    } label: {
                        Label("Blank", systemImage: "square.dashed")
                    }
                }
            }
            .navigationTitle("New Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(drink.name)
                    Text(drink.ingredientSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Drink or ingredient")
        .navigationTitle("Riff on…")
        .navigationBarTitleDisplayMode(.inline)
    }
}
