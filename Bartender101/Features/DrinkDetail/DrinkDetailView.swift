import SwiftUI
import UIKit

/// The per-drink recipe page, reached from Search and Stats. It reads top to
/// bottom in the order you make the drink — glass and ice, then each pour in
/// cheapest-first order (`PourOrder`), then the method, the top, and the
/// garnish — so a glance down mid-shift lands on the next thing to do.
///
/// Scaling (Shot/1×/2×/Batch, servings, oz/ml) and "Made it" live in a bar
/// pinned to the bottom of the screen within thumb reach. "Made it" logs the
/// drink to tonight's shift at whatever scale is on screen (`ShiftLogStore`).
/// The toolbar's Flashcard button opens the same drink as a flippable study
/// card. The screen stays awake while this page is open.
struct DrinkDetailView: View {
    let drink: Drink
    @EnvironmentObject private var shiftLog: ShiftLogStore
    @EnvironmentObject private var customDrinks: CustomDrinkStore
    @EnvironmentObject private var photoStore: PhotoStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @AppStorage(SettingsKeys.bartendingMode) private var barMode = true
    @State private var servings: Double = 1
    @State private var batchMode = false
    @State private var showFlashcard = false
    /// The spec open in the builder — a riff on this drink, or this house
    /// drink (or a copy of it) being edited.
    @State private var builderDrink: BuilderTarget?
    @State private var showDeleteConfirm = false
    /// The entry just logged, while Undo is still offered.
    @State private var lastLogged: MadeDrink?
    @State private var undoTimeout: Task<Void, Never>?

    private struct BuilderTarget: Identifiable {
        let drink: CustomDrink
        let isNew: Bool
        var id: String { drink.id }
    }

    /// The house drink behind this page, if it is one. Read live from the
    /// store so edits and stage moves show up without leaving the page.
    private var house: CustomDrink? { customDrinks.drink(id: drink.id) }

