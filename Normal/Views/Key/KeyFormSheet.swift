import SwiftData
import SwiftUI

struct CapturedLocation: Equatable {
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var kind: LocationRadiusKind
}

struct KeyFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(QRService.self) private var qrService

    let existing: Key?

    @State private var name: String
    @State private var keyType: KeyType
    @State private var scannedKeyId: String?
    @State private var scannedKind: ScanCodeKind?
    @State private var radiusKind: LocationRadiusKind
    @State private var capturedLocation: CapturedLocation?
    @State private var showQRScanner = false
    @State private var showLocationPicker = false

    private var isNew: Bool { existing == nil }

    private var isCaptured: Bool {
        switch keyType {
        case .nfc, .qr: scannedKeyId != nil
        case .location: capturedLocation != nil
        }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return isNew ? isCaptured : true
    }

    init(existing: Key? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _keyType = State(initialValue: existing?.type ?? KeyType.availableOnDevice.first ?? .qr)
        _scannedKeyId = State(initialValue: nil)
        _radiusKind = State(initialValue: existing?.radiusKind ?? .unblock)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Office Keycard", text: $name)
                        .accessibilityIdentifier("key.nameField")
                }

                if isNew {
                    KeyFormSheetSetupSection(
                        keyType: $keyType,
                        scannedKeyId: $scannedKeyId,
                        scannedKind: $scannedKind,
                        radiusKind: $radiusKind,
                        capturedLocation: $capturedLocation,
                        showQRScanner: $showQRScanner,
                        showLocationPicker: $showLocationPicker
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

                    if keyType == .location, let existing, existing.coordinate != nil {
                        Section("Location") {
                            LocationKeyMapPreview(key: existing)
                                .listRowInsets(EdgeInsets())
                            if let radius = existing.radiusMeters {
                                LabeledContent("Radius", value: LocationPickerSheet.formatted(meters: radius))
                            }
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
                        .accessibilityIdentifier("key.saveButton")
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
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerSheet(kind: radiusKind) { latitude, longitude, radius in
                    withAnimation(.spring()) {
                        capturedLocation = CapturedLocation(
                            latitude: latitude,
                            longitude: longitude,
                            radiusMeters: radius,
                            kind: radiusKind
                        )
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
            switch keyType {
            case .nfc, .qr:
                guard let rawValue = scannedKeyId else { return }
                modelContext.insert(Key(name: trimmed, type: keyType, rawValue: rawValue, scanKind: scannedKind))
            case .location:
                guard let captured = capturedLocation else { return }
                modelContext.insert(Key(
                    name: trimmed,
                    latitude: captured.latitude,
                    longitude: captured.longitude,
                    radiusMeters: captured.radiusMeters,
                    radiusKind: captured.kind
                ))
            }
        }
        dismiss()
    }
}
