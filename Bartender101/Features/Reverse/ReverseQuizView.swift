import Foundation
import SwiftUI

/// The reverse direction: shown a spec with the name hidden, name the
/// drink. This is the recall direction you actually need when a guest
/// describes what they want instead of naming it. Defaults to multiple
/// choice; a "type it" toggle switches to free text with fuzzy matching so
/// small typos still count.
struct ReverseQuizView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var reviewStore: ReviewStore
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @Environment(\.dismiss) private var dismiss

    @State private var deck: [Drink] = []
    @State private var options: [Drink] = []
    @State private var round = 0
    @State private var correctCount = 0
    @State private var typedAnswer = ""
    @State private var typeItMode = false
    @State private var answeredThisRound = false
    @State private var lastWasCorrect = false
    @State private var finished = false

    private let roundCount = 10
    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }
    private var currentDrink: Drink? { deck.indices.contains(round) ? deck[round] : nil }

    var body: some View {
        Group {
            if finished || currentDrink == nil {
                summaryView
            } else if let drink = currentDrink {
                roundView(for: drink)
            }
        }
        .navigationTitle("Name That Drink")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Type it", isOn: $typeItMode)
                    .toggleStyle(.button)
                    .font(.caption)
            }
        }
        .onAppear(perform: startIfNeeded)
    }

    private func startIfNeeded() {
        guard deck.isEmpty else { return }
        deck = Array(library.drinks.shuffled().prefix(roundCount))
        loadOptions()
    }

    private func loadOptions() {
        guard let drink = currentDrink else { return }
        var choices = library.distractors(for: drink, count: 3)
        choices.append(drink)
        options = choices.shuffled()
        answeredThisRound = false
        typedAnswer = ""
    }

    private func submit(name: String?) {
        guard !answeredThisRound, let drink = currentDrink else { return }
        let isCorrect: Bool
        if let name {
            isCorrect = name == drink.id
        } else {
            isCorrect = FuzzyMatch.matches(input: typedAnswer, target: drink.name)
        }

        answeredThisRound = true
        lastWasCorrect = isCorrect
        if isCorrect {
            correctCount += 1
            reviewStore.grade(drinkID: drink.id, grade: .gotIt)
        } else {
            reviewStore.grade(drinkID: drink.id, grade: .missed)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
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
        VStack(spacing: 16) {
            Text("\(round + 1) / \(deck.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            specSummary(for: drink)
                .padding(.horizontal)

            Spacer(minLength: 8)

            if typeItMode {
                typedAnswerArea(for: drink)
            } else {
                multipleChoiceArea(for: drink)
            }
        }
        .padding(.top, 8)
    }

    private func specSummary(for drink: Drink) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(drink.ingredients) { ingredient in
                HStack {
                    Text(ingredient.name)
                    Spacer()
                    if let amountOz = ingredient.amountOz {
                        Text(Measure.label(oz: amountOz, unit: unit))
                            .foregroundStyle(.secondary)
                    } else if let label = ingredient.countLabel {
                        Text(label).foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }
            Divider()
            HStack {
                Text(drink.glass.displayName)
                Text("·")
                Text(drink.method.displayName)
                Text("·")
                Text(drink.garnish)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    private func multipleChoiceArea(for drink: Drink) -> some View {
        VStack(spacing: 10) {
            ForEach(options) { option in
                Button {
                    submit(name: option.id)
                } label: {
                    Text(option.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(choiceColor(option: option, correctDrink: drink))
                        )
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(answeredThisRound)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    private func choiceColor(option: Drink, correctDrink: Drink) -> Color {
        guard answeredThisRound else { return Color(.secondarySystemBackground) }
        if option.id == correctDrink.id { return .green.opacity(0.25) }
        return Color(.secondarySystemBackground)
    }

    private func typedAnswerArea(for drink: Drink) -> some View {
        VStack(spacing: 12) {
            TextField("Drink name", text: $typedAnswer)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .disabled(answeredThisRound)
                .onSubmit { submit(name: nil) }
                .padding(.horizontal)

            if answeredThisRound {
                Label(lastWasCorrect ? "Correct" : "It was \(drink.name)",
                      systemImage: lastWasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(lastWasCorrect ? .green : .red)
            } else {
                Button("Submit") { submit(name: nil) }
                    .buttonStyle(.borderedProminent)
                    .disabled(typedAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.bottom, 24)
    }

    private var summaryView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.uturn.left.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.purple)
            Text("Round complete")
                .font(.title2.bold())
            Text("\(correctCount) / \(deck.count) correct")
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
        finished = false
        startIfNeeded()
    }
}
