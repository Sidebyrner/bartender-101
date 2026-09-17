import Combine
import Foundation
import SwiftUI

/// Timed multiple choice: name on screen, four ingredient-list options, a
/// clock running out from the seconds set in Settings. This is the drill
/// that trains the actual skill you asked for — recalling a spec fast
/// enough to keep a ticket moving, not just eventually getting there.
struct SpeedDrillView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var reviewStore: ReviewStore
    @AppStorage(SettingsKeys.speedDrillSeconds) private var totalSeconds = 5
    @Environment(\.dismiss) private var dismiss

    @State private var deck: [Drink] = []
    @State private var options: [Drink] = []
    @State private var round = 0
    @State private var correctCount = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var remaining: Double = 5
    @State private var answeredThisRound = false
    @State private var selectedID: String?
    @State private var finished = false
    @State private var wrongCount = 0
    @State private var rightCount = 0

    private let roundCount = 10
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var currentDrink: Drink? { deck.indices.contains(round) ? deck[round] : nil }

    var body: some View {
        Group {
            if finished || currentDrink == nil {
                summaryView
            } else if let drink = currentDrink {
                roundView(for: drink)
            }
        }
        .navigationTitle("Speed Drill")
        .readableWidth()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: startIfNeeded)
        .onReceive(timer) { _ in tick() }
    }

    private func startIfNeeded() {
        guard deck.isEmpty else { return }
        deck = Array(library.drinks.shuffled().prefix(roundCount))
        remaining = Double(totalSeconds)
        loadOptions()
    }

    private func loadOptions() {
        guard let drink = currentDrink else { return }
        var choices = library.distractors(for: drink, count: 3)
        choices.append(drink)
        options = choices.shuffled()
        remaining = Double(totalSeconds)
        answeredThisRound = false
        selectedID = nil
    }

    private func tick() {
        guard !finished, currentDrink != nil, !answeredThisRound else { return }
        remaining = max(0, remaining - 0.1)
        if remaining <= 0 {
            submit(drinkID: nil)
        }
    }

    private func submit(drinkID: String?) {
        guard !answeredThisRound, let drink = currentDrink else { return }
        answeredThisRound = true
        selectedID = drinkID

        let isCorrect = drinkID == drink.id
        if isCorrect {
            rightCount += 1
            correctCount += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            reviewStore.grade(drinkID: drink.id, grade: .gotIt)
        } else {
            wrongCount += 1
            streak = 0
            reviewStore.grade(drinkID: drink.id, grade: .missed)
        }

        // A miss lingers longer, so the right answer has time to register.
        DispatchQueue.main.asyncAfter(deadline: .now() + (isCorrect ? 0.6 : 1.4)) {
            advance()
        }
    }

    private func advance() {
        withAnimation(Theme.spring) {
            if round + 1 < deck.count {
                round += 1
                loadOptions()
            } else {
                finished = true
            }
        }
    }

    private func roundView(for drink: Drink) -> some View {
        VStack(spacing: 20) {
            HStack {
                Text("\(round + 1) / \(deck.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(round)))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .symbolEffect(.bounce, value: streak)
                    Text("\(streak)")
                        .contentTransition(.numericText(value: Double(streak)))
                }
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(streak > 0 ? .orange : .secondary)
                .animation(Theme.snap, value: streak)
            }
            .padding(.horizontal)

            CountdownBar(remaining: remaining, total: Double(totalSeconds))
                .padding(.horizontal)

            Spacer(minLength: 8)

            Text(drink.name)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .id(drink.id)
                .transition(.push(from: .trailing))

            Text("Which ingredients?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                ForEach(options) { option in
                    optionButton(option, correctDrink: drink)
                }
            }
            .id("options-\(drink.id)")
            .transition(.opacity.combined(with: .offset(y: 12)))
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .sensoryFeedback(.success, trigger: rightCount)
        .sensoryFeedback(.error, trigger: wrongCount)
    }

    @ViewBuilder
    private func optionButton(_ option: Drink, correctDrink: Drink) -> some View {
        let isCorrectOption = option.id == correctDrink.id
        let isSelected = selectedID == option.id

        Button {
            submit(drinkID: option.id)
        } label: {
            HStack(spacing: 10) {
                Text(option.ingredientSummary)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if answeredThisRound && (isCorrectOption || isSelected) {
                    Image(systemName: isCorrectOption ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(isCorrectOption ? .green : .red)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(backgroundColor(isCorrectOption: isCorrectOption, isSelected: isSelected))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(answeredThisRound && isCorrectOption ? Color.green : Color.primary.opacity(0.06), lineWidth: answeredThisRound && isCorrectOption ? 2 : 1)
            )
            .foregroundStyle(.primary)
            .scaleEffect(answeredThisRound && isCorrectOption && isSelected ? 1.02 : 1)
            .shake(trigger: isSelected && !isCorrectOption ? wrongCount : 0)
            .animation(Theme.snap, value: answeredThisRound)
        }
        .disabled(answeredThisRound)
        .buttonStyle(.pressable(scale: 0.98))
    }

    private func backgroundColor(isCorrectOption: Bool, isSelected: Bool) -> Color {
        guard answeredThisRound else { return Color(.secondarySystemBackground) }
        if isCorrectOption { return .green.opacity(0.18) }
        if isSelected { return .red.opacity(0.18) }
        return Color(.secondarySystemBackground).opacity(0.6)
    }

    private var summaryView: some View {
        DrillSummary(
            correct: correctCount,
            total: deck.count,
            tint: .orange,
            detail: bestStreak > 1 ? "Best streak: \(bestStreak) in a row" : nil,
            onDone: { dismiss() },
            onAgain: restart
        )
    }

    private func restart() {
        deck = []
        round = 0
        correctCount = 0
        streak = 0
        bestStreak = 0
        finished = false
        startIfNeeded()
    }
}

/// The shrinking time bar: a smooth fill that warms from amber to red as
/// the clock runs out.
private struct CountdownBar: View {
    let remaining: Double
    let total: Double

    private var fraction: Double { total > 0 ? max(0, min(1, remaining / total)) : 0 }
    private var tint: Color { fraction < 0.3 ? .red : (fraction < 0.6 ? .orange : .accentColor) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.8), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 8)
        .animation(.linear(duration: 0.1), value: remaining)
        .animation(.easeInOut(duration: 0.3), value: tint)
        .accessibilityElement()
        .accessibilityLabel("Time left")
        .accessibilityValue("\(Int(remaining.rounded(.up))) seconds")
    }
}

/// The end-of-round card shared by Speed Drill and Name That Drink: a score
/// ring that fills in, a verdict, and Done / Go Again.
struct DrillSummary: View {
    let correct: Int
    let total: Int
    let tint: Color
    let detail: String?
    let onDone: () -> Void
    let onAgain: () -> Void

    private var fraction: Double { total > 0 ? Double(correct) / Double(total) : 0 }

    private var verdict: String {
        switch fraction {
        case 1: return "Perfect round"
        case 0.8...: return "Sharp work"
        case 0.5...: return "Getting there"
        default: return "Keep drilling"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressRing(progress: fraction, lineWidth: 14, tint: tint) {
                VStack(spacing: 0) {
                    Text("\(correct)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("of \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            VStack(spacing: 6) {
                Text(verdict)
                    .font(.system(.title2, design: .serif, weight: .bold))
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                        .foregroundStyle(.primary)
                }
                Button(action: onAgain) {
                    Label("Go again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(Theme.accentGradient(tint)))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .sensoryFeedback(fraction >= 0.8 ? .success : .impact(weight: .medium), trigger: correct)
    }
}
