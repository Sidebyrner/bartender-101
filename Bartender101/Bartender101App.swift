import SwiftUI

@main
struct Bartender101App: App {
    @StateObject private var library = DrinkLibrary()
    @StateObject private var reviewStore = ReviewStore()
    @StateObject private var shiftLog = ShiftLogStore()
    @StateObject private var customDrinks = CustomDrinkStore()
    @StateObject private var ingredientCatalog = IngredientCatalog()
    @StateObject private var photoStore = PhotoStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(library)
                .environmentObject(reviewStore)
                .environmentObject(shiftLog)
                .environmentObject(customDrinks)
                .environmentObject(ingredientCatalog)
                .environmentObject(photoStore)
                // House drinks On the Menu join the deck everywhere, and the
                // ingredient picker learns usual pours from the whole deck.
                .onAppear {
                    library.setCustomDrinks(customDrinks.drinks)
                    ingredientCatalog.learn(fromDeck: library.drinks)
                    ingredientCatalog.learn(fromHouseDrinks: customDrinks.drinks)
                }
                .onReceive(customDrinks.$drinks) { drinks in
                    library.setCustomDrinks(drinks)
                    ingredientCatalog.learn(fromHouseDrinks: drinks)
                }
        }
    }
}

/// Top-level tab layout. Search comes first because looking a drink up
/// mid-shift is the most time-sensitive thing the app does. The three drills
/// (Review, Speed Drill, Reverse) aren't tabs of their own — they're entry
/// points from Study — so the tab bar stays to the places you'd return to
/// repeatedly: search, study, building house drinks, your stats, and settings.
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack { StudyHomeView() }
                .tabItem { Label("Study", systemImage: "rectangle.stack.fill") }

            NavigationStack { BuildBoardView() }
                .tabItem { Label("Build", systemImage: "flask.fill") }

            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
