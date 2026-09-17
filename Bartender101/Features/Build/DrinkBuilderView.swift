import SwiftUI

/// The editor for a house drink — new from a template, a riff, or blank, or
/// an existing one being tweaked. The balance meter stays pinned above the
/// form and updates on every change, so adjusting an amount shows its effect
/// immediately. Saving is always allowed; putting a drink On the Menu needs
/// the same basics the deck validator checks (`CustomDrink.menuProblems`).
struct DrinkBuilderView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var customDrinks: CustomDrinkStore
    @EnvironmentObject private var catalog: IngredientCatalog
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @Environment(\.dismiss) private var dismiss

    /// Called after saving or cancelling, so a sheet several screens deep can
    /// close itself in one step.
    let onFinish: () -> Void

    @State private var draft: CustomDrink
    @State private var rows: [IngredientDraft]
    @State private var newLabel = ""
    @State private var picker: PickerRequest?
    /// The line just swiped away, while Undo is offered.
    @State private var removed: (row: IngredientDraft, position: Int)?
    @State private var undoTimeout: Task<Void, Never>?

    private struct PickerRequest: Identifiable {
        let id = UUID()
        let mode: IngredientPickerMode
    }

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
        DrinkBalance.summary(for: rows.map(\.ingredient), family: draft.family, method: draft.method, category: catalog.category(for:))
    }

    private var menuProblems: [String] {
        guard draft.stage == .onMenu else { return [] }
        var drink = draft
        drink.ingredients = rows.map(\.ingredient)
        return library.menuProblems(for: drink)
    }

    private var duplicateGroups: [[Int]] {
        IngredientChecks.duplicateGroups(in: rows.map(\.ingredient), index: catalog.index)
    }

    /// For a line that repeats an earlier one, the earlier line's position.
    private func firstCopy(of position: Int) -> Int? {
        duplicateGroups.first { $0.contains(position) && $0.first != position }?.first
    }

    private var hasUnnamedRow: Bool {
        rows.contains { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }
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
                // Bindings by element rather than by index, so deleting a
                // row can never leave a view holding a stale position.
                ForEach($rows) { $row in
                    let position = rows.firstIndex { $0.id == row.id } ?? 0
                    IngredientRowEditor(
                        row: $row,
                        category: catalog.category(for: row.name),
                        unit: unit,
                        duplicateOf: firstCopy(of: position),
                        onSwap: { swap(rowID: row.id) },
                        onCombine: { combine(rowID: row.id) }
                    )
                }
                .onDelete(perform: remove)

                Button {
                    picker = PickerRequest(mode: .add)
                } label: {
                    Label("Add ingredient", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(minHeight: 36)
                }
            } header: {
                Text("Ingredients")
            } footer: {
                Text("Tap an ingredient to swap it. Swipe left to delete. Pour order on the recipe page is worked out for you.")
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
        .safeAreaInset(edge: .bottom) {
            if let removed {
                HStack {
                    Text("Removed \(removed.row.name.isEmpty ? "ingredient" : removed.row.name)")
                        .lineLimit(1)
                    Spacer()
                    Button("Undo", action: undoRemove)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $picker) { request in
            IngredientPickerSheet(mode: request.mode, existing: rows.map(\.ingredient), onResult: apply)
        }
        .onDisappear { undoTimeout?.cancel() }
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
                .disabled(!menuProblems.isEmpty || hasUnnamedRow)
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

    private func apply(_ result: IngredientPickerResult) {
        withAnimation(.snappy) {
            switch result {
            case .append(let ingredient):
                rows.append(IngredientDraft(ingredient))
            case .update(let position, let ingredient):
                guard rows.indices.contains(position) else { return }
                rows[position].replace(with: ingredient)
            }
        }
    }

    private func swap(rowID: UUID) {
        guard let position = rows.firstIndex(where: { $0.id == rowID }) else { return }
        picker = PickerRequest(mode: .replace(position: position))
    }

    /// Folds a repeated line into its first copy.
    private func combine(rowID: UUID) {
        guard let position = rows.firstIndex(where: { $0.id == rowID }),
              let first = firstCopy(of: position) else { return }
        let merged = IngredientChecks.combine(rows[first].ingredient, rows[position].ingredient)
        withAnimation(.snappy) {
            rows[first].replace(with: merged)
            rows.remove(at: position)
        }
    }

    private func remove(at offsets: IndexSet) {
        guard let position = offsets.first else { return }
        let row = rows[position]
        withAnimation(.snappy) {
            rows.remove(atOffsets: offsets)
            removed = (row, position)
        }
        undoTimeout?.cancel()
        undoTimeout = Task {
            // Longer than Made it's undo: a delete is easier to do by accident.
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            withAnimation { removed = nil }
        }
    }

    private func undoRemove() {
        guard let removed else { return }
        undoTimeout?.cancel()
        withAnimation(.snappy) {
            rows.insert(removed.row, at: min(removed.position, rows.count))
            self.removed = nil
        }
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

    /// Takes on another ingredient's name and pour, keeping this row's
    /// identity so the list doesn't animate it as a new row.
    mutating func replace(with ingredient: Ingredient) {
        let fresh = IngredientDraft(ingredient)
        name = fresh.name
        amountOz = fresh.amountOz
        unit = fresh.unit
        count = fresh.count
    }
}

private struct IngredientRowEditor: View {
    @Binding var row: IngredientDraft
    let category: IngredientCategory?
    let unit: MeasurementUnit
    /// Position of an earlier line with the same ingredient, if this repeats it.
    let duplicateOf: Int?
    let onSwap: () -> Void
    let onCombine: () -> Void

    private static let ozChips: [Double] = [0.25, 0.5, 0.75, 1, 1.5, 2]
    private static let topChips: [Double] = [1, 2, 3, 4, 5, 6]

    private var placeholderCategory: IngredientCategory? { DrinkTemplates.placeholderCategory(for: row.name) }
    private var isUnnamed: Bool { row.name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var needsChoice: Bool { placeholderCategory != nil || isUnnamed }

    private var issue: IngredientChecks.UnitIssue? {
        IngredientChecks.unitIssue(for: row.ingredient, category: category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            swapButton

            if !needsChoice {
                HStack {
                    Text(amountLabel)
                        .font(.title3.weight(.bold).monospacedDigit())
                    Spacer()
                    Picker("Unit", selection: unitBinding) {
                        ForEach(IngredientUnit.allCases, id: \.self) { Text($0.pickerName).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    if row.unit.expectsAmount {
                        Stepper("Amount", value: $row.amountOz, in: 0.25...32, step: 0.25)
                            .labelsHidden()
                            .fixedSize()
                    } else if row.hasCount {
                        Stepper("Count", value: $row.count, in: 1...30)
                            .labelsHidden()
                            .fixedSize()
                    }
                }

                if row.unit.expectsAmount {
                    // Equal widths, no scrolling, so every chip — including
                    // the selected one — is always on screen.
                    HStack(spacing: 6) {
                        ForEach(row.unit == .oz ? Self.ozChips : Self.topChips, id: \.self) { amount in
                            let selected = abs(row.amountOz - amount) < 0.001
                            Button {
                                row.amountOz = amount
                            } label: {
                                Text(Measure.label(oz: amount, unit: unit))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(Capsule().fill(selected ? Color.accentColor : Color(.tertiarySystemFill)))
                                    .foregroundStyle(selected ? .white : .primary)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Measure.label(oz: amount, unit: unit))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
            }

            if let issue {
                warning(issue.message, actionTitle: issue.fixLabel) {
                    if let fix = issue.fix { row.replace(with: fix) }
                }
            }
            if let duplicateOf {
                warning("Also listed as ingredient \(duplicateOf + 1)", actionTitle: "Combine", action: onCombine)
            }
        }
        .padding(.vertical, 6)
    }

    private var swapButton: some View {
        Button(action: onSwap) {
            HStack(spacing: 12) {
                Image(systemName: (category ?? placeholderCategory)?.systemImage ?? "questionmark")
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(((category ?? placeholderCategory)?.flavorRole.color ?? .gray).opacity(0.2)))
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 2) {
                    if needsChoice {
                        Text(placeholderCategory?.choosePrompt ?? "Choose an ingredient")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        if !isUnnamed {
                            Text("Template: \(row.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(row.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(category?.displayName ?? "Not on the shelf yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: needsChoice ? "chevron.right" : "arrow.left.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(needsChoice ? 10 : 0)
            .background {
                if needsChoice {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(needsChoice ? (placeholderCategory?.choosePrompt ?? "Choose an ingredient") : "\(row.name), \(amountLabel)")
        .accessibilityHint(needsChoice ? "Opens the ingredient picker" : "Swap for a different ingredient")
    }

    private var amountLabel: String {
        if row.unit == .oz { return Measure.label(oz: row.amountOz, unit: unit) }
        if row.unit == .topWith { return "Top with \(Measure.label(oz: row.amountOz, unit: unit))" }
        if row.unit == .splash { return "Splash (\(Measure.label(oz: row.amountOz, unit: unit)))" }
        return row.ingredient.countLabel ?? ""
    }

    /// Switching units starts count units at a sensible count rather than
    /// whatever number was left over from another unit.
    private var unitBinding: Binding<IngredientUnit> {
        Binding(get: { row.unit }, set: { newUnit in
            guard newUnit != row.unit else { return }
            if newUnit == .dash { row.count = 2 } else if newUnit == .muddled { row.count = 4 } else if newUnit == .barspoon { row.count = 1 }
            row.unit = newUnit
        })
    }

    private func warning(_ message: String, actionTitle: String?, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .buttonBorderShape(.capsule)
                    .fixedSize()
            }
        }
    }
}