    /// What the page renders: the latest house spec, or the deck drink.
    private var spec: Drink { house?.asDrink() ?? drink }

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }
    private var metrics: BarMetrics { BarMetrics(isOn: barMode) }

    private var staged: [(stage: PourStage, ingredient: RecipeScaler.ScaledIngredient)] {
        PourOrder.ordered(RecipeScaler.scaledIngredients(for: spec, servings: servings), method: spec.method)
    }

    private var rinses: [RecipeScaler.ScaledIngredient] { staged.filter { $0.stage == .glass }.map(\.ingredient) }
    private var pours: [RecipeScaler.ScaledIngredient] { staged.filter { $0.stage != .glass && $0.stage != .finish }.map(\.ingredient) }
    private var finishes: [RecipeScaler.ScaledIngredient] { staged.filter { $0.stage == .finish }.map(\.ingredient) }

    private var batchWaterOz: Double {
        Dilution.batchWaterOz(scaledIngredients: staged.map(\.ingredient), method: spec.method)
    }

    private var hasGarnish: Bool {
        let garnish = spec.garnish.trimmingCharacters(in: .whitespaces).lowercased()
        return !garnish.isEmpty && garnish != "none"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: barMode ? 28 : 20) {
                header
                if let house {
                    HouseDrinkPanel(drink: house, metrics: metrics)
                }
                glassAndIce

                section("Pour") {
                    VStack(spacing: 0) {
                        ForEach(Array(pours.enumerated()), id: \.element.id) { index, ingredient in
                            if index > 0 { Divider() }
                            PourRow(step: index + 1, amount: amountLabel(ingredient), name: ingredient.name, metrics: metrics)
                        }
                    }
                }

                section("Method") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(BuildSteps.methodLines(for: spec), id: \.self) { line in
                            StepLine(text: line, systemImage: "arrow.right", metrics: metrics)
                        }
                        if batchMode && batchWaterOz > 0 {
                            StepLine(
                                text: "Batched: add \(Measure.label(oz: batchWaterOz, unit: unit)) water for dilution",
                                systemImage: "drop.fill",
                                metrics: metrics
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }

                if !finishes.isEmpty {
                    section("Top") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(finishes) { ingredient in
                                StepLine(text: finishLine(ingredient), systemImage: "arrow.up.to.line", metrics: metrics)
                            }
                        }
                    }
                }

                if hasGarnish {
                    section("Garnish") {
                        StepLine(text: spec.garnish, systemImage: "leaf.fill", metrics: metrics)
                    }
                }

                if !spec.notes.isEmpty {
                    section("Notes") {
                        Text(spec.notes)
                            .font(barMode ? .title3 : .body)
                            .foregroundStyle(.secondary)
                    }
                }

                // Only once there's something to show — photos are optional.
                if !photoStore.photos(for: spec.id).isEmpty {
                    section("Your Photos") {
                        PhotoStrip(scope: .drink(spec.id), height: barMode ? 150 : 120)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding()
            .readableWidth()
        }
        .safeAreaInset(edge: .bottom) {
            ScalePanel(
                servings: $servings,
                batchMode: $batchMode,
                unitRaw: $unitRaw,
                batchEligible: Dilution.percent(for: spec.method) > 0,
                metrics: metrics,
                madeTonight: madeTonight,
                justLogged: lastLogged != nil,
                onMadeIt: logMadeDrink,
                onUndo: undoLastLog
            )
            .sensoryFeedback(.success, trigger: shiftLog.entries.count) { old, new in new > old }
        }
        .animation(Theme.spring, value: servings)
        .animation(Theme.spring, value: batchMode)
        .navigationTitle(spec.name)
        .navigationBarTitleDisplayMode(.inline)
        // The bottom bar needs the room; Back returns to the tabs.
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFlashcard = true
                } label: {
                    Label("Flashcard", systemImage: "rectangle.on.rectangle.angled")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let house {
                    Menu {
                        Button {
                            builderDrink = BuilderTarget(drink: house, isNew: false)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button {
                            if let copy = customDrinks.duplicate(id: house.id) {
                                builderDrink = BuilderTarget(drink: copy, isNew: false)
                            }
                        } label: {
                            Label("Duplicate as New Version", systemImage: "plus.square.on.square")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Label("House drink", systemImage: "ellipsis.circle")
                    }
                } else {
                    Button {
                        builderDrink = BuilderTarget(drink: DrinkTemplates.riff(on: drink), isNew: true)
                    } label: {
                        Label("Riff on This", systemImage: "arrow.triangle.branch")
                    }
                }
            }
        }
        .sheet(item: $builderDrink) { target in
            NavigationStack {
                DrinkBuilderView(drink: target.drink, isNew: target.isNew) {}
            }
        }
        .confirmationDialog("Delete \(spec.name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete House Drink", role: .destructive) {
                customDrinks.delete(id: drink.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its tasting log goes with it. Drinks already in the shift log stay there.")
        }
        .drinkPhotoButton(for: spec)
        .animation(Theme.spring, value: photoStore.photos(for: spec.id).isEmpty)
        .navigationDestination(isPresented: $showFlashcard) {
            FlashcardView(drink: spec)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            undoTimeout?.cancel()
        }
    }

    private var madeTonight: Int {
        shiftLog.tonight()?.entries.filter { $0.drinkID == spec.id }.count ?? 0
    }

    private func logMadeDrink() {
        lastLogged = shiftLog.record(drink: spec, servings: servings, batchMode: batchMode, unit: unit)
        undoTimeout?.cancel()
        undoTimeout = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            lastLogged = nil
        }
    }

    private func undoLastLog() {
        guard let lastLogged else { return }
        shiftLog.remove(id: lastLogged.id)
        undoTimeout?.cancel()
        self.lastLogged = nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(spec.name)
                .font(.system(size: barMode ? 40 : 32, weight: .bold, design: .serif))
            HStack(spacing: 6) {
                if spec.tags.contains(.house) {
                    Label("House", systemImage: "flask.fill")
                        .font((barMode ? Font.body : .caption).weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                Text("\(spec.family.displayName) · \(spec.method.displayName)")
                    .font(barMode ? .title3 : .subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var glassAndIce: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SpecTile(label: "Glass", value: spec.glass.displayName, systemImage: "wineglass", metrics: metrics)
                SpecTile(label: "Ice", value: spec.ice.displayName, systemImage: iceSymbol, metrics: metrics)
            }
            ForEach(rinses) { rinse in
                StepLine(text: "Rinse the glass with \(rinse.name.lowercased()), discard", systemImage: "drop", metrics: metrics)
            }
        }
    }

    private var iceSymbol: String {
        switch spec.ice {
        case .cubed, .largeCube: return "cube.fill"
        case .crushed: return "snowflake"
        case .none: return "xmark.circle"
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: barMode ? 12 : 8) {
            Text(title.uppercased())
                .font(metrics.sectionLabelFont)
                .tracking(1.5)
                .foregroundStyle(Color.accentColor)
            content()
        }
    }

    private func amountLabel(_ ingredient: RecipeScaler.ScaledIngredient) -> String {
        if let amountOz = ingredient.amountOz, ingredient.unit == .oz {
            return Measure.label(oz: amountOz, unit: unit)
        }
        return ingredient.countLabel ?? ""
    }

    private func finishLine(_ ingredient: RecipeScaler.ScaledIngredient) -> String {
        switch ingredient.unit {
        case .topWith: return "Top with \(ingredient.name.lowercased())"
        case .splash: return "Splash of \(ingredient.name.lowercased())"
        default:
            if let amountOz = ingredient.amountOz {
                return "Top with \(Measure.label(oz: amountOz, unit: unit)) \(ingredient.name.lowercased())"
            }
            return "Top with \(ingredient.name.lowercased())"
        }
    }
}

/// One numbered pour: step number, the amount in big type, then what to pour.
private struct PourRow: View {
    let step: Int
    let amount: String
    let name: String
    let metrics: BarMetrics

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(step)")
                .font(.system(size: metrics.isOn ? 18 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: metrics.isOn ? 32 : 24, height: metrics.isOn ? 32 : 24)
                .background(Circle().fill(Theme.accentGradient()))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }

            Text(amount)
                .font(metrics.amountFont)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: metrics.amountColumnWidth, alignment: .leading)

            Text(name)
                .font(metrics.ingredientFont)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, metrics.isOn ? 12 : 8)
        .accessibilityElement(children: .combine)
    }
}

private struct StepLine: View {
    let text: String
    let systemImage: String
    let metrics: BarMetrics

    var body: some View {
        Label {
            Text(text)
                .font(metrics.stepFont)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .font(metrics.stepFont)
                .foregroundStyle(Color.accentColor)
        }
    }
}

private struct SpecTile: View {
    let label: String
    let value: String
    let systemImage: String
    let metrics: BarMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label.uppercased(), systemImage: systemImage)
                .font(metrics.sectionLabelFont)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(metrics.isOn ? .system(size: 26, weight: .bold) : .title3.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(metrics.isOn ? 16 : 12)
        .cardSurface(cornerRadius: 14)
        .accessibilityElement(children: .combine)
    }
}
