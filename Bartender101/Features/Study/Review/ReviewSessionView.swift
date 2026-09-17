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
        .readableWidth()
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
                .tint(.accentColor)
                .padding(.horizontal)
                .animation(Theme.spring, value: index)

            Text("\(index + 1) of \(queue.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(index)))

            Spacer(minLength: 0)

            DrinkCardView(drink: drink, isFlipped: $isFlipped, unit: unit)
                .frame(maxWidth: 420)
                .frame(minHeight: 380)
                .padding(.horizontal, 24)
                // Each graded card slides away and the next one deals in.
                .id(drink.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            Spacer(minLength: 0)

            if isFlipped {
                GradeButtons { grade in
                    handleGrade(grade, for: drink)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    isFlipped = true
                } label: {
                    Label("Reveal spec", systemImage: "eye")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.accentGradient(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.pressable)
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: isFlipped)
    }

    private func handleGrade(_ grade: ReviewGrade, for drink: Drink) {
        reviewStore.grade(drinkID: drink.id, grade: grade)
        gradedCount += 1
        if grade == .missed { missedCount += 1 }

        withAnimation(Theme.spring) {
            isFlipped = false
            if index + 1 < queue.count {
                index += 1
            } else {
                sessionComplete = true
            }
        }
    }

    private var summaryView: some View {
        VStack(spacing: 16) {
            Spacer()
            if gradedCount > 0 {
                ProgressRing(progress: Double(gradedCount - missedCount) / Double(gradedCount), lineWidth: 14, tint: .green) {
                    VStack(spacing: 0) {
                        Text("\(gradedCount - missedCount)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("of \(gradedCount) clean")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)
                .padding(.bottom, 8)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: sessionComplete)
            }
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
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280, minHeight: 50)
                    .background(Theme.accentGradient(), in: Capsule())
            }
            .buttonStyle(.pressable)
            .padding(.bottom, 24)
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .sensoryFeedback(.success, trigger: sessionComplete)
    }
}
