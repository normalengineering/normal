import SwiftUI

struct SelectionIconRow: View {
    let tokens: [AnyHashable]
    var customDomains: [String] = []
    let maxCount: Int

    private var total: Int {
        tokens.count + customDomains.count
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(stride(from: min(maxCount, total), through: 0, by: -1)), id: \.self) { shown in
                HStack(spacing: DS.Spacing.sm) {
                    SelectionIconsView(tokens: tokens, customDomains: customDomains, limit: shown)
                    if total > shown {
                        SelectionOverflowBadge(count: total - shown)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("selectionIcons.row")
    }
}

private struct SelectionOverflowBadge: View {
    let count: Int
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 24

    var body: some View {
        Text("+\(count)")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, DS.Spacing.xs)
            .frame(minWidth: size, minHeight: size)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: size / 4, style: .continuous))
            .fixedSize()
            .accessibilityLabel(Text("\(count) more"))
            .accessibilityIdentifier("selectionIcons.overflow")
    }
}
