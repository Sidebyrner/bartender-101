import SwiftUI

/// `UserDefaults` keys shared across views via `@AppStorage`. Centralized
/// here so a rename never silently desyncs two screens reading the same
/// preference under different string literals.
enum SettingsKeys {
    static let measurementUnit = "settings.measurementUnit"
    static let speedDrillSeconds = "settings.speedDrillSeconds"
}

struct SettingsView: View {
    @EnvironmentObject private var reviewStore: ReviewStore
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @AppStorage(SettingsKeys.speedDrillSeconds) private var speedDrillSeconds = 5
    @State private var showResetConfirm = false

    private let timerOptions = [3, 5, 8]

    var body: some View {
        Form {
            Section("Measurements") {
                Picker("Units", selection: $unitRaw) {
                    ForEach(MeasurementUnit.allCases) { unit in
                        Text(unit == .oz ? "Ounces" : "Milliliters").tag(unit.rawValue)
                    }
                }
                .pickerStyle(.segmented)
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

            Section("About") {
                LabeledContent("Deck version", value: "1.0")
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
    }
}
