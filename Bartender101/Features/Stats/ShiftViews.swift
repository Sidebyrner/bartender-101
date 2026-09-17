import SwiftUI

/// Every night with at least one drink logged via "Made it", newest first,
/// plus the drinks made most across all of them.
struct ShiftHistoryView: View {
    @EnvironmentObject private var shiftLog: ShiftLogStore

    var body: some View {
        List {
            Section("Nights") {
                ForEach(shiftLog.nights) { night in
                    NavigationLink {
                        NightDetailView(date: night.date)
                    } label: {
                        NightSummaryRow(night: night, title: night.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    }
                }
            }

            Section("Most made, all nights") {
                ForEach(ShiftLog.tally(shiftLog.entries).prefix(10)) { tally in
                    TallyRow(tally: tally)
                }
            }
        }
        .navigationTitle("Shift History")
    }
}

/// One night: totals, what was made most, and every logged drink with the
/// scale it was made at. Swipe a drink to delete a mis-tap.
struct NightDetailView: View {
    /// The night's shift day. Looked up live from the store rather than
    /// passed as a snapshot, so deletes show up immediately.
    let date: Date
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var shiftLog: ShiftLogStore
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue

    private var night: ShiftLog.Night? { shiftLog.nights.first { $0.date == date } }
    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }

    var body: some View {
        List {
            if let night {
                Section("Totals") {
                    LabeledContent("Drinks logged", value: "\(night.drinkCount)")
                    LabeledContent("Servings", value: Measure.ozFraction(night.totalServings))
                    LabeledContent("Volume poured", value: Measure.label(oz: night.totalOz, unit: unit))
                }

                Section("By drink") {
                    ForEach(night.tally) { tally in
                        TallyRow(tally: tally)
                    }
                }

                Section {
                    ForEach(night.entries) { entry in
                        entryRow(entry)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            shiftLog.remove(id: night.entries[index].id)
                        }
                    }
                } header: {
                    Text("Every drink")
                } footer: {
                    Text("Swipe left to delete a drink logged by mistake.")
                }
            } else {
                ContentUnavailableView("No drinks logged", systemImage: "wineglass")
            }
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
    }

    @ViewBuilder
    private func entryRow(_ entry: MadeDrink) -> some View {
        let row = HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.drinkName).font(.headline)
                Text(scaleDescription(entry))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.madeAt.formatted(date: .omitted, time: .shortened))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        if let drink = library.drink(id: entry.drinkID) {
            NavigationLink { DrinkDetailView(drink: drink) } label: { row }
        } else {
            row
        }
    }

    /// "×2 · batch · 6 oz" — the scale settings as they were when logged,
    /// with the volume in the unit that was on screen at the time.
    private func scaleDescription(_ entry: MadeDrink) -> String {
        var parts = ["×\(Measure.ozFraction(entry.servings))"]
        if entry.batchMode { parts.append("batch") }
        if entry.totalOz > 0 { parts.append(Measure.label(oz: entry.totalOz, unit: entry.unit)) }
        return parts.joined(separator: " · ")
    }
}

/// A night's headline numbers, for the Stats tab and the history list.
struct NightSummaryRow: View {
    let night: ShiftLog.Night
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("\(night.drinkCount) drink\(night.drinkCount == 1 ? "" : "s")")
                    .font(.headline.monospacedDigit())
            }
            if let top = night.tally.first {
                Text("Most made: \(top.drinkName) ×\(top.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct TallyRow: View {
    let tally: ShiftLog.Tally

    var body: some View {
        HStack {
            Text(tally.drinkName)
            Spacer()
            Text("×\(tally.count)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
