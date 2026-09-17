import SwiftUI

/// Progress at a glance: tonight's shift and past nights (from "Made it" on
/// recipe pages), then study accuracy, which drinks are still weak, and how
/// coverage breaks down by family.
struct StatsView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var reviewStore: ReviewStore
    @EnvironmentObject private var shiftLog: ShiftLogStore

    private var totalReviews: Int {
        reviewStore.states.values.reduce(0) { $0 + $1.totalReviews }
    }

    private var totalLapses: Int {
        reviewStore.states.values.reduce(0) { $0 + $1.lapses }
    }

    private var accuracy: Double? {
        guard totalReviews > 0 else { return nil }
        return Double(totalReviews - totalLapses) / Double(totalReviews)
    }

    private var weakDrinks: [Drink] {
        reviewStore.weakDrinks(from: library.drinks)
    }

    var body: some View {
        List {
            Section {
                overview
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                if let tonight = shiftLog.tonight() {
                    NavigationLink {
                        NightDetailView(date: tonight.date)
                    } label: {
                        NightSummaryRow(night: tonight, title: "Tonight")
                    }
                } else {
                    Text("Nothing logged tonight. Tap **Made it** on a recipe page after you make a drink.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !shiftLog.entries.isEmpty {
                    NavigationLink("Shift history") {
                        ShiftHistoryView()
                    }
                }
            } header: {
                Text("Behind the bar")
            }


            if !weakDrinks.isEmpty {
                Section("Needs work") {
                    ForEach(weakDrinks) { drink in
                        NavigationLink {
                            DrinkDetailView(drink: drink)
                        } label: {
                            HStack {
                                Text(drink.name)
                                Spacer()
                                if let state = reviewStore.states[drink.id] {
                                    Text("\(state.lapses) missed")
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.red.opacity(0.14)))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
            }

            Section("By family") {
                ForEach(DrinkFamily.allCases) { family in
                    let drinksInFamily = library.drinks(in: family)
                    let started = drinksInFamily.filter { reviewStore.states[$0.id] != nil }.count
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(family.displayName)
                            Spacer()
                            Text("\(started) / \(drinksInFamily.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        CoverageBar(fraction: drinksInFamily.isEmpty ? 0 : Double(started) / Double(drinksInFamily.count))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Stats")
    }

    /// Headline numbers: study accuracy as a ring, then coverage, reviews,
    /// and tonight's count.
    private var overview: some View {
        HStack(spacing: 18) {
            ProgressRing(progress: accuracy ?? 0, lineWidth: 12, tint: .green) {
                VStack(spacing: 0) {
                    if let accuracy {
                        Text(accuracy, format: .percent.precision(.fractionLength(0)))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    } else {
                        Text("—")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    Text("accuracy")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 10) {
                OverviewStat(value: reviewStore.states.count, label: "of \(library.drinks.count) cards started")
                HStack(spacing: 18) {
                    OverviewStat(value: totalReviews, label: "reviews")
                    OverviewStat(value: shiftLog.tonight()?.drinkCount ?? 0, label: "made tonight")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .cardSurface(cornerRadius: 22, elevated: true)
        // Room for the card's shadow, which the list row would otherwise clip.
        .padding(.vertical, 14)
    }
}

private struct OverviewStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// A slim bar that grows in to show how much of a family has been studied.
private struct CoverageBar: View {
    let fraction: Double
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(Theme.accentGradient())
                    .frame(width: max(fraction > 0 ? 6 : 0, proxy.size.width * shown))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion { shown = fraction } else {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.9).delay(0.1)) { shown = fraction }
            }
        }
        .onChange(of: fraction) { withAnimation(Theme.spring) { shown = fraction } }
    }
}
