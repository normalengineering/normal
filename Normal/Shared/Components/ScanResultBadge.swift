import SwiftUI

struct ScanResultBadge: View {
    let systemImage: String
    let tint: Color
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundStyle(tint)
            Text(text)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(DS.Spacing.xxxl)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
    }
}
