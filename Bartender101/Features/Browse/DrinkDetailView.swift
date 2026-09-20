import SwiftUI

/// A single drink shown as one flippable index card, full screen. Reached
/// from Browse; also where a review session's "reveal" pushes conceptually,
/// though `ReviewSessionView` renders the card inline rather than pushing
/// here so grading buttons can sit right below it.
struct DrinkDetailView: View {
    let drink: Drink
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @State private var isFlipped = false

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }

    var body: some View {
        VStack {
            Spacer()
            DrinkCardView(drink: drink, isFlipped: $isFlipped, unit: unit)
                // 560 rather than 420 so the card fills an iPad detail pane
                // instead of floating in it. On iPhone the horizontal padding
                // below binds first, so this cap never applies there.
                .frame(maxWidth: 560)
                .frame(minHeight: 420)
                .padding(.horizontal, 24)
            Spacer()
        }
        .navigationTitle(drink.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
