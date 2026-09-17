import SwiftUI
import UIKit

/// The Build tab: every house drink on a board with one column per testing
/// stage. Drag a card to another column, or long-press it for Move To (more
/// reliable one-handed behind the bar). Tapping a card opens its recipe
/// page, where it can be made, logged, tasted, and edited. The + button
/// starts a new drink from a family template, a riff on a deck drink, or
/// nothing.
struct BuildBoardView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var customDrinks: CustomDrinkStore
    @EnvironmentObject private var photoStore: PhotoStore
    @State private var showNewDrink = false
    @State private var blockedMove: BlockedMove?
    @State private var targetedStage: TestStage?
    @State private var celebrations = 0
    @State private var moves = 0

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
                        .symbolEffect(.pulse, options: .repeating.speed(0.4))
                } description: {
                    Text("Start from a classic ratio or riff on a drink you know, then test it until it's ready for the menu.")
                } actions: {
                    Button {
                        showNewDrink = true
                    } label: {
                        Label("New Drink", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(minHeight: 48)
                            .background(Theme.accentGradient(), in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }
            } else {
                board
            }
        }
        .overlay { ConfettiBurst(trigger: celebrations) }
        .sensoryFeedback(.success, trigger: celebrations)
        .sensoryFeedback(.impact(weight: .medium), trigger: moves)
        .navigationTitle("Build")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewDrink = true
                } label: {
                    Label("New Drink", systemImage: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
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
                Label {
                    Text(stage.displayName)
                } icon: {
                    Image(systemName: stage.systemImage)
                        .foregroundStyle(stage.tint)
                }
                .font(.headline)
                Spacer()
                Text("\(drinks.count)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(stage.tint)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 26, minHeight: 22)
                    .background(Capsule().fill(stage.tint.opacity(0.15)))
                    .contentTransition(.numericText(value: Double(drinks.count)))
            }
            .padding(.horizontal, 4)

            ScrollView(.vertical) {
                VStack(spacing: 10) {
                    ForEach(drinks) { drink in
                        NavigationLink {
                            DrinkDetailView(drink: drink.asDrink())
                        } label: {
                            BoardCard(drink: drink, coverURL: coverURL(for: drink))
                        }
                        .buttonStyle(.pressable(scale: 0.97))
                        .draggable(drink.id) {
                            BoardCard(drink: drink, coverURL: coverURL(for: drink))
                                .frame(width: 240)
                                .rotationEffect(.degrees(-3))
                        }
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
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
                .fill(targetedStage == stage ? stage.tint.opacity(0.16) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(stage.tint.opacity(targetedStage == stage ? 0.8 : 0), lineWidth: 2)
        )
        .scaleEffect(targetedStage == stage ? 1.01 : 1)
        .animation(Theme.snap, value: targetedStage)
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

    /// The newest photo's thumbnail file for a house drink, if it has one.
    private func coverURL(for drink: CustomDrink) -> URL? {
        photoStore.photos(for: drink.id).first.map(photoStore.thumbnailURL(for:))
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
        guard drink.stage != stage else { return }
        withAnimation(Theme.spring) {
            customDrinks.move(id: id, to: stage)
        }
        moves += 1
        if stage == .onMenu { celebrations += 1 }
    }
}

private struct BoardCard: View {
    let drink: CustomDrink
    /// Passed in rather than read from the environment, because drag
    /// previews render outside the view hierarchy's environment.
    var coverURL: URL?
    @State private var cover: UIImage?

    private var averageRating: Double? {
        let ratings = drink.tastings.compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(drink.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(drink.family.displayName) · \(drink.method.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
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
        .overlay(alignment: .leading) {
            // A stage-colored edge, so a card's column reads at a glance even mid-drag.
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14)
                .fill(drink.stage.tint)
                .frame(width: 4)
        }
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Long-press to move to another stage")
        .task(id: coverURL) {
            guard let coverURL else { cover = nil; return }
            let loaded = await Task.detached(priority: .utility) { UIImage(contentsOfFile: coverURL.path) }.value
            withAnimation(.easeOut(duration: 0.2)) { cover = loaded }
        }
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
