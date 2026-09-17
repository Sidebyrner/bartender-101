import SwiftUI

@main
struct Bartender101App: App {
    @StateObject private var library = DrinkLibrary()
    @StateObject private var reviewStore = ReviewStore()
    @StateObject private var shiftLog = ShiftLogStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(library)
                .environmentObject(reviewStore)
                .environmentObject(shiftLog)
        }
    }
}

/// Top-level tab layout. Search comes first because looking a drink up
/// mid-shift is the most time-sensitive thing the app does. The three drills
/// (Review, Speed Drill, Reverse) aren't tabs of their own — they're entry
/// points from Study — so the tab bar stays to the four places you'd return
/// to repeatedly: search, study, your stats, and settings.
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack { StudyHomeView() }
                .tabItem { Label("Study", systemImage: "rectangle.stack.fill") }

            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
