import SwiftUI

/// Icon + headline + caption, the shape every Home section row uses to
/// summarise a subsystem and lead into its detail screen.
struct SummaryRow: View {
    let systemImage: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: String

    var body: some View {
        HStack(spacing: DS.Spacing.summaryIcon) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(tint)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
