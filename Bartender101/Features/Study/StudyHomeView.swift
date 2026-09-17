import SwiftUI

/// Study home: how much of the deck you've started, how many cards are due,
/// and the entry points into the three drills. This is the screen you open
/// every time you sit down to study, so the numbers lead.
struct StudyHomeView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var reviewStore: ReviewStore

    private var dueCount: Int {
        reviewStore.dueDrinks(from: library.drinks).count
    }

    private var startedCount: Int {
        library.drinks.filter { reviewStore.states[$0.id] != nil }.count
    }

    private var coverage: Double {
        library.drinks.isEmpty ? 0 : Double(startedCount) / Double(library.drinks.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroCard

                VStack(spacing: 12) {
                    NavigationLink {
                        ReviewSessionView()
                    } label: {
                        DrillRow(
                            title: "Spaced Review",
                            subtitle: dueCount > 0 ? "Ready when you are" : "All caught up — nice",
                            systemImage: "brain.head.profile",
                            tint: .accentColor,
                            badge: dueCount > 0 ? dueCount : nil
                        )
                    }
                    .disabled(dueCount == 0)

                    NavigationLink {
                        SpeedDrillView()
                    } label: {
                        DrillRow(
                            title: "Speed Drill",
                            subtitle: "Beat the clock on ingredients",
                            systemImage: "timer",
                            tint: .orange,
                            badge: nil
                        )
                    }

                    NavigationLink {
                        ReverseQuizView()
                    } label: {
                        DrillRow(
                            title: "Name That Drink",
                            subtitle: "Spec shown, you name it",
                            systemImage: "text.magnifyingglass",
                            tint: .purple,
                            badge: nil
                        )
                    }
                }
                .buttonStyle(.pressable(scale: 0.98))
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Study")
    }

    private var heroCard: some View {
        HStack(spacing: 20) {
            ProgressRing(progress: coverage, lineWidth: 12) {
                VStack(spacing: 0) {
                    Text(coverage, format: .percent.precision(.fractionLength(0)))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("started")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 12) {
                stat(value: startedCount, label: "of \(library.drinks.count) drinks started")
                stat(value: dueCount, label: dueCount == 1 ? "card due now" : "cards due now")
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .cardSurface(cornerRadius: 22, elevated: true)
        .padding(.horizontal)
        .animation(Theme.spring, value: dueCount)
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DrillRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let badge: Int?

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: systemImage, tint: isEnabled ? tint : .gray, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let badge {
                Text("\(badge)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .frame(minWidth: 28, minHeight: 28)
                    .background(Capsule().fill(tint))
                    .contentTransition(.numericText(value: Double(badge)))
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .cardSurface()
        .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}
