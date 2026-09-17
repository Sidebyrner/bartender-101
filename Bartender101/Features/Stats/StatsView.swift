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

            Section("Study") {
                LabeledContent("Cards reviewed") {
                    Text("\(reviewStore.states.count) / \(library.drinks.count)")
                }
                LabeledContent("Total reviews") {
                    Text("\(totalReviews)")
                }
                LabeledContent("Accuracy") {
                    if let accuracy {
                        Text(accuracy, format: .percent.precision(.fractionLength(0)))
                    } else {
                        Text("—")
                    }
                }
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
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                    HStack {
                        Text(family.displayName)
                        Spacer()
                        Text("\(started) / \(drinksInFamily.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Stats")
    }
}
