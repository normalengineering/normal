import SwiftUI

struct KeyTypesFAQView: View {
    private var isNFCAvailable: Bool { KeyType.nfc.isAvailableOnDevice }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(intro)
            if !isNFCAvailable { iPadNote }
            KeyTypeExamplesView()
        }
        .font(.body)
        .foregroundStyle(.secondary)
    }

    private var intro: LocalizedStringKey {
        isNFCAvailable
            ? "Just about any NFC tag or QR code can be a key. Here are some examples and tips on where to keep them."
            : "Just about any QR code can be a key. Here are some examples and tips on where to keep them."
    }

    private var iPadNote: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "ipad")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Using an iPad?").fontWeight(.semibold).foregroundStyle(.primary)
                Text("This device can't scan NFC, so NFC tags won't work here. Use a QR code instead.")
                    .foregroundStyle(.primary)
            }
        }
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(DS.Opacity.muted))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
