import Foundation
@testable import Normal
import Testing

@MainActor
struct KeyCheckFlowTests {
    private let nfc = ControlledScanner()
    private let qr = ControlledScanner()
    private let flow: KeyCheckFlow
    private let counter = Counter()

    private final class Counter {
        var runs = 0
        var proofs: [KeyProof] = []
    }

    init() {
        flow = KeyCheckFlow(nfc: nfc, qr: qr)
    }

    private func key(_ type: KeyType, _ value: String) -> Key {
        Key(name: value, type: type, rawValue: value)
    }

    private func request(
        _ keys: [Key],
        available: [KeyType],
        keyGroupID: UUID? = nil,
        defaultKeyType: KeyType? = nil
    ) -> KeyCheckFlow.Request {
        KeyCheckFlow.Request(
            keys: keys,
            keyGroupID: keyGroupID,
            availableKeyTypes: available,
            defaultKeyType: defaultKeyType
        )
    }

    private func start(_ request: KeyCheckFlow.Request, allowBypass: Bool = false) {
        let counter = counter
        let action: ProtectedAction = allowBypass
            ? .tighten { counter.runs += 1 }
            : .weaken { counter.proofs.append($0); counter.runs += 1 }
        flow.start(request, action: action)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 10000 where !condition() {
            await Task.yield()
        }
        #expect(condition())
    }

    private var qrAndNFC: KeyCheckFlow.Request {
        request([key(.qr, "code"), key(.nfc, "tag")], available: [.nfc, .qr])
    }

    @Test func noKeysShowsTheAlertUntilCancelled() {
        let request = request([], available: [])
        start(request)
        #expect(flow.stage == .noKeys)

        flow.cancel()

        #expect(flow.stage == .idle)
        #expect(flow.finishedRequestID == request.id)
        #expect(counter.runs == 0)
    }

    @Test func severalKeyTypesShowThePicker() {
        start(qrAndNFC)
        #expect(flow.stage == .choosing)
        #expect(flow.sheetScreen == .picker)
    }

    @Test func defaultNFCKeyScansAndRunsTheAction() async {
        start(request([key(.nfc, "tag"), key(.qr, "code")], available: [.nfc, .qr], defaultKeyType: .nfc))
        #expect(flow.stage == .scanningNFC)

        await waitUntil { nfc.isScanning }
        nfc.present("tag")
        await waitUntil { flow.stage == .idle }

        #expect(counter.runs == 1)
    }

    @Test func passingKeyHandsTheActionAProofForTheRequestsGroup() async {
        let groupID = UUID()
        start(request([key(.nfc, "tag")], available: [.nfc], keyGroupID: groupID))
        await waitUntil { nfc.isScanning }

        nfc.present("tag")
        await waitUntil { flow.stage == .idle }

        #expect(counter.proofs == [KeyProof(keyGroupID: groupID)])
    }

    @Test func rejectedTagEndsWithoutTheAction() async {
        start(request([key(.nfc, "tag")], available: [.nfc]))
        await waitUntil { nfc.isScanning }

        nfc.reject()
        await waitUntil { flow.stage == .idle }

        #expect(counter.runs == 0)
    }

    @Test func qrScanStartsOnceTheScannerAppears() async {
        start(qrAndNFC)
        flow.choose(.qr)
        #expect(flow.stage == .scanningQR)
        #expect(flow.sheetScreen == .qrScanner)
        for _ in 0 ..< 100 {
            await Task.yield()
        }
        #expect(qr.scanCount == 0)

        flow.scannerAppeared()
        flow.scannerAppeared()
        await waitUntil { qr.isScanning }

        #expect(qr.scanCount == 1)
    }

    @Test func requestedQRKeyGoesStraightToTheScanner() {
        var request = qrAndNFC
        request.requestedKeyType = .qr
        start(request)
        #expect(flow.stage == .scanningQR)
        #expect(flow.sheetScreen == .qrScanner)
    }

    @Test func repeatedChoiceIsIgnored() async {
        start(qrAndNFC)
        flow.choose(.qr)
        flow.choose(.qr)
        flow.choose(.nfc)
        flow.scannerAppeared()
        await waitUntil { qr.isScanning }

        #expect(flow.stage == .scanningQR)
        #expect(qr.scanCount == 1)
        #expect(nfc.scanCount == 0)
    }

    @Test func validCodeRunsTheActionOnce() async {
        start(qrAndNFC)
        flow.choose(.qr)
        flow.scannerAppeared()
        await waitUntil { qr.isScanning }

        qr.present("code")
        await waitUntil { flow.stage == .idle }

        #expect(counter.runs == 1)
    }

    @Test func onlyTheRequestsOwnKeysPass() async {
        start(request([key(.qr, "group-code")], available: [.qr]))
        flow.choose(.qr)
        flow.scannerAppeared()
        await waitUntil { qr.isScanning }

        qr.present("other-code")
        #expect(qr.isScanning)
        qr.present("group-code")
        await waitUntil { flow.stage == .idle }

        #expect(counter.runs == 1)
    }

