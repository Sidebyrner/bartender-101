import SwiftUI

/// What the builder asked the picker for.
enum IngredientPickerMode: Equatable {
    /// Add a new line.
    case add
    /// Swap the line at `position` for another ingredient.
    case replace(position: Int)
}

/// What the picker hands back to the builder.
enum IngredientPickerResult {
    case append(Ingredient)
    /// Replace the line at `position` with `ingredient` — a swap, or an
    /// existing line with a new pour combined into it.
    case update(position: Int, ingredient: Ingredient)
}

/// The full-screen ingredient chooser. Search is typo-tolerant and knows
/// brand names and shorthand (`IngredientIndex`); an empty search browses
/// recents and every shelf. Nothing changes the drink without a clear step:
/// swapping an ingredient asks Replace or Back, picking one that's already
/// in the drink asks Combine, Add Anyway, or Back, and a name the catalog
/// doesn't know offers close matches before it can be added.
struct IngredientPickerSheet: View {
    let mode: IngredientPickerMode
    /// The drink's current lines, for duplicate and replace checks.
    let existing: [Ingredient]
    let onResult: (IngredientPickerResult) -> Void

    @EnvironmentObject private var catalog: IngredientCatalog
    @AppStorage(SettingsKeys.measurementUnit) private var unitRaw = MeasurementUnit.oz.rawValue
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var category: IngredientCategory?
    @State private var pendingReplace: PendingReplace?
    @State private var pendingDuplicate: PendingDuplicate?
    @State private var newIngredientName: String?
    @FocusState private var searchFocused: Bool

    init(mode: IngredientPickerMode, existing: [Ingredient], onResult: @escaping (IngredientPickerResult) -> Void) {
        self.mode = mode
        self.existing = existing
        self.onResult = onResult
        // A template stand-in ("Base spirit") opens on its shelf.
        if case .replace(let position) = mode, existing.indices.contains(position) {
            _category = State(initialValue: DrinkTemplates.placeholderCategory(for: existing[position].name))
        }
    }

    private struct PendingReplace: Identifiable {
        let id = UUID()
        let position: Int
        let current: Ingredient
        let replacement: Ingredient
    }

