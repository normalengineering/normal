import SwiftData
import SwiftUI

struct CreateKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NFCService.self) private var nfcService
    @Environment(QRService.self) private var qrService

    @State private var name: String = ""
    @State private var keyType: KeyType = .nfc
    @State private var scannedKeyId: String?
    @State private var showQRScanner = false

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                setupSection
            }
            .navigationTitle("New Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(scannedKeyId == nil || name.isEmpty)
                }
            }
            .navigationDestination(isPresented: $showQRScanner) {
                QRScannerView(qrService: qrService)
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                qrService.cancel()
                                showQRScanner = false
                            }
                        }
                    }
            }
        }
    }

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Office Keycard", text: $name)
        }
    }

    private var setupSection: some View {
        Section("Setup") {
            VStack(alignment: .leading, spacing: 12) {
                Label("Choose Type", systemImage: "1.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Picker("Type", selection: $keyType) {
                    ForEach(KeyType.allCases) { type in
                        Label(
                            type.rawValue,
                            systemImage: type.icon
                        )
                        .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: keyType) { _, _ in
                    scannedKeyId = nil
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 12) {
                Label("Scan", systemImage: "2.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Button { handleScan() } label: {
                    scanButtonContent
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
    }

    private var scanButtonContent: some View {
        HStack {
            Image(systemName: keyType.icon
            )
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

    private func saveAndDismiss() {
        guard let rawValue = scannedKeyId else { return }
        let newKey = Key(name: name, type: keyType, rawValue: rawValue)
        modelContext.insert(newKey)
        dismiss()
    }
}
