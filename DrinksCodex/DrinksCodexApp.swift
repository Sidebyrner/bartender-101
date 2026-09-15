import SwiftUI

@main
struct DrinksCodexApp: App {
    @StateObject private var library = DrinkLibrary()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(library)
        }
    }
}

/// Two tabs: the searchable encyclopedia and unit preferences. No
/// memorization drills here — this app is a fast during-shift reference,
/// not a study tool. `Bartender101` (this repo's other app) covers drilling.
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
