import SwiftUI

/// A single drink shown as one flippable index card, full screen. Reached
/// from the recipe page's Flashcard button, for quizzing yourself on one
/// drink outside a drill. `ReviewSessionView` renders the card inline rather
/// than pushing here so grading buttons can sit right below it.
struct FlashcardView: View {
    let drink: Drink
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @State private var isFlipped = false

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }

    var body: some View {
        VStack {
            Spacer()
            DrinkCardView(drink: drink, isFlipped: $isFlipped, unit: unit)
                .frame(maxWidth: 420)
                .frame(minHeight: 420)
                .padding(.horizontal, 24)
            Spacer()
        }
        .navigationTitle(drink.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
