import Foundation
import Observation

protocol QRScanning: KeyScanning {
    var isScanning: Bool { get }
    func cancel()
}

extension QRService: QRScanning {}

@Observable
final class KeyCheckFlow {
    struct Request {
        let id = UUID()
        let keys: [Key]
        let availableKeyTypes: [KeyType]
        let allowBypass: Bool
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
        case openingLocation
        case checkingLocation

        var showsKeySheet: Bool {
            switch self {
            case .choosing, .confirmingBypass, .scanningQR: true
            default: false
            }
        }
    }

    enum SheetScreen: Equatable {
        case picker
        case bypassConfirm
        case qrScanner
    }

    private(set) var stage: Stage = .idle
    private(set) var request: Request?
    private(set) var sheetScreen: SheetScreen = .picker
    private(set) var finishedRequestID: UUID?

    private let nfc: any KeyScanning
    private let qr: any QRScanning
    @ObservationIgnored private var qrScanRequestID: UUID?
    @ObservationIgnored private var action: (@MainActor () -> Void)?

    init(nfc: any KeyScanning, qr: any QRScanning) {
        self.nfc = nfc
        self.qr = qr
    }

    func start(_ request: Request, action: (@MainActor () -> Void)?) {
        stopQRScan()
        self.request = request
        self.action = action
        switch KeySelectLogic.decide(
            availableKeyTypes: request.availableKeyTypes,
            allowBypass: request.allowBypass,
            defaultKeyType: request.defaultKeyType,
            requestedKeyType: request.requestedKeyType
        ) {
        case .showNoKeysAlert:
            stage = .noKeys
        case let .autoSelect(keyType):
            begin(keyType)
        case .showSheet:
            sheetScreen = .picker
            stage = .choosing
        }
    }

    func choose(_ keyType: KeyType) {
        guard stage == .choosing else { return }
        begin(keyType)
    }

    func requestBypass(skippingConfirmation: Bool) {
        guard stage == .choosing, request?.allowBypass == true else { return }
        if skippingConfirmation {
            complete()
        } else {
            sheetScreen = .bypassConfirm
            stage = .confirmingBypass
        }
    }

    func confirmBypass() {
        guard stage == .confirmingBypass, request?.allowBypass == true else { return }
        complete()
    }

    func returnFromBypassConfirm() {
        guard stage == .confirmingBypass else { return }
        sheetScreen = .picker
        stage = .choosing
    }

    func scannerAppeared() {
        guard stage == .scanningQR, qrScanRequestID == nil, let request else { return }
        qrScanRequestID = request.id
        check(QRKeyMethod(qrService: qr, keys: request.keys), for: request)
    }

    func locationVerified(requestID: UUID) {
        guard stage == .checkingLocation, request?.id == requestID else { return }
        complete()
    }

    func keySheetClosed() {
        guard stage.showsKeySheet else { return }
        cancel()
    }

    func keySheetDismissed() {
        switch stage {
        case .openingLocation:
            stage = .checkingLocation
        case let current where current.showsKeySheet:
            break
        default:
            if qr.isScanning {
                qr.cancel()
            }
            qrScanRequestID = nil
        }
    }

    func locationSheetClosed() {
        guard stage == .checkingLocation else { return }
        cancel()
    }

    func cancel() {
        stopQRScan()
        finish()
    }

    func hostCleared() {
        guard stage != .idle else { return }
        stopQRScan()
        stage = .idle
        request = nil
        action = nil
    }

    private func begin(_ keyType: KeyType) {
        guard let request else { return }
        switch keyType {
        case .nfc:
            stage = .scanningNFC
            check(NFCKeyMethod(nfcService: nfc, keys: request.keys), for: request)
        case .qr:
            sheetScreen = .qrScanner
            stage = .scanningQR
        case .location:
            stage = stage.showsKeySheet ? .openingLocation : .checkingLocation
        }
    }

    private func check(_ method: some KeyMethod, for request: Request) {
        let requestID = request.id
        Task {
            let result = await method.checkKey()
            scanFinished(result, requestID: requestID)
        }
    }

    private func scanFinished(_ result: KeyResult, requestID: UUID) {
        if qrScanRequestID == requestID {
            qrScanRequestID = nil
        }
        guard request?.id == requestID else { return }
        if result == .success {
            complete()
        } else {
            finish()
        }
    }

    private func complete() {
        action?()
        finish()
    }

    private func finish() {
        finishedRequestID = request?.id
        stage = .idle
        request = nil
        action = nil
    }

    private func stopQRScan() {
        guard qrScanRequestID != nil else { return }
        qrScanRequestID = nil
        qr.cancel()
    }
}
