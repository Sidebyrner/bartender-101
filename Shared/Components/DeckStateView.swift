import SwiftUI

/// The empty state for a drink list, shared by both apps.
///
/// Distinguishes a failed deck load from a search that legitimately found
/// nothing. `DrinkLibrary.loadError` was previously set but never read by any
/// view, so a `drinks.json` decode failure left `drinks` empty and surfaced as
/// "No results" — which sends you hunting for a search bug instead of a
/// data one.
struct DeckStateView: View {
    let loadError: String?
    let query: String

    var body: some View {
        if let loadError {
            ContentUnavailableView {
                Label("Couldn't load the deck", systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadError)
            }
        } else {
            ContentUnavailableView.search(text: query)
        }
    }
}

/// Shown in the detail pane on iPad when no drink is selected yet. On iPhone
/// `NavigationSplitView` collapses to a stack and this is never reached.
struct NoSelectionView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Pick a drink", systemImage: "wineglass")
        } description: {
            Text("Choose one from the list to see its full spec.")
        }
    }
}
