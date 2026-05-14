import SwiftUI

struct KeyFormSheetSetupSection: View {
    @Environment(NFCService.self) private var nfcService
    @Environment(QRService.self) private var qrService

    @Binding var keyType: KeyType
    @Binding var scannedKeyId: String?
    @Binding var showQRScanner: Bool

    var body: some View {
        Section("Setup") {
            if KeyType.availableOnDevice.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Choose Type", systemImage: "1.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    Picker("Type", selection: $keyType) {
                        ForEach(KeyType.availableOnDevice) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: keyType) { _, _ in
                        scannedKeyId = nil
                    }
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Scan", systemImage: KeyType.availableOnDevice.count > 1 ? "2.circle.fill" : "1.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Button(action: handleScan) {
                    scanButtonContent
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
    }

    private var scanButtonContent: some View {
        HStack {
            Image(systemName: keyType.icon)
                .font(.title2)

            Text(scannedKeyId != nil ? "Key Linked" : "Tap to Scan")
                .font(.headline)

            Spacer()

            if scannedKeyId != nil {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            scannedKeyId != nil
                ? Color.green.opacity(0.1)
                : Color.accentColor.opacity(0.1)
        )
        .cornerRadius(12)
    }

    private func handleScan() {
        Task {
            do {
                let id: String

                switch keyType {
                case .nfc:
                    id = try await nfcService.scan()
                case .qr:
                    showQRScanner = true
                    id = try await qrService.scan()
                    showQRScanner = false
                }

                withAnimation(.spring()) {
                    scannedKeyId = id
                }
            } catch {
                showQRScanner = false
            }
        }
    }
}
