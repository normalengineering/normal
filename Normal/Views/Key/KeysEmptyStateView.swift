import SwiftUI

struct KeysEmptyStateView: View {
    let onAddKey: () -> Void

    private var noKeysDescription: LocalizedStringKey {
        KeyType.nfc.isAvailableOnDevice
            ? "Keys are required to block and unblock apps. Add an NFC tag or QR code to get started."
            : "Keys are required to block and unblock apps. Add a QR code to get started."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                addButton
                KeyTypeExamplesView()
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Image(systemName: "key.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("No Keys Yet").font(.title2.bold())
            Text(noKeysDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var addButton: some View {
        Button("Add Key", action: onAddKey)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
    }
}
