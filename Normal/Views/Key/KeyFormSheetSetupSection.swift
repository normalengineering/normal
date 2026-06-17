import SwiftData
import SwiftUI

struct KeyFormSheetSetupSection: View {
    @Environment(NFCService.self) private var nfcService
    @Environment(QRService.self) private var qrService
    @Query private var keys: [Key]

    @Binding var keyType: KeyType
    @Binding var scannedKeyId: String?
    @Binding var scannedKind: ScanCodeKind?
    @Binding var radiusKind: LocationRadiusKind
    @Binding var capturedLocation: CapturedLocation?
    @Binding var showQRScanner: Bool
    @Binding var showLocationPicker: Bool

    private var hasMultipleTypes: Bool {
        KeyType.availableOnDevice.count > 1
    }

    private var lockedKind: LocationRadiusKind? {
        Key.existingLocationKind(in: keys)
    }

    var body: some View {
        Section("Setup") {
            if hasMultipleTypes { typePickerStep }
            switch keyType {
            case .nfc, .qr: scanStep
            case .location: locationStep
            }
        }
        .onAppear {
            if let lockedKind { radiusKind = lockedKind }
        }

        if keyType == .location {
            Section {
                unlockAnywhereNote
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var typePickerStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            stepLabel(number: 1, title: "Choose Type")
            Picker("Type", selection: $keyType) {
                ForEach(KeyType.availableOnDevice) { type in
                    Label(type.shortLabel, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: keyType) { _, _ in
                scannedKeyId = nil
                scannedKind = nil
                capturedLocation = nil
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var scanStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            stepLabel(number: hasMultipleTypes ? 2 : 1, title: "Scan")
            Button(action: handleScan) { scanButtonContent }
                .buttonStyle(.plain)
                .accessibilityIdentifier("key.scanButton")
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            stepLabel(number: hasMultipleTypes ? 2 : 1, title: "Radius Type")
            if let lockedKind {
                lockedKindRow(lockedKind)
            } else {
                Picker("Radius Type", selection: $radiusKind) {
                    ForEach(LocationRadiusKind.allCases) { kind in
                        Text(kind.shortLabel).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: radiusKind) { _, _ in capturedLocation = nil }
            }
            Text(radiusKind.pickerFooter)
                .font(.caption)
                .foregroundStyle(.secondary)

            stepLabel(number: hasMultipleTypes ? 3 : 2, title: "Set Location")
            Button { showLocationPicker = true } label: { locationButtonContent }
                .buttonStyle(.plain)
                .accessibilityIdentifier("key.locationButton")
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private var unlockAnywhereNote: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text("Location keys still require you to unblock selected apps/groups by opening the Normal app and unblocking. Your NFC and QR keys will still work from anywhere!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(Color.blue.opacity(DS.Opacity.subtle))
        .cornerRadius(DS.Radius.md)
    }

    private func lockedKindRow(_ kind: LocationRadiusKind) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Label(kind.label, systemImage: kind.icon)
                    .foregroundStyle(kind.zoneColor)
                Spacer()
                Image(systemName: "lock.fill").foregroundStyle(.tertiary)
            }
            .font(.subheadline.weight(.medium))
            Text("You currently have \(kind.label) keys. You can only have one type of location key at a time. To change the type, delete all existing location keys of this type.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.zoneColor.opacity(DS.Opacity.subtle))
        .cornerRadius(DS.Radius.md)
    }

    private var locationButtonContent: some View {
        HStack {
            Image(systemName: KeyType.location.icon).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(capturedLocation != nil ? "Location Set" : "Pick on Map")
                    .font(.headline)
                if let captured = capturedLocation {
                    Text("Radius: \(LocationFormat.distance(meters: captured.radiusMeters))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if capturedLocation != nil {
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
            (capturedLocation != nil ? Color.green : Color.accentColor).opacity(DS.Opacity.subtle)
        )
        .cornerRadius(DS.Radius.md)
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
                let kind: ScanCodeKind?
                switch keyType {
                case .nfc:
                    id = try await nfcService.scan()
                    kind = nil
                case .qr:
                    showQRScanner = true
                    id = try await qrService.scan()
                    showQRScanner = false
                    kind = qrService.lastScanCodeKind
                case .location:
                    return
                }
                withAnimation(.spring()) {
                    scannedKeyId = id
                    scannedKind = kind
                }
            } catch {
                showQRScanner = false
            }
        }
    }
}
