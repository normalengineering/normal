import SwiftUI

struct SummaryRow: View {
    let systemImage: String
    let tint: Color
    let title: Text
    let subtitle: Text
    @ScaledMetric(relativeTo: .title) private var iconWidth = DS.Size.summaryIcon

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(tint)
                .frame(width: iconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                title
                    .font(.headline)
                subtitle
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
