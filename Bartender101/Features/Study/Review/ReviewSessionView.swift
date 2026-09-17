import SwiftUI

/// A spaced-repetition study session: work through every currently-due
/// card, flip to check yourself, grade honestly, and the scheduler decides
/// when each one comes back. This is the mode that actually makes the deck
/// stick with the least total study time.
struct ReviewSessionView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var reviewStore: ReviewStore
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [Drink] = []
    @State private var index = 0
    @State private var isFlipped = false
    @State private var missedCount = 0
    @State private var gradedCount = 0
    @State private var sessionComplete = false

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }
    private var currentDrink: Drink? { queue.indices.contains(index) ? queue[index] : nil }

    var body: some View {
        Group {
            if sessionComplete || currentDrink == nil {
                summaryView
            } else if let drink = currentDrink {
                sessionView(for: drink)
            }
        }
        .navigationTitle("Spaced Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if queue.isEmpty {
                queue = reviewStore.dueDrinks(from: library.drinks)
            }
        }
    }

    private func sessionView(for drink: Drink) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: Double(index), total: Double(max(queue.count, 1)))
                .padding(.horizontal)

            Text("\(index + 1) of \(queue.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            DrinkCardView(drink: drink, isFlipped: $isFlipped, unit: unit)
                .frame(maxWidth: 420)
                .frame(minHeight: 380)
                .padding(.horizontal, 24)

            Spacer(minLength: 0)

            if isFlipped {
                GradeButtons { grade in
                    handleGrade(grade, for: drink)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity)
            } else {
                Button {
                    isFlipped = true
                } label: {
                    Text("Reveal spec")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    private func handleGrade(_ grade: ReviewGrade, for drink: Drink) {
        reviewStore.grade(drinkID: drink.id, grade: grade)
        gradedCount += 1
        if grade == .missed { missedCount += 1 }

        isFlipped = false
        if index + 1 < queue.count {
            index += 1
        } else {
            sessionComplete = true
        }
    }

    private var summaryView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            if gradedCount == 0 {
                Text("Nothing due right now")
                    .font(.title2.bold())
                Text("Check back later, or try Speed Drill or Name That Drink.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("Session complete")
                    .font(.title2.bold())
                Text("\(gradedCount) reviewed · \(gradedCount - missedCount) clean · \(missedCount) missed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 24)
        }
    }
}
