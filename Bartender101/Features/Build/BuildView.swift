import SwiftUI

/// What both Build layouts can do to a drink. Owned by `BuildView` so the
/// board and the list share one set of rules — the On the Menu check, the
/// celebration, the delete confirmation.
struct BuildActions {
    let move: (_ id: String, _ stage: TestStage) -> Void
    let duplicate: (_ id: String) -> Void
    let requestDelete: (_ drink: CustomDrink) -> Void
    let newDrink: () -> Void
}

enum BuildLayout: String, CaseIterable, Identifiable {
    case board, list
    var id: String { rawValue }
}

/// The Build tab: every house drink, as a stage-by-stage board or a
/// scannable list of everything in the works, plus the button that starts a
/// new one. The layout choice is remembered.
struct BuildView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var customDrinks: CustomDrinkStore
    @AppStorage(SettingsKeys.buildLayout) private var layoutRaw = BuildLayout.board.rawValue

    @State private var showNewDrink = false
    @State private var blockedMove: BlockedMove?
    @State private var pendingDelete: CustomDrink?
    @State private var celebrations = 0
    @State private var moves = 0
    @State private var buttonCollapsed = false

    private struct BlockedMove: Identifiable {
        let id = UUID()
        let name: String
        let problems: [String]
    }

    private var layout: BuildLayout { BuildLayout(rawValue: layoutRaw) ?? .board }

    private var actions: BuildActions {
        BuildActions(
            move: attemptMove,
            duplicate: { id in withAnimation(Theme.spring) { _ = customDrinks.duplicate(id: id) } },
            requestDelete: { pendingDelete = $0 },
            newDrink: { showNewDrink = true }
        )
    }

    var body: some View {
        Group {
            if customDrinks.drinks.isEmpty {
                emptyState
            } else {
                switch layout {
                case .board:
                    BuildBoardView(actions: actions)
                        .transition(.opacity)
                case .list:
                    BuildListView(actions: actions, buttonCollapsed: $buttonCollapsed)
                        .transition(.opacity)
                }
            }
        }
        .animation(Theme.spring, value: layoutRaw)
        .overlay(alignment: .bottomTrailing) {
            if !customDrinks.drinks.isEmpty {
                NewDrinkButton(collapsed: buttonCollapsed, emphasize: false) { showNewDrink = true }
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay { ConfettiBurst(trigger: celebrations) }
        .sensoryFeedback(.success, trigger: celebrations)
        .sensoryFeedback(.impact(weight: .medium), trigger: moves)
        .sensoryFeedback(.selection, trigger: layoutRaw)
        .navigationTitle("Build")
        .toolbar {
            if !customDrinks.drinks.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Layout", selection: $layoutRaw) {
                        Image(systemName: "rectangle.split.3x1").tag(BuildLayout.board.rawValue)
                            .accessibilityLabel("Board")
                        Image(systemName: "list.bullet").tag(BuildLayout.list.rawValue)
                            .accessibilityLabel("List")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
            }
        }
        .sheet(isPresented: $showNewDrink) {
            NewDrinkSheet()
        }
        .alert(item: $blockedMove) { blocked in
            Alert(
                title: Text("\(blocked.name) isn't ready for the menu"),
                message: Text(blocked.problems.joined(separator: "\n")),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            pendingDelete.map { "Delete \($0.displayName)?" } ?? "",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { drink in
            Button("Delete Drink", role: .destructive) {
                withAnimation(Theme.spring) { customDrinks.delete(id: drink.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its spec and tasting log are removed. Photos and shift log entries stay.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 150, height: 150)
                Image(systemName: "flask.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(Theme.accentGradient())
                    .modifier(RepeatingBounce())
            }
            VStack(spacing: 8) {
                Text("Your drinks start here")
                    .font(.system(.title2, design: .serif, weight: .bold))
                Text("Start from a classic ratio or riff on a drink you know, then test it until it's ready for the menu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            NewDrinkButton(collapsed: false, emphasize: true) { showNewDrink = true }
                .padding(.top, 6)
            Spacer()
            Spacer()
        }
    }

    private func attemptMove(id: String, to stage: TestStage) {
        guard let drink = customDrinks.drink(id: id), drink.stage != stage else { return }
        if stage == .onMenu {
            let problems = library.menuProblems(for: drink)
            guard problems.isEmpty else {
                blockedMove = BlockedMove(name: drink.displayName, problems: problems)
                return
            }
        }
        withAnimation(Theme.spring) {
            customDrinks.move(id: id, to: stage)
        }
        moves += 1
        if stage == .onMenu { celebrations += 1 }
    }
}

/// The long-press menu for a house drink, shared by the board and the list.
struct DrinkCardMenu: View {
    let drink: CustomDrink
    let actions: BuildActions

    var body: some View {
        Menu("Move To") {
            ForEach(TestStage.allCases.filter { $0 != drink.stage }) { stage in
                Button {
                    actions.move(drink.id, stage)
                } label: {
                    Label(stage.displayName, systemImage: stage.systemImage)
                }
            }
        }
        Button {
            actions.duplicate(drink.id)
        } label: {
            Label("Duplicate as New Version", systemImage: "plus.square.on.square")
        }
        Button(role: .destructive) {
            actions.requestDelete(drink)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

/// A slow, repeating bounce. Repeating bounce needs iOS 18; iOS 17 gets a
/// gentle pulse instead.
private struct RepeatingBounce: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.symbolEffect(.bounce, options: .repeating.speed(0.25))
        } else {
            content.symbolEffect(.pulse, options: .repeating.speed(0.5))
        }
    }
}
