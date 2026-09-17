import SwiftUI

/// The full deck, searchable and filterable by family and tag. Built for
/// looking a drink up fast mid-shift: the search field is always on screen
/// (not tucked under the title), and tapping a result goes straight to the
/// recipe page. The toolbar's Bar Mode button switches Search and the recipe
/// page between big, arm's-length text and the regular compact layout.
struct SearchView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @AppStorage(SettingsKeys.bartendingMode) private var barMode = true
    @State private var query = ""
    @State private var selectedFamily: DrinkFamily?
    @State private var selectedTags: Set<DrinkTag> = []
    @FocusState private var searchFocused: Bool

    private var metrics: BarMetrics { BarMetrics(isOn: barMode) }

    private var filtered: [Drink] {
        var results = library.search(query)
        if let selectedFamily {
            results = results.filter { $0.family == selectedFamily }
        }
        if !selectedTags.isEmpty {
            results = results.filter { !Set($0.tags).isDisjoint(with: selectedTags) }
        }
        return results.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            filterBar

            List(filtered) { drink in
                NavigationLink {
                    DrinkDetailView(drink: drink)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(drink.name)
                                .font(.system(barMode ? .title2 : .headline, design: .serif, weight: .bold))
                            if drink.tags.contains(.house) {
                                Image(systemName: "flask.fill")
                                    .font(barMode ? .body : .caption)
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityLabel("House drink")
                            }
                        }
                        Text(drink.ingredientSummary)
                            .font(barMode ? .body : .caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(barMode ? 2 : 1)
                    }
                    .padding(.vertical, barMode ? 8 : 0)
                }
            }
            .listStyle(.plain)
            .animation(Theme.spring, value: filtered.map(\.id))
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .dynamicTypeSize(metrics.dynamicTypeRange)
        .sensoryFeedback(.selection, trigger: selectedFamily)
        .sensoryFeedback(.selection, trigger: selectedTags)
        .sensoryFeedback(.impact(weight: .light), trigger: barMode)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(barMode ? .inline : .large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(Theme.spring) { barMode.toggle() }
                } label: {
                    // An HStack rather than a Label: toolbar buttons render a
                    // Label icon-only, and "Bar Mode" needs to be readable.
                    HStack(spacing: 6) {
                        Image(systemName: barMode ? "wineglass.fill" : "wineglass")
                            .contentTransition(.symbolEffect(.replace))
                        Text("Bar Mode")
                    }
                    .font(.headline)
                    .foregroundStyle(barMode ? Color.accentColor : Color.secondary)
                    .fixedSize()
                }
                .accessibilityValue(barMode ? "On" : "Off")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(barMode ? "Drink or ingredient" : "Search drinks or ingredients", text: $query)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: metrics.tapHeight, minHeight: metrics.tapHeight)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(barMode ? .title3 : .body)
        .padding(.leading, 14)
        .padding(.trailing, query.isEmpty ? 14 : 0)
        .frame(minHeight: metrics.tapHeight)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedFamily == nil && selectedTags.isEmpty, metrics: metrics) {
                    withAnimation(Theme.snap) {
                        selectedFamily = nil
                        selectedTags = []
                    }
                }
                ForEach(DrinkTag.allCases) { tag in
                    FilterChip(title: tag.displayName, isSelected: selectedTags.contains(tag), metrics: metrics) {
                        withAnimation(Theme.snap) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    }
                }
                Divider().frame(height: 20)
                ForEach(DrinkFamily.allCases) { family in
                    FilterChip(title: family.displayName, isSelected: selectedFamily == family, metrics: metrics) {
                        withAnimation(Theme.snap) {
                            selectedFamily = (selectedFamily == family) ? nil : family
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let metrics: BarMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(metrics.isOn ? .body.weight(.semibold) : .caption.weight(.medium))
                .padding(.horizontal, metrics.isOn ? 16 : 12)
                .frame(minHeight: metrics.isOn ? 48 : 30)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.93))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
