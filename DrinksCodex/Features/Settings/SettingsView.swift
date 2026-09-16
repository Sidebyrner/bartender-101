import SwiftUI

/// `UserDefaults` keys for this app's `@AppStorage` values. A separate copy
/// from Bartender101's own `SettingsKeys` — the two apps have separate
/// containers on device, so there's nothing to share here beyond the key
/// string itself.
enum SettingsKeys {
    static let measurementUnit = "settings.measurementUnit"
}

struct SettingsView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Units", selection: $unitRaw) {
                    ForEach(MeasurementUnit.allCases) { unit in
                        Text(unit == .oz ? "Ounces" : "Milliliters").tag(unit.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Measurements")
            } footer: {
                Text("Applies everywhere a drink's amounts are shown, scaled or not.")
            }

            Section("About") {
                LabeledContent("Drinks in the deck", value: "\(library.drinks.count)")
            }
        }
        .navigationTitle("Settings")
    }
}
