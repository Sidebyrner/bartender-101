import SwiftUI

/// The testing section at the top of a house drink's recipe page: its stage,
/// labels, and tasting log. Everything below it on the page is the normal
/// recipe, so a test pour can be made and logged with Made it like any drink.
struct HouseDrinkPanel: View {
    let drink: CustomDrink
    let metrics: BarMetrics

    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var customDrinks: CustomDrinkStore
    @State private var showAddTasting = false
    @State private var menuProblems: [String] = []
    @State private var showMenuProblems = false
    @State private var celebrations = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(TestStage.allCases) { stage in
                        Button {
                            move(to: stage)
                        } label: {
                            Label(stage.displayName, systemImage: stage.systemImage)
                        }
                        .disabled(stage == drink.stage)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: drink.stage.systemImage)
                            .contentTransition(.symbolEffect(.replace))
                        Text(drink.stage.displayName)
                            .contentTransition(.interpolate)
                        Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.bold))
                    }
                    .font(metrics.isOn ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: metrics.isOn ? 48 : 34)
                    .background(Capsule().fill(drink.stage.tint.opacity(0.18)))
                    .foregroundStyle(drink.stage == .shelved ? Color.secondary : Color.primary)
                    .overlay { ConfettiBurst(trigger: celebrations) }
                }
                .animation(Theme.spring, value: drink.stage)
                .accessibilityLabel("Stage: \(drink.stage.displayName)")

                if let basedOn = drink.basedOnDrinkID.flatMap(library.drink(id:)) {
                    Text("Riff on the \(basedOn.name)")
                        .font(metrics.isOn ? .body : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if !drink.labels.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(drink.labels, id: \.self) { label in
                        Text(label)
                            .font(metrics.isOn ? .body : .caption.weight(.medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(.secondarySystemBackground)))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TASTING LOG")
                        .font(metrics.sectionLabelFont)
                        .tracking(1.5)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Button {
                        showAddTasting = true
                    } label: {
                        Label("Add Note", systemImage: "plus")
                            .font(metrics.isOn ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                    }
                }

                if drink.tastings.isEmpty {
                    Text("Nothing yet. Make it, taste it, and note what to change.")
                        .font(metrics.isOn ? .title3 : .subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(drink.tastings.reversed()) { note in
                        TastingRow(note: note, metrics: metrics)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .contextMenu {
                                Button(role: .destructive) {
                                    customDrinks.removeTasting(id: drink.id, noteID: note.id)
                                } label: {
                                    Label("Delete Note", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding()
            .cardSurface(cornerRadius: 14)
            .animation(Theme.spring, value: drink.tastings.count)
        }
        .sensoryFeedback(.success, trigger: celebrations)
        .sheet(isPresented: $showAddTasting) {
            AddTastingSheet(drinkName: drink.displayName) { note in
                customDrinks.addTasting(id: drink.id, note: note)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Not ready for the menu", isPresented: $showMenuProblems) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(menuProblems.joined(separator: "\n"))
        }
    }

    private func move(to stage: TestStage) {
        if stage == .onMenu {
            let problems = library.menuProblems(for: drink)
            guard problems.isEmpty else {
                menuProblems = problems
                showMenuProblems = true
                return
            }
        }
        withAnimation(Theme.spring) {
            customDrinks.move(id: drink.id, to: stage)
        }
        if stage == .onMenu { celebrations += 1 }
    }
}

private struct TastingRow: View {
    let note: TastingNote
    let metrics: BarMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(metrics.isOn ? .body : .caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let rating = note.rating {
                    StarRating(rating: rating)
                        .font(metrics.isOn ? .body : .caption)
                }
            }
            Text(note.text)
                .font(metrics.isOn ? .title3 : .body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StarRating: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(star <= rating ? Color.yellow : Color.secondary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(rating) out of 5 stars")
    }
}

private struct AddTastingSheet: View {
    let drinkName: String
    let onSave: (TastingNote) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var rating: Int?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. v2: dropped lime to ½ oz — better", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
                }
                Section("Rating") {
                    HStack(spacing: 14) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(Theme.snap) {
                                    rating = (rating == star) ? nil : star
                                }
                            } label: {
                                Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundStyle(star <= (rating ?? 0) ? Color.yellow : Color.secondary)
                                    .contentTransition(.symbolEffect(.replace))
                                    .symbolEffect(.bounce, value: rating == star)
                                    .scaleEffect(star <= (rating ?? 0) ? 1.1 : 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(star) stars")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.selection, trigger: rating)
                }
            }
            .navigationTitle(drinkName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(TastingNote(text: text.trimmingCharacters(in: .whitespacesAndNewlines), rating: rating))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && rating == nil)
                }
            }
            .onAppear { focused = true }
        }
    }
}
