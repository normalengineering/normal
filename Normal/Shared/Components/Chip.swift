import SwiftUI

struct Chip: View {
    let text: String
    var tint: Color = .accentColor
    var isProminent: Bool = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, DS.Spacing.sm - 2)
            .padding(.vertical, DS.Spacing.xs - 1)
            .foregroundStyle(isProminent ? Color.white : .primary)
            .background(isProminent ? tint : tint.opacity(DS.Opacity.muted))
            .clipShape(Capsule())
    }
}
