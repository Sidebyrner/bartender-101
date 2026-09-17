import SwiftUI

/// The builder's live read-out: one stacked bar showing how the measured
/// pour splits across spirit, liqueur, sour, sweet, and the rest, the total
/// volume, and any rule-of-thumb warnings from `DrinkBalance`.
struct BalanceMeterView: View {
    let summary: DrinkBalance.Summary
    let unit: MeasurementUnit

    /// Roles drawn in the bar, in pour-logic order. Accents carry no volume.
    private static let barRoles: [FlavorRole] = [.spirit, .modifier, .sour, .sweet, .dairy, .lengthener, .other]

    private var measuredRoles: [FlavorRole] {
        Self.barRoles.filter { summary.oz($0) > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("BALANCE")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(summary.totalOz > 0 ? Measure.label(oz: summary.totalOz, unit: unit) + " total" : "Nothing measured yet")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(summary.totalOz > 0 ? .primary : .secondary)
                    .contentTransition(.numericText(value: summary.totalOz))
                    .animation(Theme.snap, value: summary.totalOz)
            }

            GeometryReader { proxy in
                HStack(spacing: 2) {
                    if summary.totalOz > 0 {
                        ForEach(measuredRoles, id: \.self) { role in
                            Rectangle()
                                .fill(role.color)
                                .frame(width: max(4, (proxy.size.width - CGFloat(measuredRoles.count - 1) * 2) * summary.oz(role) / summary.totalOz))
                        }
                    } else {
                        Rectangle().fill(Color(.tertiarySystemFill))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 14)
            .animation(.snappy, value: summary)
            .accessibilityHidden(true)

            if !measuredRoles.isEmpty {
                FlowLayout(spacing: 10) {
                    ForEach(measuredRoles, id: \.self) { role in
                        HStack(spacing: 4) {
                            Circle().fill(role.color).frame(width: 8, height: 8)
                            Text("\(role.displayName) \(Measure.label(oz: summary.oz(role), unit: unit))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            ForEach(summary.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: summary.warnings)
    }
}

extension FlavorRole {
    var color: Color {
        switch self {
        case .spirit: return .brown
        case .modifier: return .red
        case .sour: return .yellow
        case .sweet: return .pink
        case .dairy: return Color(.systemGray3)
        case .lengthener: return .teal
        case .accent: return .purple
        case .other: return .gray
        }
    }
}

/// Wraps its children onto new lines when they run out of width — used for
/// the balance legend and label chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