    private struct PendingDuplicate: Identifiable {
        let id = UUID()
        let position: Int
        let entry: CatalogIngredient
        let newLine: Ingredient
    }

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .oz }

    private var current: Ingredient? {
        guard case .replace(let position) = mode, existing.indices.contains(position) else { return nil }
        return existing[position]
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var results: [IngredientIndex.Match] { catalog.search(trimmedQuery, category: category) }

    private var hasExactMatch: Bool { results.contains(where: \.isExact) }

    /// Adding a new ingredient is offered only once what's typed isn't just
    /// the start of a known name — "simple" can't become its own ingredient
    /// next to Simple syrup, but "simple syrup, smoked" can.
    private var canAddNew: Bool {
        !results.contains { $0.score < 3 }
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    browseSections
                } else {
                    searchSections
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.immediately)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $newIngredientName) { name in
                NewIngredientCategoryView(name: name, suggested: category ?? IngredientCatalog.guessCategory(name: name, unit: .oz)) { chosen in
                    let entry = catalog.addCustom(name: name, category: chosen)
                    newIngredientName = nil
                    pick(entry)
                }
            }
            .alert(item: $pendingReplace) { pending in
                Alert(
                    title: Text("Replace \(pending.current.name) with \(pending.replacement.name)?"),
                    message: Text(replaceMessage(pending)),
                    primaryButton: .cancel(Text("Back")),
                    secondaryButton: .default(Text("Replace")) {
                        finish(.update(position: pending.position, ingredient: pending.replacement))
                    }
                )
            }
            // An alert rather than a confirmation dialog: an alert always
            // shows its Back button instead of hiding it behind a tap outside.
            .alert(
                pendingDuplicate.map { "\($0.entry.name) is already in this drink" } ?? "",
                isPresented: Binding(get: { pendingDuplicate != nil }, set: { if !$0 { pendingDuplicate = nil } }),
                presenting: pendingDuplicate
            ) { pending in
                let line = existing[pending.position]
                if IngredientChecks.canCombine(line, pending.newLine) {
                    Button("Combine: \(pourLabel(IngredientChecks.combine(line, pending.newLine)))") {
                        finish(.update(position: pending.position, ingredient: IngredientChecks.combine(line, pending.newLine)))
                    }
                }
                Button("Add Anyway") { finish(.append(pending.newLine)) }
                Button("Back", role: .cancel) {}
            } message: { pending in
                Text("It's already in the drink as \(pourLabel(existing[pending.position])).")
            }
        }
        .onAppear { searchFocused = true }
    }

    private var title: String {
        if let current {
            return DrinkTemplates.placeholderCategory(for: current.name) != nil ? "Choose Ingredient" : "Swap \(current.name)"
        }
        return "Add Ingredient"
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search ingredients, brands, or \"OJ\"", text: $query)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit(submitSearch)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.tertiarySystemFill)))
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(title: "All", systemImage: nil, isSelected: category == nil) { category = nil }
                    ForEach(IngredientCategory.allCases) { shelf in
                        CategoryChip(title: shelf.displayName, systemImage: shelf.systemImage, isSelected: category == shelf) {
                            category = (category == shelf) ? nil : shelf
                        }
                    }
                }
                .padding(.horizontal)
            }

            if let current {
                HStack {
                    Text("Replacing")
                        .foregroundStyle(.secondary)
                    Text(current.name).fontWeight(.semibold)
                    Text(pourLabel(current)).foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.subheadline)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Lists

    @ViewBuilder
    private var browseSections: some View {
        if category == nil && !catalog.recents.isEmpty {
            Section("Recent") {
                ForEach(catalog.recents) { entry in row(entry, alias: nil) }
            }
        }
        ForEach(category.map { [$0] } ?? IngredientCategory.allCases) { shelf in
            let entries = catalog.search("", category: shelf)
            if !entries.isEmpty {
                Section {
                    ForEach(entries, id: \.entry.id) { match in row(match.entry, alias: nil) }
                } header: {
                    Label(shelf.displayName, systemImage: shelf.systemImage)
                }
            }
        }
    }

    @ViewBuilder
    private var searchSections: some View {
        let matches = results
        if !matches.isEmpty {
            Section {
                ForEach(matches, id: \.entry.id) { match in row(match.entry, alias: match.matchedAlias) }
            } header: {
                Text(category.map { "In \($0.displayName)" } ?? "Matches")
            }
        }

        if !hasExactMatch {
            let shown = Set(matches.map(\.entry.id))
            let suggestions = catalog.didYouMean(trimmedQuery).filter { !shown.contains($0.id) }
            if !suggestions.isEmpty {
                Section("Did you mean") {
                    ForEach(suggestions) { entry in row(entry, alias: nil) }
                }
            }

            if canAddNew {
                Section {
                    Button {
                        searchFocused = false
                        newIngredientName = trimmedQuery
                    } label: {
                        Label("Add \"\(trimmedQuery)\" as a new ingredient", systemImage: "plus.circle")
                    }
                } footer: {
                    Text(matches.isEmpty
                         ? "Nothing on the shelf matches. Check the spelling, or add it and pick where it belongs."
                         : "None of these? Add it as your own ingredient.")
                }
            } else {
                Section {} footer: {
                    Text("Keep typing to add something that isn't listed.")
                }
            }
        }
    }

    private func row(_ entry: CatalogIngredient, alias: String?) -> some View {
        let alreadyIn = existingPosition(of: entry) != nil
        let usage = catalog.usageCount(for: entry.id)
        return Button {
            pick(entry)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: entry.category.systemImage)
                    .font(.body)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(entry.category.flavorRole.color.opacity(0.2)))
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    let details = [
                        alias.map { "matches \"\($0)\"" },
                        usage > 0 ? "in \(usage) drink\(usage == 1 ? "" : "s")" : nil,
                        entry.id.hasPrefix("user-") ? "your ingredient" : nil,
                        alreadyIn ? "already in this drink" : nil,
                    ].compactMap { $0 }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(alreadyIn ? Color.orange : Color.secondary)
                    }
                }
                Spacer()
                Text(catalog.defaults(for: entry).label(unit: unit))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(mode == .add ? "Adds it to the drink" : "Swaps it in")
    }

    // MARK: - Picking

    private func submitSearch() {
        // Return picks the top result only when it's an exact name or alias,
        // so a half-typed word can't add the wrong thing.
        if let exact = results.first(where: \.isExact) {
            pick(exact.entry)
        }
    }

    private func existingPosition(of entry: CatalogIngredient) -> Int? {
        existing.indices.first { position in
            if case .replace(let replacing) = mode, replacing == position { return false }
            return catalog.index.resolve(existing[position].name)?.id == entry.id
        }
    }

    private func pick(_ entry: CatalogIngredient) {
        catalog.noteUsed(entry)
        let pour = catalog.defaults(for: entry)

        switch mode {
        case .add:
            let newLine = pour.ingredient(named: entry.name)
            if let position = existingPosition(of: entry) {
                pendingDuplicate = PendingDuplicate(position: position, entry: entry, newLine: newLine)
            } else {
                finish(.append(newLine))
            }

        case .replace(let position):
            guard let current else { return dismiss() }
            if catalog.index.resolve(current.name)?.id == entry.id {
                dismiss()
                return
            }
            let replacement = Self.replacement(for: current, with: entry.name, pour: pour)
            let nothingToLose = current.name.trimmingCharacters(in: .whitespaces).isEmpty
                || DrinkTemplates.placeholderCategory(for: current.name) != nil
            if nothingToLose {
                // Filling in a stand-in replaces nothing real — no need to ask.
                finish(.update(position: position, ingredient: replacement))
            } else {
                pendingReplace = PendingReplace(position: position, current: current, replacement: replacement)
            }
        }
    }

    /// The new line for a swap: keeps the current pour when it's measured
    /// the same way the new ingredient usually is, otherwise uses the new
    /// ingredient's usual pour (lime juice → bitters becomes dashes).
    static func replacement(for current: Ingredient, with name: String, pour: IngredientDefault) -> Ingredient {
        guard current.unit == pour.unit else { return pour.ingredient(named: name) }
        return Ingredient(
            name: name,
            amountOz: current.amountOz,
            unit: current.unit,
            dashCount: current.dashCount,
            approxCount: current.approxCount,
            spoonCount: current.spoonCount
        )
    }

    private func replaceMessage(_ pending: PendingReplace) -> String {
        let before = pourLabel(pending.current)
        let after = pourLabel(pending.replacement)
        return before == after ? "Keeps \(after)." : "The pour changes from \(before) to \(after)."
    }

    private func pourLabel(_ ingredient: Ingredient) -> String {
        if ingredient.unit == .oz, let amountOz = ingredient.amountOz {
            return Measure.label(oz: amountOz, unit: unit)
        }
        if ingredient.unit == .topWith, let amountOz = ingredient.amountOz {
            return "top with \(Measure.label(oz: amountOz, unit: unit))"
        }
        return ingredient.countLabel?.lowercased() ?? ""
    }

    private func finish(_ result: IngredientPickerResult) {
        onResult(result)
        dismiss()
    }
}

private struct CategoryChip: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Capsule().fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground)))
            .foregroundStyle(isSelected ? .white : .primary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The last step before adding an ingredient the catalog doesn't know:
/// where does it belong? Its shelf decides its icon, balance role, starting
/// pour, and unit checks. The navigation bar's Back returns to the search.
private struct NewIngredientCategoryView: View {
    let name: String
    let suggested: IngredientCategory
    let onChoose: (IngredientCategory) -> Void

    var body: some View {
        List {
            Section {
                ForEach([suggested] + IngredientCategory.allCases.filter { $0 != suggested }) { shelf in
                    Button {
                        onChoose(shelf)
                    } label: {
                        HStack {
                            Label(shelf.displayName, systemImage: shelf.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            if shelf == suggested {
                                Text("Suggested")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text("Where does \"\(name)\" belong?")
            } footer: {
                Text("It's saved to your ingredients, so it shows up in search next time.")
            }
        }
        .navigationTitle("New Ingredient")
        .navigationBarTitleDisplayMode(.inline)
    }
}
