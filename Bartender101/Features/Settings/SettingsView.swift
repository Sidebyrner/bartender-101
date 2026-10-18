import SwiftUI

/// `UserDefaults` keys shared across views via `@AppStorage`. Centralized
/// here so a rename never silently desyncs two screens reading the same
/// preference under different string literals.
enum SettingsKeys {
    static let measurementUnit = "settings.measurementUnit"
    static let speedDrillSeconds = "settings.speedDrillSeconds"
    static let bartendingMode = "settings.bartendingMode"
    static let buildLayout = "settings.buildLayout"
    static let hasSeenIntro = "settings.hasSeenIntro"
}

struct SettingsView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var reviewStore: ReviewStore
    @EnvironmentObject private var shiftLog: ShiftLogStore
    @EnvironmentObject private var customDrinks: CustomDrinkStore
    @EnvironmentObject private var photoStore: PhotoStore
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @AppStorage(SettingsKeys.speedDrillSeconds) private var speedDrillSeconds = 5
    @AppStorage(SettingsKeys.bartendingMode) private var barMode = true
    @AppStorage(SettingsKeys.hasSeenIntro) private var hasSeenIntro = false
    @State private var showResetConfirm = false
    @State private var showClearLogConfirm = false
    @State private var showDeleteHouseConfirm = false
    @State private var showDeletePhotosConfirm = false

    private let timerOptions = [3, 5, 8]

    /// The pages served from `/docs` via GitHub Pages. The privacy policy is
    /// also the URL in App Store Connect — the two have to agree.
    static let privacyPolicyURL = URL(string: "https://sidebyrner.github.io/bartender-101/privacy.html")!
    static let supportURL = URL(string: "https://sidebyrner.github.io/bartender-101/support.html")!

    var body: some View {
        Form {
            Section {
                Toggle("Bartending Mode", isOn: $barMode)
            } footer: {
                Text("Big text and big buttons on Search and recipe pages, for reading your phone behind the bar. Also on the Search page's toolbar.")
            }

            Section {
                UnitPicker(unitRaw: $unitRaw)
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

            Section {
                Button("Delete all house drinks", role: .destructive) {
                    showDeleteHouseConfirm = true
                }
                .disabled(customDrinks.drinks.isEmpty)
            } footer: {
                Text("Deletes every drink made in Build, with its tasting log. Drinks already in the shift log stay there.")
            }

            Section {
                Button("Delete all photos", role: .destructive) {
                    showDeletePhotosConfirm = true
                }
                .disabled(photoStore.photos.isEmpty)
            } footer: {
                Text("Deletes every drink photo saved in the app. Photos you shared or saved elsewhere aren't affected.")
            }

            Section {
                Button {
                    hasSeenIntro = false
                } label: {
                    Label("Show intro again", systemImage: "sparkles")
                }
            }

            Section("About") {
                LabeledContent("Deck version", value: "1.0")
                LabeledContent("Drinks in the deck", value: "\(library.drinks.count)")
                LabeledContent("House drinks", value: "\(customDrinks.drinks.count)")
                LabeledContent("Drink photos", value: "\(photoStore.photos.count)")
                LabeledContent("Cards started", value: "\(reviewStore.states.count)")
            }

            // App Review guideline 5.1.1(i) wants the privacy policy reachable
            // from inside the app, not just from the store listing.
            Section {
                Link(destination: Self.privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: Self.supportURL) {
                    Label("Support", systemImage: "questionmark.circle")
                }
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    Label("Acknowledgements", systemImage: "text.book.closed")
                }
            } footer: {
                Text("House Pour collects nothing and sends nothing anywhere. Everything you make stays on this device.")
            }
        }
        // Hold the rows to a readable column on iPad, but let the grouped
        // background run the full width — clamping it too leaves a seam down
        // either side of the form.
        .scrollContentBackground(.hidden)
        .readableWidth()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
            "Delete all photos?",
            isPresented: $showDeletePhotosConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete \(photoStore.photos.count) Photos", role: .destructive) {
                photoStore.deleteAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            "Delete all house drinks?",
            isPresented: $showDeleteHouseConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete \(customDrinks.drinks.count) House Drinks", role: .destructive) {
                customDrinks.deleteAll()
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

/// Credits for bundled third-party data, with the license text it requires.
private struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                Text("The builder's pairing ideas, ratio checks, documented riffs, and close matches draw on recipes from Bar Assistant's open recipe data.")
                Link(destination: URL(string: "https://github.com/bar-assistant/data")!) {
                    Label("bar-assistant/data on GitHub", systemImage: "safari")
                }
            } header: {
                Text("Bar Assistant")
            }
            Section("License") {
                Text(Self.mitLicense)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let mitLicense = """
    MIT License

    Copyright (c) 2026 Bar Assistant

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
}
