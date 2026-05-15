import SwiftUI

struct FeatureRow: View {
    let systemImage: String
    let text: LocalizedStringKey
    var tint: Color = .blue

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: DS.Size.iconWell, alignment: .center)
            Text(text)
                .font(.subheadline)
        }
    }
}
