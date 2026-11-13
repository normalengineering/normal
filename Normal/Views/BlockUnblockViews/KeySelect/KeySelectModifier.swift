import SwiftData
import SwiftUI

struct KeySelectModifier: ViewModifier {
    @Environment(QRService.self) private var qrService
    @Environment(LocationService.self) private var locationService
    @Query private var keys: [Key]
    @Query private var allSettings: [Settings]

    @Binding var action: (@MainActor () -> Void)?
    var allowBypass: Bool
    var defaultKeyType: KeyType?
    var keyGroupID: UUID?
    var requestID: UUID?

    @State private var flow = KeyCheckFlow(nfc: NFCService.shared, qr: QRService.shared)

    private struct SheetID: Identifiable {
        let id: UUID
    }

    private struct LocationCheck: Identifiable {
        let id: UUID
        let keys: [Key]
    }

    private struct Trigger: Equatable {
        let hasAction: Bool
        let requestID: UUID?
    }

    private var settings: Settings {
        allSettings.unwrapped
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: Trigger(hasAction: action != nil, requestID: requestID)) { _, trigger in
                if trigger.hasAction {
                    start()
                } else {
                    flow.hostCleared()
                }
            }
            .onChange(of: flow.finishedRequestID) { _, _ in action = nil }
            .alert("No Keys Available", isPresented: noKeysAlert) {
                Button("OK", role: .cancel) { flow.cancel() }
            } message: {
                Text(
                    flow.request?.keys.isEmpty ?? true
                        ? "Add a key in the Keys tab before blocking apps."
                        : "None of your registered keys are supported on this device. Add a QR code or barcode key to use on iPad."
                )
            }
            .sheet(item: keySheet, onDismiss: flow.keySheetDismissed) { _ in
                keySelectSheet
            }
            .sheet(item: locationSheet) { check in
                LocationUnlockSheet(
                    keys: check.keys,
                    provider: locationService,
                    onVerified: { flow.locationVerified(requestID: check.id) }
                )
            }
    }

    private var keySelectSheet: some View {
        NavigationStack {
            KeySelectView(
                availableKeyTypes: flow.request?.availableKeyTypes ?? [],
                allowBypass: flow.request?.allowBypass ?? false,
                onSelect: flow.choose,
                onBypass: { flow.requestBypass(skippingConfirmation: settings.skipBlockWithoutKeyConfirmation) }
            )
            .navigationDestination(isPresented: screen(.bypassConfirm, onBack: flow.returnFromBypassConfirm)) {
                BypassConfirmView { skipFuture in
                    if skipFuture {
                        settings.skipBlockWithoutKeyConfirmation = true
                    }
                    flow.confirmBypass()
                }
            }
            .navigationDestination(isPresented: screen(.qrScanner, onBack: {})) {
                QRScannerView(qrService: qrService)
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel", action: flow.cancel)
                        }
                    }
                    .onAppear(perform: flow.scannerAppeared)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: flow.cancel)
                }
            }
        }
        .presentationDetents(flow.sheetScreen == .qrScanner ? [.large] : [.medium])
        .presentationDragIndicator(flow.sheetScreen == .bypassConfirm ? .visible : .hidden)
    }

    private var noKeysAlert: Binding<Bool> {
        Binding(
            get: { flow.stage == .noKeys },
            set: { if !$0 { flow.cancel() } }
        )
    }

    private var keySheet: Binding<SheetID?> {
        Binding(
            get: { flow.stage.showsKeySheet ? flow.request.map { SheetID(id: $0.id) } : nil },
            set: { if $0 == nil { flow.keySheetClosed() } }
        )
    }

    private var locationSheet: Binding<LocationCheck?> {
        Binding(
            get: {
                guard flow.stage == .checkingLocation, let request = flow.request else { return nil }
                return LocationCheck(id: request.id, keys: request.keys)
            },
            set: { if $0 == nil { flow.locationSheetClosed() } }
        )
    }

    private func screen(_ screen: KeyCheckFlow.SheetScreen, onBack: @escaping () -> Void) -> Binding<Bool> {
        Binding(
            get: { flow.sheetScreen == screen },
            set: { if !$0 { onBack() } }
        )
    }

    private func start() {
        let scopedKeys = Key.scoped(keys, toGroup: keyGroupID)
        flow.start(
            KeyCheckFlow.Request(
                keys: scopedKeys,
                availableKeyTypes: KeyType.selectable(registered: scopedKeys.map(\.type)),
                allowBypass: allowBypass,
                defaultKeyType: defaultKeyType
            ),
            action: action
        )
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