    @Test func newerRequestCancelsTheRunningScan() async {
        start(qrAndNFC)
        flow.choose(.qr)
        flow.scannerAppeared()
        await waitUntil { qr.isScanning }

        let newer = qrAndNFC
        start(newer)

        #expect(!qr.isScanning)
        #expect(flow.stage == .choosing)
        #expect(flow.request?.id == newer.id)
        #expect(counter.runs == 0)
    }

    @Test func resultForAReplacedRequestIsIgnored() async {
        start(request([key(.nfc, "tag")], available: [.nfc]))
        await waitUntil { nfc.isScanning }
        let newer = qrAndNFC
        start(newer)

        nfc.present("tag")
        for _ in 0 ..< 100 {
            await Task.yield()
        }

        #expect(counter.runs == 0)
        #expect(flow.stage == .choosing)
        #expect(flow.request?.id == newer.id)
    }

    @Test func bypassNeedsPermission() {
        start(qrAndNFC)
        #expect(!flow.allowsBypass)
        flow.requestBypass(skippingConfirmation: true)
        #expect(flow.stage == .choosing)
        #expect(counter.runs == 0)
    }

    @Test func bypassWithoutConfirmationRunsTheAction() {
        start(request([key(.qr, "code")], available: [.qr]), allowBypass: true)
        #expect(flow.allowsBypass)
        flow.requestBypass(skippingConfirmation: true)
        #expect(counter.runs == 1)
        #expect(!flow.allowsBypass)
        #expect(flow.stage == .idle)
    }

    @Test func bypassConfirmationRunsTheAction() {
        start(request([key(.qr, "code")], available: [.qr]), allowBypass: true)
        flow.requestBypass(skippingConfirmation: false)
        #expect(flow.stage == .confirmingBypass)
        #expect(flow.sheetScreen == .bypassConfirm)

        flow.confirmBypass()

        #expect(counter.runs == 1)
        #expect(flow.stage == .idle)
    }

    @Test func goingBackFromTheConfirmationShowsThePicker() {
        start(request([key(.qr, "code")], available: [.qr]), allowBypass: true)
        flow.requestBypass(skippingConfirmation: false)
        flow.returnFromBypassConfirm()
        #expect(flow.stage == .choosing)
        #expect(flow.sheetScreen == .picker)
    }

    @Test func confirmationCannotRunANewerRequest() {
        start(request([key(.qr, "code")], available: [.qr]), allowBypass: true)
        flow.requestBypass(skippingConfirmation: false)
        start(qrAndNFC)

        flow.confirmBypass()

        #expect(counter.runs == 0)
        #expect(flow.stage == .choosing)
    }

    @Test func locationOpensAfterThePickerCloses() {
        start(request([key(.qr, "code")], available: [.qr, .location]))
        flow.choose(.location)
        #expect(flow.stage == .openingLocation)

        flow.keySheetDismissed()

        #expect(flow.stage == .checkingLocation)
    }

    @Test func locationVerificationOnlyCountsForTheCurrentRequest() throws {
        let request = request([], available: [.location], defaultKeyType: .location)
        start(request)
        #expect(flow.stage == .checkingLocation)

        flow.locationVerified(requestID: UUID())
        #expect(counter.runs == 0)

        flow.locationVerified(requestID: request.id)
        #expect(counter.runs == 1)
        #expect(counter.proofs == [KeyProof(keyGroupID: nil)])
        #expect(flow.stage == .idle)
    }

    @Test func closingTheLocationSheetCancels() {
        let request = request([], available: [.location], defaultKeyType: .location)
        start(request)

        flow.locationSheetClosed()

        #expect(flow.stage == .idle)
        #expect(flow.finishedRequestID == request.id)
        #expect(counter.runs == 0)
    }

    @Test func closingTheSheetCancelsTheScan() async {
        start(qrAndNFC)
        flow.choose(.qr)
        flow.scannerAppeared()
        await waitUntil { qr.isScanning }

        flow.keySheetClosed()

        #expect(!qr.isScanning)
        #expect(flow.stage == .idle)
        #expect(counter.runs == 0)
    }

    @Test func dismissingAReplacedSheetKeepsTheNewerScan() async {
        start(qrAndNFC)
        flow.choose(.qr)
        start(qrAndNFC)
        flow.choose(.qr)
        flow.scannerAppeared()
        await waitUntil { qr.isScanning }

        flow.keySheetDismissed()

        #expect(qr.isScanning)
        #expect(flow.stage == .scanningQR)
    }

    @Test func dismissingTheSheetClearsAnOrphanedScan() async {
        let orphan = Task { try await qr.scan(validate: nil) }
        await waitUntil { qr.isScanning }

        flow.keySheetDismissed()

        #expect(!qr.isScanning)
        _ = try? await orphan.value
    }

    @Test func clearingTheHostStopsWithoutFinishing() async {
        start(qrAndNFC)
        flow.choose(.qr)
        flow.scannerAppeared()
        await waitUntil { qr.isScanning }

        flow.hostCleared()

        #expect(!qr.isScanning)
        #expect(flow.stage == .idle)
        #expect(flow.finishedRequestID == nil)
        #expect(counter.runs == 0)
    }
}
