import SwiftUI

/// The editor for a house drink — new from a template, a riff, or blank, or
/// an existing one being tweaked. The balance meter stays pinned above the
/// form and updates on every change, so adjusting an amount shows its effect
/// immediately. Saving is always allowed; putting a drink On the Menu needs
/// the same basics the deck validator checks (`CustomDrink.menuProblems`).
struct DrinkBuilderView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var customDrinks: CustomDrinkStore
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @Environment(\.dismiss) private var dismiss

    /// Called after saving or cancelling, so a sheet several screens deep can
    /// close itself in one step.
    let onFinish: () -> Void

    @State private var draft: CustomDrink
    @State private var rows: [IngredientDraft]
    @State private var newLabel = ""
    @FocusState private var focusedRow: UUID?

    private let isNew: Bool

    init(drink: CustomDrink, isNew: Bool, onFinish: @escaping () -> Void) {
        _draft = State(initialValue: drink)
        _rows = State(initialValue: drink.ingredients.map(IngredientDraft.init))
        self.isNew = isNew
        self.onFinish = onFinish
    }

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }

    private var assembled: CustomDrink {
        var drink = draft
        drink.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        drink.ingredients = rows
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(\.ingredient)
        return drink
    }

    private var summary: DrinkBalance.Summary {
        DrinkBalance.summary(for: rows.map(\.ingredient), family: draft.family, method: draft.method)
    }

    private var menuProblems: [String] {
        guard draft.stage == .onMenu else { return [] }
        var drink = draft
        drink.ingredients = rows.map(\.ingredient)
        return library.menuProblems(for: drink)
    }

    var body: some View {
        Form {
            Section {
                TextField("Drink name", text: $draft.name)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.words)
                if let basedOn = draft.basedOnDrinkID.flatMap(library.drink(id:)) {
                    Label("Riff on the \(basedOn.name)", systemImage: "arrow.triangle.branch")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Build") {
                Picker("Family", selection: $draft.family) {
                    ForEach(DrinkFamily.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Method", selection: $draft.method) {
                    ForEach(DrinkMethod.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Glass", selection: $draft.glass) {
                    ForEach(GlassType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Ice", selection: $draft.ice) {
                    ForEach(IceType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

            Section {
                ForEach($rows) { $row in
                    IngredientRowEditor(
                        row: $row,
                        unit: unit,
                        suggestions: suggestions(for: row),
                        focusedRow: $focusedRow
                    )
                }
                .onDelete { rows.remove(atOffsets: $0) }

                Button {
                    let row = IngredientDraft()
                    rows.append(row)
                    focusedRow = row.id
                } label: {
                    Label("Add ingredient", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Ingredients")
            } footer: {
                Text("Swipe to delete. Pour order on the recipe page is worked out for you.")
            }

            Section("Finish") {
                TextField("Garnish", text: $draft.garnish)
                TextField("Notes — what you're going for", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                if !draft.labels.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(draft.labels, id: \.self) { label in
                            Button {
                                draft.labels.removeAll { $0 == label }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(label)
                                    Image(systemName: "xmark").font(.caption2.weight(.bold))
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove label \(label)")
                        }
                    }
                    .padding(.vertical, 4)
                }
                HStack {
                    TextField("Add a label, e.g. summer menu", text: $newLabel)
                        .onSubmit(addLabel)
                        .submitLabel(.done)
                    Button("Add", action: addLabel)
                        .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Labels")
            }

            Section {
                Picker("Stage", selection: $draft.stage) {
                    ForEach(TestStage.allCases) { stage in
                        Label(stage.displayName, systemImage: stage.systemImage).tag(stage)
                    }
                }
            } footer: {
                if menuProblems.isEmpty {
                    Text("Drinks On the Menu show up in Search, Study, and Stats with the rest of the deck.")
                } else {
                    Text("Before it goes on the menu: " + menuProblems.joined(separator: " · "))
                        .foregroundStyle(.red)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BalanceMeterView(summary: summary, unit: unit)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isNew ? "New Drink" : "Edit Drink")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { finish() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    customDrinks.save(assembled)
                    finish()
                }
                .fontWeight(.semibold)
                .disabled(!menuProblems.isEmpty)
            }
        }
    }

    private func finish() {
        onFinish()
        dismiss()
    }

    private func addLabel() {
        let label = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        if !draft.labels.contains(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) {
            draft.labels.append(label)
        }
        newLabel = ""
    }

    /// Up to four known ingredient names matching what's typed in the row
    /// that has focus.
    private func suggestions(for row: IngredientDraft) -> [String] {
        guard focusedRow == row.id else { return [] }
        let query = row.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard query.count >= 2 else { return [] }
        return Array(
            library.ingredientNames
                .filter { $0.lowercased().contains(query) && $0.lowercased() != query }
                .sorted { $0.lowercased().hasPrefix(query) && !$1.lowercased().hasPrefix(query) }
                .prefix(4)
        )
    }
}

extension DrinkLibrary {
    /// What stops `drink` from going on the menu, checking its name against
    /// the deck and every other house drink.
    func menuProblems(for drink: CustomDrink) -> [String] {
        drink.menuProblems(nameTaken: isNameTaken(drink.name, excluding: drink.id))
    }
}

/// One editable ingredient line. `Ingredient` is immutable and spreads its
/// count across three optional fields; this keeps one amount and one count
/// and maps back by unit.
struct IngredientDraft: Identifiable, Hashable {
    let id = UUID()
    var name: String = ""
    var amountOz: Double = 1
    var unit: IngredientUnit = .oz
    var count: Int = 1

    init() {}

    init(_ ingredient: Ingredient) {
        name = ingredient.name
        unit = ingredient.unit
        amountOz = ingredient.amountOz ?? 1
        count = ingredient.dashCount ?? ingredient.approxCount ?? ingredient.spoonCount ?? 1
    }

    var ingredient: Ingredient {
        Ingredient(
            name: name.trimmingCharacters(in: .whitespaces),
            amountOz: unit.expectsAmount ? amountOz : nil,
            unit: unit,
            dashCount: unit == .dash ? count : nil,
            approxCount: unit == .muddled ? count : nil,
            spoonCount: unit == .barspoon ? count : nil
        )
    }

    var hasCount: Bool { unit == .dash || unit == .muddled || unit == .barspoon }
}

extension IngredientUnit {
    var pickerName: String {
        switch self {
        case .oz: return "oz"
        case .topWith: return "Top with"
        case .dash: return "Dashes"
        case .barspoon: return "Barspoons"
        case .rinse: return "Rinse"
        case .splash: return "Splash"
        case .muddled: return "Muddled"
        case .pinch: return "Pinch"
        case .optional: return "Optional"
        }
    }
}

private struct IngredientRowEditor: View {
    @Binding var row: IngredientDraft
    let unit: MeasurementUnit
    let suggestions: [String]
    var focusedRow: FocusState<UUID?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Ingredient", text: $row.name)
                    .focused(focusedRow, equals: row.id)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                Picker("Unit", selection: $row.unit) {
                    ForEach(IngredientUnit.allCases, id: \.self) { Text($0.pickerName).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                row.name = suggestion
                                focusedRow.wrappedValue = nil
                            }
                            .font(.caption.weight(.medium))
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        }
                    }
                }
            }

            if row.unit.expectsAmount {
                Stepper(value: $row.amountOz, in: 0.25...32, step: 0.25) {
                    Text(Measure.label(oz: row.amountOz, unit: unit))
                        .font(.title3.weight(.bold).monospacedDigit())
                }
            } else if row.hasCount {
                Stepper(value: $row.count, in: 1...30) {
                    Text(row.ingredient.countLabel ?? "")
                        .font(.title3.weight(.bold).monospacedDigit())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
