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
            correctCount += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            reviewStore.grade(drinkID: drink.id, grade: .gotIt)
        } else {
            streak = 0
            reviewStore.grade(drinkID: drink.id, grade: .missed)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            advance()
        }
    }

    private func advance() {
        if round + 1 < deck.count {
            round += 1
            loadOptions()
        } else {
            finished = true
        }
    }

    private func roundView(for drink: Drink) -> some View {
        VStack(spacing: 20) {
            HStack {
                Text("\(round + 1) / \(deck.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(streak)", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal)

            ProgressView(value: remaining, total: Double(totalSeconds))
                .tint(remaining < 1.5 ? .red : .accentColor)
                .padding(.horizontal)

            Spacer(minLength: 8)

            Text(drink.name)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Which ingredients?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                ForEach(options) { option in
                    optionButton(option, correctDrink: drink)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func optionButton(_ option: Drink, correctDrink: Drink) -> some View {
        let isCorrectOption = option.id == correctDrink.id
        let isSelected = selectedID == option.id

        Button {
            submit(drinkID: option.id)
        } label: {
            Text(option.ingredientSummary)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(backgroundColor(isCorrectOption: isCorrectOption, isSelected: isSelected))
                )
                .foregroundStyle(.primary)
        }
        .disabled(answeredThisRound)
        .buttonStyle(.plain)
    }

    private func backgroundColor(isCorrectOption: Bool, isSelected: Bool) -> Color {
        guard answeredThisRound else { return Color(.secondarySystemBackground) }
        if isCorrectOption { return .green.opacity(0.25) }
        if isSelected { return .red.opacity(0.25) }
        return Color(.secondarySystemBackground)
    }

    private var summaryView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Round complete")
                .font(.title2.bold())
            Text("\(correctCount) / \(deck.count) correct · best streak \(bestStreak)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 12) {
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Go again") { restart() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 24)
        }
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
