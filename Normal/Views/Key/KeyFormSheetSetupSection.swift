import SwiftUI

struct KeyFormSheetSetupSection: View {
    @Environment(NFCService.self) private var nfcService
    @Environment(QRService.self) private var qrService

    @Binding var keyType: KeyType
    @Binding var scannedKeyId: String?
    @Binding var showQRScanner: Bool

    private var hasMultipleTypes: Bool {
        KeyType.availableOnDevice.count > 1
    }

    var body: some View {
        Section("Setup") {
            if hasMultipleTypes { typePickerStep }
            scanStep
        }
    }

    private var typePickerStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            stepLabel(number: 1, title: "Choose Type")
            Picker("Type", selection: $keyType) {
                ForEach(KeyType.availableOnDevice) { type in
                    Label(type.rawValue, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: keyType) { _, _ in scannedKeyId = nil }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var scanStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            stepLabel(number: hasMultipleTypes ? 2 : 1, title: "Scan")
            Button(action: handleScan) { scanButtonContent }
                .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private func stepLabel(number: Int, title: String) -> some View {
        Label(title, systemImage: "\(number).circle.fill")
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
    }

    private var scanButtonContent: some View {
        HStack {
            Image(systemName: keyType.icon).font(.title2)
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
            (scannedKeyId != nil ? Color.green : Color.accentColor).opacity(DS.Opacity.subtle)
        )
        .cornerRadius(DS.Radius.md)
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
