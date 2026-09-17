import SwiftUI

/// Which drinks the list shows.
enum BuildListScope: String, CaseIterable, Identifiable {
    case inTheWorks, onMenu, shelved, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inTheWorks: return "In the Works"
        case .onMenu: return "On the Menu"
        case .shelved: return "Shelved"
        case .all: return "All"
        }
    }

    func includes(_ stage: TestStage) -> Bool {
        switch self {
        case .inTheWorks: return stage.isInTheWorks
        case .onMenu: return stage == .onMenu
        case .shelved: return stage == .shelved
        case .all: return true
        }
    }
}

/// The list layout of the Build tab: every house drink at a glance, grouped
/// by stage, newest activity first. Defaults to what's in the works. Swipe
/// right to advance a drink to its next stage, swipe left to delete.
struct BuildListView: View {
    let actions: BuildActions
    @Binding var buttonCollapsed: Bool

    @EnvironmentObject private var customDrinks: CustomDrinkStore
    @EnvironmentObject private var photoStore: PhotoStore
    @State private var scope: BuildListScope = .inTheWorks
    @State private var query = ""

    private func drinks(in stage: TestStage) -> [CustomDrink] {
        customDrinks.drinks(in: stage).filter { $0.matches(query: query) }
    }

    private var visibleStages: [TestStage] {
        TestStage.allCases.filter { scope.includes($0) && !drinks(in: $0).isEmpty }
    }

    var body: some View {
        List {
            Section {
                scopeChips
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(visibleStages) { stage in
                let stageDrinks = drinks(in: stage)
                Section {
                    ForEach(stageDrinks) { drink in
                        NavigationLink {
                            DrinkDetailView(drink: drink.asDrink())
                        } label: {
                            BuildListRow(drink: drink, cover: photoStore.photos(for: drink.id).first)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if let next = drink.stage.next {
                                Button {
                                    actions.move(drink.id, next)
                                } label: {
                                    Label(next.displayName, systemImage: next.systemImage)
                                }
                                .tint(next.tint)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                actions.requestDelete(drink)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .contextMenu { DrinkCardMenu(drink: drink, actions: actions) }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: stage.systemImage)
                            .foregroundStyle(stage.tint)
                        Text(stage.displayName)
                        Text("\(stageDrinks.count)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(stage.tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(stage.tint.opacity(0.15)))
                            .contentTransition(.numericText(value: Double(stageDrinks.count)))
                    }
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
                }
            }

            // Room to scroll the last row clear of the New Drink button.
            Color.clear
                .frame(height: 70)
                .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .overlay {
            if visibleStages.isEmpty {
                emptyScope
            }
        }
        .animation(Theme.spring, value: scope)
        .animation(Theme.spring, value: customDrinks.drinks)
        .searchable(text: $query, prompt: "Name, label, or ingredient")
        .sensoryFeedback(.selection, trigger: scope)
        .modifier(CollapseOnScroll(collapsed: $buttonCollapsed))
    }

    private var scopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BuildListScope.allCases) { option in
                    let count = customDrinks.drinks.filter { option.includes($0.stage) }.count
                    let selected = scope == option
                    Button {
                        withAnimation(Theme.snap) { scope = option }
                    } label: {
                        HStack(spacing: 5) {
                            Text(option.title)
                            Text("\(count)")
                                .monospacedDigit()
                                .opacity(0.75)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(selected ? Color.accentColor : Color(.secondarySystemGroupedBackground)))
                        .foregroundStyle(selected ? .white : .primary)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.pressable(scale: 0.93))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var emptyScope: some View {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            switch scope {
            case .inTheWorks:
                ContentUnavailableView {
                    Label("Nothing in the works", systemImage: "flask")
                } description: {
                    Text("Every drink is on the menu or shelved. Time to start something new.")
                } actions: {
                    Button("New Drink", action: actions.newDrink)
                        .buttonStyle(.borderedProminent)
                }
            case .onMenu:
                ContentUnavailableView("Nothing on the menu yet", systemImage: "menucard",
                                       description: Text("Swipe right on a dialed-in drink to put it on the menu."))
            case .shelved:
                ContentUnavailableView("Nothing shelved", systemImage: "archivebox",
                                       description: Text("Ideas you set aside will wait here."))
            case .all:
                ContentUnavailableView("No house drinks", systemImage: "flask")
            }
        }
    }
}

/// One drink in the list: photo or stage tile, name, spec summary, labels,
/// and when it was last worked on.
private struct BuildListRow: View {
    let drink: CustomDrink
    let cover: DrinkPhoto?

    private var averageRating: Double? {
        let ratings = drink.tastings.compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let cover {
                    PhotoThumbnail(photo: cover)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    IconTile(systemImage: drink.family.systemImage, tint: drink.stage.tint, size: 52)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(drink.displayName)
                    .font(.system(.headline, design: .serif, weight: .bold))
                Text("\(drink.family.displayName) · \(drink.method.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !drink.ingredients.isEmpty {
                    Text(drink.asDrink().ingredientSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !drink.labels.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(drink.labels, id: \.self) { label in
                            Text(label)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                }
                HStack(spacing: 10) {
                    Text("Updated \(drink.updatedAt, format: .relative(presentation: .named))")
                    if !drink.tastings.isEmpty {
                        Label("\(drink.tastings.count)", systemImage: "text.bubble")
                    }
                    if let averageRating {
                        Label(String(format: "%.1f", averageRating), systemImage: "star.fill")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint(drink.stage.next.map { "Swipe right to move to \($0.displayName)" } ?? "")
    }
}

/// Collapses the floating New Drink button while the list scrolls, and
/// brings it back once scrolling settles. Scroll phases need iOS 18; on
/// iOS 17 the button simply stays expanded.
private struct CollapseOnScroll: ViewModifier {
    @Binding var collapsed: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollPhaseChange { _, phase in
                    withAnimation(Theme.spring) { collapsed = phase.isScrolling }
                }
                .onDisappear { collapsed = false }
        } else {
            content
        }
    }
}
