import SwiftUI

struct SummaryRow: View {
    let systemImage: String
    let tint: Color
    let title: Text
    let subtitle: Text

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(tint)
                .frame(width: DS.Size.summaryIcon)
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
