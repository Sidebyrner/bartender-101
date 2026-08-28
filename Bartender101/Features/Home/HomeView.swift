import SwiftUI

/// Study home: how many cards are due, a streak counter, and the entry
/// points into the three drills. This is the screen you open every time you
/// sit down to study.
struct HomeView: View {
    @EnvironmentObject private var library: DrinkLibrary
    @EnvironmentObject private var reviewStore: ReviewStore

    private var dueCount: Int {
        reviewStore.dueDrinks(from: library.drinks).count
    }

    private var reviewedCount: Int {
        reviewStore.states.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard

                VStack(spacing: 14) {
                    NavigationLink {
                        ReviewSessionView()
                    } label: {
                        DrillRow(
                            title: "Spaced Review",
                            subtitle: dueCount > 0 ? "\(dueCount) card\(dueCount == 1 ? "" : "s") due" : "All caught up",
                            systemImage: "brain.head.profile",
                            tint: .blue
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
                            tint: .orange
                        )
                    }

                    NavigationLink {
                        ReverseQuizView()
                    } label: {
                        DrillRow(
                            title: "Name That Drink",
                            subtitle: "Spec shown, you name it",
                            systemImage: "arrow.uturn.left.circle.fill",
                            tint: .purple
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 12)
        }
        .navigationTitle("Bartender 101")
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(library.drinks.count)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("drinks in the deck")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(reviewedCount)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("cards started")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal)
    }
}

private struct DrillRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}
