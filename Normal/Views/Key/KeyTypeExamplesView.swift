import SwiftUI

/// Shared explainer for what NFC tags / QR codes can be used as keys and
/// where to place them. Reused by the Keys empty state and the FAQ.
struct KeyTypeExamplesView: View {
    private var isNFCAvailable: Bool { KeyType.nfc.isAvailableOnDevice }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            if isNFCAvailable { nfcCard }
            qrCard
            placementCard
        }
    }

    private var nfcCard: some View {
        card {
            cardTitle("NFC tag examples", systemImage: "wave.3.right")
            FeatureRow(systemImage: "tag.fill", text: "Almost any NFC tag works. AirTags, transit cards, amiibo, and even passports all have NFC chips you can use.")
            FeatureRow(systemImage: "cart.fill", text: "You can also buy packs of blank NFC tags online for very little.")
            FeatureRow(systemImage: "lock.shield.fill", text: "Normal only reads the tag's unique ID, never the data on it. That means only the tag you register can unblock your apps, and your privacy stays protected.")
        }
    }

    private var qrCard: some View {
        card {
            cardTitle("QR code examples", systemImage: "qrcode")
            FeatureRow(systemImage: "doc.fill", text: "Any QR code works. You can print one on paper, put it on a sticker, or show it on a second device's screen.")
            FeatureRow(systemImage: "arrow.triangle.2.circlepath", text: "Normal reads the value inside the QR code. Use something you can recreate later if you lose it, or make it random so it's hard to reproduce.")
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Generating one").font(.subheadline.weight(.semibold))
                BulletRow(text: "Any free \"QR code generator\" website")
                BulletRow(text: "The Shortcuts app's \"Generate QR Code\" action")
            }
            .padding(.top, DS.Spacing.xs)
        }
    }

    private var placementCard: some View {
        card {
            cardTitle("Where to place them", systemImage: "mappin.and.ellipse")
            FeatureRow(systemImage: "door.left.hand.closed", text: "Another room, a closet, or a high shelf", tint: .orange)
            FeatureRow(systemImage: "car.fill", text: "Your car, office, mailbox or with a trusted person", tint: .orange)
            FeatureRow(systemImage: "person.2.fill", text: "However difficult you make it to reach is how difficult it will be to unblock your device.", tint: .orange)
            BulletRow(text: "Keep a backup key somewhere safe so you're never fully locked out.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, DS.Spacing.xs)
        }
    }

    private func cardTitle(_ text: LocalizedStringKey, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.headline)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(DS.Radius.md)
    }
}
