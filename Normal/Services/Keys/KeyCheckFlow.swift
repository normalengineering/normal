import Foundation
import Observation

@Observable
final class KeyCheckFlow {
    struct Request {
        let id = UUID()
        let keys: [Key]
        let keyGroupID: UUID?
        let availableKeyTypes: [KeyType]
        let defaultKeyType: KeyType?
        var requestedKeyType: KeyType?
    }

    enum Stage: Equatable {
        case idle
        case noKeys
        case choosing
        case confirmingBypass
        case scanningQR
        case scanningNFC
        case checkingLocation
    }

    enum SheetScreen: Equatable {
        case picker
        case bypassConfirm
        case qrScanner
        case location
    }

    struct LocationCheck {
        let requestID: UUID
        let keys: [Key]
    }

    private struct Scan {
        let id: UUID
        let keyType: KeyType
        let task: Task<Void, Never>
    }

    private(set) var stage: Stage = .idle
    private(set) var request: Request?
    private(set) var allowsBypass = false
    private(set) var sheetScreen: SheetScreen = .picker
    private(set) var finishedRequestID: UUID?
    private(set) var locationCheck: LocationCheck?
    private var nfcOverPicker = false
    private var nfcChosenFromPicker = false

    var canReturnToPicker: Bool {
        allowsBypass || (request?.availableKeyTypes.count ?? 0) > 1
    }

    var showsKeySheet: Bool {
        switch stage {
        case .choosing, .confirmingBypass, .scanningQR, .checkingLocation: true
        case .scanningNFC: nfcOverPicker
        case .idle, .noKeys: false
        }
    }

    var keySheetIsMinimized: Bool {
        stage == .scanningNFC && !nfcChosenFromPicker
    }

    private let nfc: any CancellableKeyScanning
    private let qr: any CancellableKeyScanning
    @ObservationIgnored private var scan: Scan?
    @ObservationIgnored private var action: ProtectedAction?

    init(nfc: any CancellableKeyScanning, qr: any CancellableKeyScanning) {
        self.nfc = nfc
        self.qr = qr
    }

    func start(_ request: Request, action: ProtectedAction) {
        stopScan()
        self.request = request
        self.action = action
        allowsBypass = action.allowsBypass
        switch KeySelectLogic.decide(
            availableKeyTypes: request.availableKeyTypes,
            allowBypass: allowsBypass,
            defaultKeyType: request.defaultKeyType,
            requestedKeyType: request.requestedKeyType
        ) {
        case .showNoKeysAlert:
            stage = .noKeys
        case let .autoSelect(keyType):
            begin(keyType, fromPicker: false)
        case .showSheet:
            sheetScreen = .picker
            stage = .choosing
        }
    }

    func choose(_ keyType: KeyType) {
        guard stage == .choosing else { return }
        begin(keyType, fromPicker: true)
    }

    func requestBypass(skippingConfirmation: Bool) {
        guard stage == .choosing, allowsBypass else { return }
        if skippingConfirmation {
            complete(with: nil)
        } else {
            sheetScreen = .bypassConfirm
            stage = .confirmingBypass
        }
    }

    func confirmBypass() {
        guard stage == .confirmingBypass, allowsBypass else { return }
        complete(with: nil)
    }

    func returnFromBypassConfirm() {
        guard stage == .confirmingBypass else { return }
        sheetScreen = .picker
        stage = .choosing
    }

    func scannerAppeared() {
        guard stage == .scanningQR, scan == nil, let request else { return }
        check(QRKeyMethod(qrService: qr, keys: request.keys), keyType: .qr)
    }

    func promptCancelled() {
        guard stage == .scanningQR || stage == .checkingLocation else { return }
        promptEnded()
    }

    func locationVerified(requestID: UUID) {
        guard stage == .checkingLocation, let request, request.id == requestID else { return }
        complete(with: KeyProof(keyGroupID: request.keyGroupID))
    }

    func showMinimizedPicker() {
        guard stage == .scanningNFC, canReturnToPicker else { return }
        nfcOverPicker = true
    }

    func keySheetClosed() {
        guard showsKeySheet else { return }
        cancel()
    }

    func keySheetDismissed() {
        guard !showsKeySheet else { return }
        if qr.isScanning {
            qr.cancel()
        }
        if scan?.keyType == .qr {
            scan = nil
        }
    }

    func cancel() {
        stopScan()
        finish()
    }

    func hostCleared() {
        guard stage != .idle else { return }
        stopScan()
        stage = .idle
        request = nil
        action = nil
        allowsBypass = false
    }

    private func begin(_ keyType: KeyType, fromPicker: Bool) {
        guard let request else { return }
        switch keyType {
        case .nfc:
            nfcChosenFromPicker = fromPicker
            nfcOverPicker = fromPicker
            sheetScreen = .picker
            stage = .scanningNFC
            check(NFCKeyMethod(nfcService: nfc, keys: request.keys), keyType: .nfc)
        case .qr:
            sheetScreen = .qrScanner
            stage = .scanningQR
        case .location:
            locationCheck = LocationCheck(requestID: request.id, keys: request.keys)
            sheetScreen = .location
            stage = .checkingLocation
        }
    }

    private func check(_ method: some KeyMethod, keyType: KeyType) {
        let id = UUID()
        let task = Task {
            let result = await method.checkKey()
            scanFinished(result, scanID: id)
        }
        scan = Scan(id: id, keyType: keyType, task: task)
    }

    private func scanFinished(_ result: KeyResult, scanID: UUID) {
        guard scan?.id == scanID, let request else { return }
        scan = nil
        if result == .success {
            complete(with: KeyProof(keyGroupID: request.keyGroupID))
        } else {
            promptEnded()
        }
    }

    private func promptEnded() {
        if canReturnToPicker {
            showPicker()
        } else {
            cancel()
        }
    }

    private func showPicker() {
        stopScan()
        sheetScreen = .picker
        stage = .choosing
    }

    private func complete(with proof: KeyProof?) {
        action?.run(with: proof)
        finish()
    }

    private func finish() {
        finishedRequestID = request?.id
        stage = .idle
        request = nil
        action = nil
        allowsBypass = false
    }

    private func stopScan() {
        guard let scan else { return }
        self.scan = nil
        scan.task.cancel()
        switch scan.keyType {
        case .nfc: nfc.cancel()
        case .qr: qr.cancel()
        case .location: break
        }
    }
}
