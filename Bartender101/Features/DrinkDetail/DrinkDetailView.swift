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
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @AppStorage(SettingsKeys.bartendingMode) private var barMode = true
    @State private var servings: Double = 1
    @State private var batchMode = false
    @State private var showFlashcard = false
    /// The entry just logged, while Undo is still offered.
    @State private var lastLogged: MadeDrink?
    @State private var undoTimeout: Task<Void, Never>?

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }
    private var metrics: BarMetrics { BarMetrics(isOn: barMode) }

    private var staged: [(stage: PourStage, ingredient: RecipeScaler.ScaledIngredient)] {
        PourOrder.ordered(RecipeScaler.scaledIngredients(for: drink, servings: servings), method: drink.method)
    }

    private var rinses: [RecipeScaler.ScaledIngredient] { staged.filter { $0.stage == .glass }.map(\.ingredient) }
    private var pours: [RecipeScaler.ScaledIngredient] { staged.filter { $0.stage != .glass && $0.stage != .finish }.map(\.ingredient) }
    private var finishes: [RecipeScaler.ScaledIngredient] { staged.filter { $0.stage == .finish }.map(\.ingredient) }

    private var batchWaterOz: Double {
        Dilution.batchWaterOz(scaledIngredients: staged.map(\.ingredient), method: drink.method)
    }

    private var hasGarnish: Bool {
        let garnish = drink.garnish.trimmingCharacters(in: .whitespaces).lowercased()
        return !garnish.isEmpty && garnish != "none"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: barMode ? 28 : 20) {
                header
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
                        ForEach(BuildSteps.methodLines(for: drink), id: \.self) { line in
                            StepLine(text: line, systemImage: "arrow.right", metrics: metrics)
                        }
                        if batchMode && batchWaterOz > 0 {
                            StepLine(
                                text: "Batched: add \(Measure.label(oz: batchWaterOz, unit: unit)) water for dilution",
                                systemImage: "drop.fill",
                                metrics: metrics
                            )
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
                        StepLine(text: drink.garnish, systemImage: "leaf.fill", metrics: metrics)
                    }
                }

                if !drink.notes.isEmpty {
                    section("Notes") {
                        Text(drink.notes)
                            .font(barMode ? .title3 : .body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            ScalePanel(
                servings: $servings,
                batchMode: $batchMode,
                unitRaw: $unitRaw,
                batchEligible: Dilution.percent(for: drink.method) > 0,
                metrics: metrics,
                madeTonight: madeTonight,
                justLogged: lastLogged != nil,
                onMadeIt: logMadeDrink,
                onUndo: undoLastLog
            )
            .sensoryFeedback(.success, trigger: shiftLog.entries.count) { old, new in new > old }
        }
        .navigationTitle(drink.name)
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
        }
        .navigationDestination(isPresented: $showFlashcard) {
            FlashcardView(drink: drink)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            undoTimeout?.cancel()
        }
    }

    private var madeTonight: Int {
        shiftLog.tonight()?.entries.filter { $0.drinkID == drink.id }.count ?? 0
    }

    private func logMadeDrink() {
        lastLogged = shiftLog.record(drink: drink, servings: servings, batchMode: batchMode, unit: unit)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(drink.name)
                .font(.system(size: barMode ? 40 : 30, weight: .bold, design: .serif))
            Text("\(drink.family.displayName) · \(drink.method.displayName)")
                .font(barMode ? .title3 : .subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var glassAndIce: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SpecTile(label: "Glass", value: drink.glass.displayName, systemImage: "wineglass", metrics: metrics)
                SpecTile(label: "Ice", value: drink.ice.displayName, systemImage: iceSymbol, metrics: metrics)
            }
            ForEach(rinses) { rinse in
                StepLine(text: "Rinse the glass with \(rinse.name.lowercased()), discard", systemImage: "drop", metrics: metrics)
            }
        }
    }

    private var iceSymbol: String {
        switch drink.ice {
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
                .background(Circle().fill(Color.accentColor))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }

            Text(amount)
                .font(metrics.amountFont)
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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
        .accessibilityElement(children: .combine)
    }
}
