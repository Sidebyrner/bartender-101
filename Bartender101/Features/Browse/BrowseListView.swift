import SwiftUI

/// The full deck, searchable and filterable by family and tag — the plain
/// "read the index cards" experience your original ask was about. Everything
/// else in the app is a drill built on top of this list.
struct BrowseListView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @State private var query = ""
    @State private var selectedFamily: DrinkFamily?
    @State private var selectedTags: Set<DrinkTag> = []

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
            filterBar

            List(filtered) { drink in
                NavigationLink {
                    DrinkDetailView(drink: drink)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drink.name).font(.headline)
                        Text(drink.family.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .searchable(text: $query, prompt: "Search drinks or ingredients")
        .navigationTitle("Browse")
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
