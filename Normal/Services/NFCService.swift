@preconcurrency import CoreNFC
import Foundation
import Observation

extension ScanError {
    enum NFCError: LocalizedError {
        case unavailable
        case connectionFailed
        case unsupportedTag

        var errorDescription: String? {
            switch self {
            case .unavailable: "NFC is not supported on this device."
            case .connectionFailed: "Could not connect to the tag. Please try again."
            case .unsupportedTag: "This tag type isn't compatible with this app."
            }
        }

        var alertMessage: String {
            switch self {
            case .unavailable: "NFC unavailable."
            case .connectionFailed: "Connection failed."
            case .unsupportedTag: "Unsupported NFC type. Please contact us to add support."
            }
        }
    }
}

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
}

@Observable
final class NFCService: NSObject {
    static let shared = NFCService()

    private(set) var isScanning = false
    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<String, Error>?
    private var validator: ((String) -> Bool)?

    override private init() { super.init() }

    func scan() async throws -> String {
        try await scan(validate: nil)
    }

    func scan(validate: ((String) -> Bool)?) async throws -> String {
        guard !isScanning else { throw ScanError.alreadyScanning }
        guard NFCTagReaderSession.readingAvailable else { throw ScanError.nfc(.unavailable) }

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

    private func finish(with result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        session = nil
        isScanning = false
    }
}

extension NFCService: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(_: NFCTagReaderSession, didInvalidateWithError error: Error) {
        MainActor.assumeIsolated {
            if (error as? NFCReaderError)?.code == .readerSessionInvalidationErrorUserCanceled {
                finish(with: .failure(ScanError.userCanceled))
            } else {
                finish(with: .failure(ScanError.systemError(error)))
            }
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }

        session.connect(to: tag) { error in
            MainActor.assumeIsolated {
                if error != nil {
                    let err = ScanError.NFCError.connectionFailed
                    session.invalidate(errorMessage: err.alertMessage)
                    self.finish(with: .failure(ScanError.nfc(err)))
                    return
                }

                guard let hexId = tag.hexId else {
                    let err = ScanError.NFCError.unsupportedTag
                    session.invalidate(errorMessage: err.alertMessage)
                    self.finish(with: .failure(ScanError.nfc(err)))
                    return
                }

                guard let validator = self.validator else {
                    session.alertMessage = "Key Detected"
                    session.invalidate()
                    self.finish(with: .success(hexId))
                    return
                }

                if validator(hexId) {
                    session.alertMessage = "Key Verified"
                    session.invalidate()
                    self.finish(with: .success(hexId))
                } else {
                    session.invalidate(errorMessage: ScanError.invalidKey.errorDescription)
                    self.finish(with: .failure(ScanError.invalidKey))
                }
            }
        }
    }
}
