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
    @State private var wrongCount = 0
    @State private var rightCount = 0
    @State private var pickedID: String?

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
        pickedID = nil
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

        withAnimation(Theme.snap) {
            answeredThisRound = true
            lastWasCorrect = isCorrect
            pickedID = name
        }
        if isCorrect {
            rightCount += 1
            correctCount += 1
            reviewStore.grade(drinkID: drink.id, grade: .gotIt)
        } else {
            wrongCount += 1
            reviewStore.grade(drinkID: drink.id, grade: .missed)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (isCorrect ? 0.9 : 1.4)) {
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
        VStack(spacing: 16) {
            Text("\(round + 1) / \(deck.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(round)))

            specSummary(for: drink)
                .padding(.horizontal)
                .id(drink.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            Spacer(minLength: 8)

            if typeItMode {
                typedAnswerArea(for: drink)
            } else {
                multipleChoiceArea(for: drink)
            }
        }
        .padding(.top, 8)
        .sensoryFeedback(.success, trigger: rightCount)
        .sensoryFeedback(.error, trigger: wrongCount)
    }

    private func specSummary(for drink: Drink) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT'S THIS DRINK?")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(Color.accentColor)
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
        .padding(18)
        .cardSurface(cornerRadius: 20, elevated: true)
    }

    private func multipleChoiceArea(for drink: Drink) -> some View {
        VStack(spacing: 10) {
            ForEach(options) { option in
                let isCorrectOption = option.id == drink.id
                let isPicked = pickedID == option.id
                Button {
                    submit(name: option.id)
                } label: {
                    HStack {
                        Text(option.name)
                            .font(.system(.body, design: .serif, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if answeredThisRound && (isCorrectOption || isPicked) {
                            Image(systemName: isCorrectOption ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(isCorrectOption ? .green : .red)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(choiceColor(option: option, correctDrink: drink))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(answeredThisRound && isCorrectOption ? Color.green : Color.primary.opacity(0.06), lineWidth: answeredThisRound && isCorrectOption ? 2 : 1)
                    )
                    .foregroundStyle(.primary)
                    .shake(trigger: isPicked && !isCorrectOption ? wrongCount : 0)
                }
                .buttonStyle(.pressable(scale: 0.98))
                .disabled(answeredThisRound)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    private func choiceColor(option: Drink, correctDrink: Drink) -> Color {
        guard answeredThisRound else { return Color(.secondarySystemBackground) }
        if option.id == correctDrink.id { return .green.opacity(0.18) }
        if option.id == pickedID { return .red.opacity(0.18) }
        return Color(.secondarySystemBackground).opacity(0.6)
    }

    private func typedAnswerArea(for drink: Drink) -> some View {
        VStack(spacing: 12) {
            TextField("Drink name", text: $typedAnswer)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .disabled(answeredThisRound)
                .onSubmit { submit(name: nil) }
                .shake(trigger: wrongCount)
                .padding(.horizontal)

            if answeredThisRound {
                Label(lastWasCorrect ? "Correct" : "It was \(drink.name)",
                      systemImage: lastWasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(lastWasCorrect ? .green : .red)
                    .symbolEffect(.bounce, value: answeredThisRound)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                Button("Submit") { submit(name: nil) }
                    .buttonStyle(.borderedProminent)
                    .disabled(typedAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.bottom, 24)
    }

    private var summaryView: some View {
        DrillSummary(
            correct: correctCount,
            total: deck.count,
            tint: .purple,
            detail: typeItMode ? "Typed from memory" : nil,
            onDone: { dismiss() },
            onAgain: restart
        )
    }

    private func restart() {
        deck = []
        round = 0
        correctCount = 0
        finished = false
        startIfNeeded()
    }
}
