import SwiftData
import SwiftUI

struct KeyFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(QRService.self) private var qrService

    let existing: Key?

    @State private var name: String
    @State private var keyType: KeyType
    @State private var scannedKeyId: String?
    @State private var showQRScanner = false

    private var isNew: Bool { existing == nil }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return isNew ? scannedKeyId != nil : true
    }

    init(existing: Key? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _keyType = State(initialValue: existing?.type ?? KeyType.availableOnDevice.first ?? .qr)
        _scannedKeyId = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Office Keycard", text: $name)
                }

                if isNew {
                    KeyFormSheetSetupSection(
                        keyType: $keyType,
                        scannedKeyId: $scannedKeyId,
                        showQRScanner: $showQRScanner
                    )
                } else {
                    Section("Key Type") {
                        HStack {
                            Label(keyType.label, systemImage: keyType.icon)
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Key" : "Edit Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Save" : "Update", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
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

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing {
            existing.name = trimmed
        } else {
            guard let rawValue = scannedKeyId else { return }
            modelContext.insert(Key(name: trimmed, type: keyType, rawValue: rawValue))
        }
        dismiss()
    }
}
