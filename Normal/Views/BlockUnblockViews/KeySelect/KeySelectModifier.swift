import SwiftData
import SwiftUI

struct KeySelectModifier: ViewModifier {
    @Environment(KeyManager.self) private var keyManager
    @Environment(NFCService.self) private var nfcService
    @Environment(QRService.self) private var qrService
    @Environment(LocationService.self) private var locationService
    @Query private var keys: [Key]

    @Binding var action: (@MainActor () -> Void)?
    var allowBypass: Bool
    var defaultKeyType: KeyType?
    var keyGroupID: UUID?

    @State private var keySelectToken: PresentationToken?
    @State private var locationToken: PresentationToken?
    @State private var showQRScanner = false
    @State private var showNoKeysAlert = false
    @State private var pendingLocationAction: (@MainActor () -> Void)?

    private struct PresentationToken: Identifiable {
        let id = UUID()
    }

    private var scopedKeys: [Key] {
        Key.scoped(keys, toGroup: keyGroupID)
    }

    private var availableKeyTypes: [KeyType] {
        KeyType.selectable(registered: scopedKeys.map(\.type))
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: action != nil) { _, hasAction in
                if hasAction { applyDecision() }
            }
            .alert("No Keys Available", isPresented: $showNoKeysAlert) {
                Button("OK", role: .cancel) { action = nil }
            } message: {
                Text(
                    scopedKeys.isEmpty
                        ? "Add a key in the Keys tab before blocking apps."
                        : "None of your registered keys are supported on this device. Add a QR code or barcode key to use on iPad."
                )
            }
            .sheet(item: $keySelectToken, onDismiss: onSheetDismiss) { _ in
                keySelectSheet
            }
            .sheet(item: $locationToken, onDismiss: finishLocation) { _ in
                LocationUnlockSheet(
                    keys: scopedKeys,
                    provider: locationService,
                    onVerified: { pendingLocationAction?() }
                )
            }
    }

    private var keySelectSheet: some View {
        NavigationStack {
            KeySelectView(
                availableKeyTypes: availableKeyTypes,
                allowBypass: allowBypass,
                onSelect: handleSelection,
                onBypass: bypassNow
            )
            .navigationDestination(isPresented: $showQRScanner) {
                QRScannerView(qrService: qrService)
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                qrService.cancel()
                                keySelectToken = nil
                            }
                        }
                    }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { keySelectToken = nil }
                }
            }
        }
        .presentationDetents(showQRScanner ? [.large] : [.medium])
        .presentationDragIndicator(.hidden)
    }

    private func applyDecision() {
        let decision = KeySelectLogic.decide(
            availableKeyTypes: availableKeyTypes,
            allowBypass: allowBypass,
            defaultKeyType: defaultKeyType
        )
        switch decision {
        case .showNoKeysAlert:
            showNoKeysAlert = true
        case let .autoSelect(keyType):
            handleSelection(keyType)
        case .showSheet:
            showQRScanner = false
            keySelectToken = PresentationToken()
        }
    }

    private func handleSelection(_ choice: KeyType) {
        switch choice {
        case .nfc:
            let pending = action
            keySelectToken = nil
            Task { await authenticate(with: .nfc, action: pending) }
        case .qr:
            let pending = action
            showQRScanner = true
            Task { await authenticate(with: .qr, action: pending) }
        case .location:
            pendingLocationAction = action
            if keySelectToken != nil {
                keySelectToken = nil
            } else {
                locationToken = PresentationToken()
            }
        }
    }

    private func bypassNow() {
        action?()
        action = nil
        keySelectToken = nil
    }

    private func authenticate(with choice: KeyType, action pending: (@MainActor () -> Void)?) async {
        guard let pending else { return }
        let method: KeyMethod = switch choice {
        case .nfc: NFCKeyMethod(nfcService: nfcService, keys: scopedKeys)
        case .qr: QRKeyMethod(qrService: qrService, keys: scopedKeys)
        case .location: preconditionFailure("location uses its own popup")
        }
        _ = await keyManager.performWithKeyCheck(using: method) { pending() }
        keySelectToken = nil
        action = nil
    }

    private func onSheetDismiss() {
        if qrService.isScanning { qrService.cancel() }

        if pendingLocationAction != nil {
            locationToken = PresentationToken()
            return
        }
        action = nil
    }

    private func finishLocation() {
        pendingLocationAction = nil
        action = nil
    }
}

extension View {
    func keySelect(
        action: Binding<(@MainActor () -> Void)?>,
        allowBypass: Bool = false,
        defaultKeyType: KeyType? = nil,
        keyGroupID: UUID? = nil
    ) -> some View {
        modifier(KeySelectModifier(
            action: action,
            allowBypass: allowBypass,
            defaultKeyType: defaultKeyType,
            keyGroupID: keyGroupID
        ))
    }
}
