@preconcurrency import CoreNFC
import Foundation
import Observation
import UIKit

private extension NFCTag {
    var hexId: String? {
        let bytes: Data? = switch self {
        case let .feliCa(t): t.currentIDm
        case let .miFare(t): t.identifier
        case let .iso7816(t): t.identifier
        case let .iso15693(t): t.identifier
        @unknown default: nil
        }
        return bytes?.hexString
    }

    var hasRandomIdentifier: Bool {
        let id: Data? = switch self {
        case let .miFare(t): t.identifier
        case let .iso7816(t): t.identifier
        default: nil
        }
        return id?.count == 4 && id?.first == 0x08
    }
}

private let mrtdAID = Data([0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01])

private extension NFCISO7816Tag {
    func hasMRTDApplication() async -> Bool {
        let apdu = NFCISO7816APDU(
            instructionClass: 0x00,
            instructionCode: 0xA4,
            p1Parameter: 0x04,
            p2Parameter: 0x0C,
            data: mrtdAID,
            expectedResponseLength: -1
        )
        do {
            let (_, sw1, sw2) = try await sendCommand(apdu: apdu)
            return sw1 == 0x90 && sw2 == 0x00
        } catch {
            return false
        }
    }
}

@Observable
final class NFCService: NSObject {
    static let shared = NFCService()

    private(set) var isScanning = false
    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<String, Error>?
    private var validator: ((String) -> Bool)?
    private var coveredBySheet = false
    private var rejection: ScanError?

    override private init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(appResignedActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func scan() async throws -> String {
        try await scan(validate: nil)
    }

    func scan(validate: ((String) -> Bool)?) async throws -> String {
        if UITestSupport.isActive {
            if let validate, !validate(UITestSupport.stubScanValue) {
                throw ScanError.invalidKey
            }
            return UITestSupport.stubScanValue
        }
        guard !isScanning else { throw ScanError.alreadyScanning }
        guard NFCTagReaderSession.readingAvailable else { throw ScanError.nfc(.unavailable) }
        try Task.checkCancellation()

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.validator = validate
            self.isScanning = true

            session = NFCTagReaderSession(
                pollingOption: [.iso14443, .iso15693, .iso18092],
                delegate: self,
                queue: .main
            )
            session?.alertMessage = "Hold your device near the NFC tag."
            session?.begin()
        }
    }

    func cancel() {
        guard isScanning else { return }
        session?.invalidate()
        finish(with: .failure(ScanError.userCanceled))
    }

    @objc private func appResignedActive() {
        coveredBySheet = isScanning
    }

    @objc private func appBecameActive() {
        guard coveredBySheet else { return }
        if let rejection {
            finish(with: .failure(rejection))
        } else {
            cancel()
        }
    }

    private func reject(_ session: NFCTagReaderSession, with error: ScanError, message: String) {
        session.invalidate(errorMessage: message)
        guard coveredBySheet else {
            finish(with: .failure(error))
            return
        }
        rejection = error
    }

    private func finish(with result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        session = nil
        rejection = nil
        coveredBySheet = false
        isScanning = false
    }
}

extension NFCService: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let ended = ObjectIdentifier(session)
        MainActor.assumeIsolated {
            guard self.session.map(ObjectIdentifier.init) == ended, rejection == nil else { return }
            if (error as? NFCReaderError)?.code == .readerSessionInvalidationErrorUserCanceled {
                finish(with: .failure(ScanError.userCanceled))
            } else {
                finish(with: .failure(ScanError.systemError(error)))
            }
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        Task { @MainActor in
            await process(tag: tag, session: session)
        }
    }

    private func process(tag: NFCTag, session: NFCTagReaderSession) async {
        do {
            try await session.connect(to: tag)
        } catch {
            fail(session: session, with: .connectionFailed)
            return
        }

        let hasRandomID = tag.hasRandomIdentifier
        let hasMRTD = await checkMRTD(tag: tag, skipping: hasRandomID)

        switch TagDecision.decide(
            hexId: tag.hexId,
            hasRandomIdentifier: hasRandomID,
            hasMRTDApplication: hasMRTD
        ) {
        case let .proceed(hexId):
            complete(session: session, hexId: hexId)
        case let .reject(err):
            fail(session: session, with: err)
        }
    }

    private func checkMRTD(tag: NFCTag, skipping skip: Bool) async -> Bool {
        guard !skip, case let .iso7816(iso) = tag else { return false }
        return await iso.hasMRTDApplication()
    }

    private func fail(session: NFCTagReaderSession, with err: ScanError.NFCError) {
        guard session === self.session else { return }
        reject(session, with: .nfc(err), message: err.alertMessage)
    }

    private func complete(session: NFCTagReaderSession, hexId: String) {
        guard session === self.session else { return }
        guard let validator else {
            session.alertMessage = "Key Detected"
            session.invalidate()
            finish(with: .success(hexId))
            return
        }
        if validator(hexId) {
            session.alertMessage = "Key Verified"
            session.invalidate()
            finish(with: .success(hexId))
        } else {
            reject(session, with: .invalidKey, message: ScanError.invalidKey.errorDescription)
        }
    }
}
