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
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var keys: [Key]

    let existing: Key?
    var groupID: UUID?

    @State private var name: String
    @State private var keyType: KeyType
    @State private var scannedKeyId: String?
    @State private var scannedKind: ScanCodeKind?
    @State private var radiusKind: LocationRadiusKind
    @State private var capturedLocation: CapturedLocation?
    @State private var showQRScanner = false
    @State private var showLocationPicker = false
    @State private var showDeleteConfirmation = false
    @State private var showLastKeyAlert = false
    @State private var showKeyTypeLockedAlert = false

    private var isNew: Bool { existing == nil }

    private var isReadOnly: Bool { !isNew && screenTimeService.activeShieldCount() > 0 }

    private var isLastKey: Bool {
        guard let existing else { return false }
        return !Key.canDelete(existing, in: keys)
    }

    private var navigationTitle: String {
        if isNew { return "New Key" }
        return isReadOnly ? "Key" : "Edit Key"
    }

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

    init(existing: Key? = nil, groupID: UUID? = nil) {
        self.existing = existing
        self.groupID = groupID
        _name = State(initialValue: existing?.name ?? "")
        _keyType = State(initialValue: existing?.type ?? KeyType.availableOnDevice.first ?? .qr)
        _scannedKeyId = State(initialValue: nil)
        _radiusKind = State(initialValue: existing?.radiusKind ?? .unblock)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    if isReadOnly {
                        Text(name)
                    } else {
                        TextField("e.g. Office Keycard", text: $name)
                            .accessibilityIdentifier("key.nameField")
                    }
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
                        Button {
                            if !isReadOnly { showKeyTypeLockedAlert = true }
                        } label: {
                            HStack {
                                Label(keyType.label, systemImage: keyType.icon)
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isReadOnly)
                    }

                    if keyType == .location, let existing, existing.coordinate != nil {
                        Section("Location") {
                            LocationKeyMapPreview(key: existing)
                                .listRowInsets(EdgeInsets())
                            if let radius = existing.radiusMeters {
                                LabeledContent("Radius", value: LocationFormat.distance(meters: radius))
                            }
                        }
                    }

                    if !isNew, !isReadOnly {
                        Section {
                            Button(role: .destructive, action: attemptDelete) {
                                Text("Delete Key")
                                    .frame(maxWidth: .infinity)
                            }
                            .accessibilityIdentifier("key.deleteButton")
                        }
                    }

                    if isReadOnly {
                        Section {} footer: {
                            Text(BlockedMessage.keys)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isReadOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.fontWeight(.semibold)
                    }
                } else {
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
                LocationPickerSheet(kind: radiusKind, groupID: groupID) { latitude, longitude, radius in
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
            .deleteConfirmation(
                title: "Delete Key?",
                itemName: existing?.name ?? name,
                isPresented: $showDeleteConfirmation,
                onDelete: deleteKey
            )
            .alert("Can't Delete Key", isPresented: $showLastKeyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("At least one key must exist. Add another key before deleting this one.")
            }
            .alert("Can't Change Key Type", isPresented: $showKeyTypeLockedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Keys cannot be re-assigned once created. Please create a new key instead and delete this one.")
            }
        }
    }

    private func attemptDelete() {
        if isLastKey {
            showLastKeyAlert = true
        } else {
            showDeleteConfirmation = true
        }
    }

    private func deleteKey() {
        guard let existing, keys.count > 1 else { return }
        modelContext.delete(existing)
        dismiss()
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing {
            existing.name = trimmed
        } else {
            let peers = keys.filter { $0.groupID == groupID }
            let nextIndex = SortIndexing.nextIndex(after: peers, sortIndex: \.sortIndex)
            switch keyType {
            case .nfc, .qr:
                guard let rawValue = scannedKeyId else { return }
                modelContext.insert(Key(
                    name: trimmed,
                    type: keyType,
                    rawValue: rawValue,
                    scanKind: scannedKind,
                    sortIndex: nextIndex,
                    groupID: groupID
                ))
            case .location:
                guard let captured = capturedLocation else { return }
                modelContext.insert(Key(
                    name: trimmed,
                    latitude: captured.latitude,
                    longitude: captured.longitude,
                    radiusMeters: captured.radiusMeters,
                    radiusKind: captured.kind,
                    sortIndex: nextIndex,
                    groupID: groupID
                ))
            }
        }
        dismiss()
    }
}
