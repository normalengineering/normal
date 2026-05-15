import SwiftData
import SwiftUI

struct KeySelectModifier: ViewModifier {
    @Environment(KeyManager.self) private var keyManager
    @Environment(NFCService.self) private var nfcService
    @Environment(QRService.self) private var qrService
    @Query private var keys: [Key]

    @Binding var action: (@MainActor () -> Void)?
    var allowBypass: Bool
    var defaultKeyType: KeyType?

    @State private var showKeySelect = false
    @State private var showQRScanner = false
    @State private var showNoKeysAlert = false
    @State private var actionTrigger = false

    private var availableKeyTypes: [KeyType] {
        KeyType.availableOnDevice.filter { type in keys.contains { $0.type == type } }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: actionTrigger) { _, _ in
                guard action != nil else { return }
                applyDecision()
            }
            .onChange(of: action != nil) { _, hasAction in
                if hasAction { actionTrigger.toggle() }
            }
            .alert("No Keys Available", isPresented: $showNoKeysAlert) {
                Button("OK", role: .cancel) { action = nil }
            } message: {
                Text(
                    keys.isEmpty
                        ? "Add a key in the Keys tab before blocking apps."
                        : "None of your registered keys are supported on this device. Add a QR code key to use on iPad."
                )
            }
            .sheet(isPresented: $showKeySelect, onDismiss: onSheetDismiss) {
                keySelectSheet
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
                                showKeySelect = false
                            }
                        }
                    }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showKeySelect = false }
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
            showKeySelect = true
        }
    }

    private func handleSelection(_ choice: KeyType) {
        switch choice {
        case .nfc:
            showKeySelect = false
            Task { await authenticate(with: .nfc) }
        case .qr:
            showQRScanner = true
            Task { await authenticate(with: .qr) }
        }
    }

    private func bypassNow() {
        action?()
        action = nil
        showKeySelect = false
    }

    private func authenticate(with choice: KeyType) async {
        guard let pendingAction = action else { return }
        let method: KeyMethod = switch choice {
        case .nfc: NFCKeyMethod(nfcService: nfcService, keys: keys)
        case .qr: QRKeyMethod(qrService: qrService, keys: keys)
        }
        _ = await keyManager.performWithKeyCheck(using: method) { pendingAction() }
        showKeySelect = false
        action = nil
    }

    private func onSheetDismiss() {
        if qrService.isScanning { qrService.cancel() }
        action = nil
    }
}

extension View {
    func keySelect(
        action: Binding<(@MainActor () -> Void)?>,
        allowBypass: Bool = false,
        defaultKeyType: KeyType? = nil
    ) -> some View {
        modifier(KeySelectModifier(action: action, allowBypass: allowBypass, defaultKeyType: defaultKeyType))
    }
}
