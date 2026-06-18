import SwiftUI

struct BulletRow: View {
    let text: String
    var indent: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text("\u{2022}")
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, indent)
    }
}
