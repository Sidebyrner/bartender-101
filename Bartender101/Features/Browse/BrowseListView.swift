import SwiftUI

/// The full deck, searchable and filterable by family and tag — the plain
/// "read the index cards" experience. Everything else in the app is a drill
/// built on top of this list.
///
/// A `NavigationSplitView` rather than a stack: on iPhone it collapses to
/// ordinary push navigation, and on iPad the deck stays visible beside the
/// card instead of being replaced by it.
struct BrowseListView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @State private var query = ""
    @State private var selectedFamily: DrinkFamily?
    @State private var selectedTags: Set<DrinkTag> = []
    /// Bound to the drink's `id`, not the drink itself — `List(_:selection:)`
    /// over `Identifiable` data selects by ID.
    @State private var selectedID: Drink.ID?

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
        NavigationSplitView {
            VStack(spacing: 0) {
                filterBar

                List(filtered, selection: $selectedID) { drink in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drink.name).font(.headline)
                        Text(drink.family.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if filtered.isEmpty {
                        DeckStateView(loadError: library.loadError, query: query)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search drinks or ingredients")
            .navigationTitle("Browse")
        } detail: {
            if let selectedID, let drink = library.drink(id: selectedID) {
                DrinkDetailView(drink: drink)
            } else {
                NoSelectionView()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedFamily == nil && selectedTags.isEmpty) {
                    selectedFamily = nil
                    selectedTags = []
                }
                ForEach(DrinkTag.allCases) { tag in
                    FilterChip(title: tag.displayName, isSelected: selectedTags.contains(tag)) {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                }
                Divider().frame(height: 20)
                ForEach(DrinkFamily.allCases) { family in
                    FilterChip(title: family.displayName, isSelected: selectedFamily == family) {
                        selectedFamily = (selectedFamily == family) ? nil : family
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
