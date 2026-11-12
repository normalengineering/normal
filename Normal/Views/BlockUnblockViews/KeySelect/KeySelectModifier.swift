import SwiftData
import SwiftUI

struct KeySelectModifier: ViewModifier {
    @Environment(KeyManager.self) private var keyManager
    @Environment(NFCService.self) private var nfcService
    @Environment(QRService.self) private var qrService
    @Environment(LocationService.self) private var locationService
    @Query private var keys: [Key]
    @Query private var allSettings: [Settings]

    @Binding var action: (@MainActor () -> Void)?
    var allowBypass: Bool
    var defaultKeyType: KeyType?
    var keyGroupID: UUID?
    var requestID: UUID?

    @State private var flowID = UUID()
    @State private var keySelectToken: PresentationToken?
    @State private var locationCheck: LocationCheck?
    @State private var pendingLocationCheck: LocationCheck?
    @State private var presentedLocationFlowID: UUID?
    @State private var locationAction: (@MainActor () -> Void)?
    @State private var qrScanFlowID: UUID?
    @State private var showQRScanner = false
    @State private var showNoKeysAlert = false
    @State private var showBypassConfirm = false

    private struct PresentationToken: Identifiable {
        let id = UUID()
    }

    private struct LocationCheck: Identifiable {
        let id = UUID()
        let flowID: UUID
        let keys: [Key]
    }

    private struct Trigger: Equatable {
        let hasAction: Bool
        let requestID: UUID?
    }

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var scopedKeys: [Key] {
        Key.scoped(keys, toGroup: keyGroupID)
    }

    private var availableKeyTypes: [KeyType] {
        KeyType.selectable(registered: scopedKeys.map(\.type))
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: Trigger(hasAction: action != nil, requestID: requestID)) { _, trigger in
                if trigger.hasAction {
                    startFlow()
                }
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
            .sheet(item: $locationCheck, onDismiss: finishLocation) { check in
                LocationUnlockSheet(
                    keys: check.keys,
                    provider: locationService,
                    onVerified: { verifyLocation(check) }
                )
            }
    }

    private var keySelectSheet: some View {
        NavigationStack {
            KeySelectView(
                availableKeyTypes: availableKeyTypes,
                allowBypass: allowBypass,
                onSelect: handleSelection,
                onBypass: requestBypass
            )
            .navigationDestination(isPresented: $showBypassConfirm) {
                BypassConfirmView { skipFuture in
                    if skipFuture {
                        settings.skipBlockWithoutKeyConfirmation = true
                    }
                    bypassNow()
                }
            }
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
        .presentationDetents(sheetDetents)
        .presentationDragIndicator(showBypassConfirm ? .visible : .hidden)
    }

    private var sheetDetents: Set<PresentationDetent> {
        if showQRScanner {
            return [.large]
        }
        return [.medium]
    }

    private func startFlow() {
        pendingLocationCheck = nil
        locationCheck = nil
        locationAction = nil
        if qrScanFlowID != nil {
            qrService.cancel()
        }
        flowID = UUID()
        applyDecision()
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
            showBypassConfirm = false
            keySelectToken = PresentationToken()
        }
    }

    private func requestBypass() {
        if settings.skipBlockWithoutKeyConfirmation {
            bypassNow()
        } else {
            showBypassConfirm = true
        }
    }

    private func handleSelection(_ choice: KeyType) {
        switch choice {
        case .nfc:
            let pending = action
            keySelectToken = nil
            Task { await authenticate(with: .nfc, action: pending) }
        case .qr:
            guard qrScanFlowID != flowID else { return }
            qrScanFlowID = flowID
            let pending = action
            showQRScanner = true
            Task { await authenticate(with: .qr, action: pending) }
        case .location:
            locationAction = action
            let check = LocationCheck(flowID: flowID, keys: scopedKeys)
            if keySelectToken != nil {
                pendingLocationCheck = check
                keySelectToken = nil
            } else {
                present(check)
            }
        }
    }

    private func present(_ check: LocationCheck) {
        presentedLocationFlowID = check.flowID
        locationCheck = check
    }

    private func verifyLocation(_ check: LocationCheck) {
        guard check.flowID == flowID else { return }
        locationAction?()
    }

    /// Leaves `showBypassConfirm` alone: flipping it here would swap the key
    /// picker back in while the sheet is still animating away.
    private func bypassNow() {
        guard allowBypass else { return }
        action?()
        action = nil
        keySelectToken = nil
    }

    private func authenticate(with choice: KeyType, action pending: (@MainActor () -> Void)?) async {
        guard let pending else { return }
        let flow = flowID
        let method: KeyMethod = switch choice {
        case .nfc: NFCKeyMethod(nfcService: nfcService, keys: scopedKeys)
        case .qr: QRKeyMethod(qrService: qrService, keys: scopedKeys)
        case .location: preconditionFailure("location uses its own popup")
        }
        _ = await keyManager.performWithKeyCheck(using: method) { pending() }
        if qrScanFlowID == flow {
            qrScanFlowID = nil
        }
        guard flow == flowID else { return }
        keySelectToken = nil
        action = nil
    }

    private func onSheetDismiss() {
        guard keySelectToken == nil else { return }
        if qrService.isScanning {
            qrService.cancel()
        }

        if let pending = pendingLocationCheck {
            pendingLocationCheck = nil
            present(pending)
            return
        }
        action = nil
    }

    private func finishLocation() {
        guard locationCheck == nil, presentedLocationFlowID == flowID else { return }
        locationAction = nil
        action = nil
    }
}

extension View {
    func keySelect(
        action: Binding<(@MainActor () -> Void)?>,
        allowBypass: Bool = false,
        defaultKeyType: KeyType? = nil,
        keyGroupID: UUID? = nil,
        requestID: UUID? = nil
    ) -> some View {
        modifier(KeySelectModifier(
            action: action,
            allowBypass: allowBypass,
            defaultKeyType: defaultKeyType,
            keyGroupID: keyGroupID,
            requestID: requestID
        ))
    }
}
