import SwiftUI

struct InlineIconText: View {
    let systemImage: String
    let text: String
    let tint: Color
    var size: Font = .caption

    var body: some View {
        HStack(spacing: DS.Spacing.xs - 1) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(text)
                .font(size)
        }
        .foregroundStyle(tint)
    }
}
