import SwiftUI

@main
struct Bartender101App: App {
    @StateObject private var library = DrinkLibrary()
    @StateObject private var reviewStore = ReviewStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(library)
                .environmentObject(reviewStore)
        }
    }
}

/// Top-level tab layout. The three drills (Review, Speed Drill, Reverse)
/// aren't tabs of their own — they're entry points from Home — so the tab
/// bar stays to the four places you'd return to repeatedly: study home,
/// the browsable deck, your stats, and settings.
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            // No NavigationStack wrapper — BrowseListView is a
            // NavigationSplitView, which collapses to a stack on iPhone by
            // itself. Nesting it in one would break the iPad sidebar.
            BrowseListView()
                .tabItem { Label("Browse", systemImage: "rectangle.stack.fill") }

            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
