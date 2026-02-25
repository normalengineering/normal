import SwiftData
import SwiftUI

struct KeySelectModifier: ViewModifier {
    @Environment(KeyManager.self) private var keyManager
    @Environment(NFCService.self) private var nfcService
    @Environment(QRService.self) private var qrService
    @Query private var keys: [Key]

    @Binding var action: (@MainActor () -> Void)?
    var allowBypass: Bool

    @State private var showKeySelect = false
    @State private var showQRScanner = false
    @State private var showNoKeysAlert = false
    @State private var actionTrigger = false

    func body(content: Content) -> some View {
        content
            .onChange(of: actionTrigger) { _, _ in
                if action != nil {
                    if keys.isEmpty {
                        showNoKeysAlert = true
                    } else {
                        showQRScanner = false
                        showKeySelect = true
                    }
                }
            }
            .onChange(of: action != nil) { _, hasAction in
                if hasAction {
                    actionTrigger.toggle()
                }
            }
            .alert("No Keys", isPresented: $showNoKeysAlert) {
                Button("OK", role: .cancel) {
                    action = nil
                }
            } message: {
                Text("Add a key in the Keys tab before blocking apps.")
            }
            .sheet(isPresented: $showKeySelect, onDismiss: onSheetDismiss) {
                NavigationStack {
                    KeySelectView(
                        allowBypass: allowBypass,
                        onSelect: { choice in handleSelection(choice) },
                        onBypass: {
                            action?()
                            action = nil
                            showKeySelect = false
                        }
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

    private func authenticate(with choice: KeyType) async {
        guard let pendingAction = action else { return }

        let method: KeyMethod = switch choice {
        case .nfc: NFCKeyMethod(nfcService: nfcService, keys: keys)
        case .qr:  QRKeyMethod(qrService: qrService, keys: keys)
        }

        _ = await keyManager.performWithKeyCheck(using: method) {
            pendingAction()
        }

        showKeySelect = false
        action = nil
    }

    private func onSheetDismiss() {
        if qrService.isScanning {
            qrService.cancel()
        }
        action = nil
    }
}

extension View {
    func keySelect(
        action: Binding<(@MainActor () -> Void)?>,
        allowBypass: Bool = false
    ) -> some View {
        modifier(KeySelectModifier(action: action, allowBypass: allowBypass))
    }
}
