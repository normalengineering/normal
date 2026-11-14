import SwiftData
import SwiftUI

struct KeySelectModifier: ViewModifier {
    @Environment(QRService.self) private var qrService
    @Environment(LocationService.self) private var locationService
    @Query private var keys: [Key]
    @Query private var allSettings: [Settings]

    @Binding var action: ProtectedAction?
    var defaultKeyType: KeyType?
    var requestedKeyType: KeyType?
    var keyGroupID: UUID?
    var requestID: UUID?

    @State private var flow = KeyCheckFlow(nfc: NFCService.shared, qr: QRService.shared)
    @State private var keepsMinimizedDetent = false

    private static let minimizedDetent = PresentationDetent.height(88)
    private static let sheetResizeTime: Duration = .seconds(1)
    private static let nfcPopupRiseTime: Duration = .milliseconds(500)

    private struct SheetID: Identifiable {
        let id: UUID
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                guard flow.stage == .scanningNFC else { return }
                Task {
                    try? await Task.sleep(for: Self.nfcPopupRiseTime)
                    flow.showMinimizedPicker()
                }
            }
            .onChange(of: flow.keySheetIsMinimized) { _, minimized in
                if minimized {
                    keepsMinimizedDetent = true
                } else {
                    Task {
                        try? await Task.sleep(for: Self.sheetResizeTime)
                        keepsMinimizedDetent = flow.keySheetIsMinimized
                    }
                }
            }
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
    }

    private var keySelectSheet: some View {
        NavigationStack {
            KeySelectView(
                availableKeyTypes: flow.request?.availableKeyTypes ?? [],
                allowBypass: flow.allowsBypass,
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
                            Button("Cancel", action: flow.promptCancelled)
                        }
                    }
                    .onAppear(perform: flow.scannerAppeared)
            }
            .navigationDestination(isPresented: screen(.location, onBack: {})) {
                if let check = flow.locationCheck {
                    LocationUnlockView(
                        keys: check.keys,
                        provider: locationService,
                        onVerified: { flow.locationVerified(requestID: check.requestID) },
                        onClose: flow.promptCancelled
                    )
                    .id(check.requestID)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: flow.cancel)
                }
            }
        }
        .presentationDetents(sheetDetents, selection: Binding(get: { sheetDetent }, set: { _ in }))
        .presentationBackgroundInteraction(
            allowsMinimizedDetent ? .enabled(upThrough: Self.minimizedDetent) : .automatic
        )
        .presentationDragIndicator(flow.sheetScreen == .bypassConfirm ? .visible : .hidden)
    }

    private var sheetDetent: PresentationDetent {
        if flow.keySheetIsMinimized {
            return Self.minimizedDetent
        }
        return [.qrScanner, .location].contains(flow.sheetScreen) ? .large : .medium
    }

    private var allowsMinimizedDetent: Bool {
        keepsMinimizedDetent && flow.sheetScreen == .picker
    }

    private var sheetDetents: Set<PresentationDetent> {
        allowsMinimizedDetent ? [sheetDetent, Self.minimizedDetent] : [sheetDetent]
    }

    private var noKeysAlert: Binding<Bool> {
        Binding(
            get: { flow.stage == .noKeys },
            set: { if !$0 { flow.cancel() } }
        )
    }

    private var keySheet: Binding<SheetID?> {
        Binding(
            get: { flow.showsKeySheet ? flow.request.map { SheetID(id: $0.id) } : nil },
            set: { if $0 == nil { flow.keySheetClosed() } }
        )
    }

    private func screen(_ screen: KeyCheckFlow.SheetScreen, onBack: @escaping () -> Void) -> Binding<Bool> {
        Binding(
            get: { flow.sheetScreen == screen },
            set: { if !$0 { onBack() } }
        )
    }

    private func start() {
        guard let action else { return }
        let scopedKeys = Key.scoped(keys, toGroup: keyGroupID)
        flow.start(
            KeyCheckFlow.Request(
                keys: scopedKeys,
                keyGroupID: keyGroupID,
                availableKeyTypes: KeyType.selectable(registered: scopedKeys.map(\.type)),
                defaultKeyType: defaultKeyType,
                requestedKeyType: requestedKeyType
            ),
            action: action
        )
    }
}

extension View {
    func keySelect(
        action: Binding<ProtectedAction?>,
        defaultKeyType: KeyType? = nil,
        requestedKeyType: KeyType? = nil,
        keyGroupID: UUID? = nil,
        requestID: UUID? = nil
    ) -> some View {
        modifier(KeySelectModifier(
            action: action,
            defaultKeyType: defaultKeyType,
            requestedKeyType: requestedKeyType,
            keyGroupID: keyGroupID,
            requestID: requestID
        ))
    }
}
