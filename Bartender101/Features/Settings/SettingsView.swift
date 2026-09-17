import SwiftUI

/// `UserDefaults` keys shared across views via `@AppStorage`. Centralized
/// here so a rename never silently desyncs two screens reading the same
/// preference under different string literals.
enum SettingsKeys {
    static let measurementUnit = "settings.measurementUnit"
    static let speedDrillSeconds = "settings.speedDrillSeconds"
    static let bartendingMode = "settings.bartendingMode"
}

struct SettingsView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var reviewStore: ReviewStore
    @EnvironmentObject private var shiftLog: ShiftLogStore
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @AppStorage(SettingsKeys.speedDrillSeconds) private var speedDrillSeconds = 5
    @AppStorage(SettingsKeys.bartendingMode) private var barMode = true
    @State private var showResetConfirm = false
    @State private var showClearLogConfirm = false

    private let timerOptions = [3, 5, 8]

    var body: some View {
        Form {
            Section {
                Toggle("Bartending Mode", isOn: $barMode)
            } footer: {
                Text("Big text and big buttons on Search and recipe pages, for reading your phone behind the bar. Also on the Search page's toolbar.")
            }

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

            Section("Speed Drill") {
                Picker("Time per card", selection: $speedDrillSeconds) {
                    ForEach(timerOptions, id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("Reset all progress", role: .destructive) {
                    showResetConfirm = true
                }
            } footer: {
                Text("Clears every card's spaced-repetition history. The drink deck itself is unaffected.")
            }

            Section {
                Button("Clear shift log", role: .destructive) {
                    showClearLogConfirm = true
                }
                .disabled(shiftLog.entries.isEmpty)
            } footer: {
                Text("Deletes every drink logged with Made it, across all nights.")
            }

            Section("About") {
                LabeledContent("Deck version", value: "1.0")
                LabeledContent("Drinks in the deck", value: "\(library.drinks.count)")
                LabeledContent("Cards started", value: "\(reviewStore.states.count)")
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Reset all progress?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset Progress", role: .destructive) {
                reviewStore.resetProgress()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            "Clear shift log?",
            isPresented: $showClearLogConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear \(shiftLog.entries.count) Logged Drinks", role: .destructive) {
                shiftLog.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}
