import SwiftUI

struct StatusBadge: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
    }
}
