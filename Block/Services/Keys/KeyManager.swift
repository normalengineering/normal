import Foundation
import Observation

enum ScanError: LocalizedError {
    case alreadyScanning
    case userCanceled
    case invalidKey
    case systemError(Error)
    case nfc(NFCError)

    var errorDescription: String {
        switch self {
        case .alreadyScanning:    "A scan is already in progress."
        case .userCanceled:       "Scanning was canceled."
        case .invalidKey:         "This key hasn't been registered."
        case let .systemError(e): e.localizedDescription
        case let .nfc(nfcError):    nfcError.errorDescription ?? "Unknown NFC error"
        }
    }
}

@Observable
final class KeyManager {
    @discardableResult
    func performWithKeyCheck(
        using method: KeyMethod,
        action: @MainActor () -> Void
    ) async -> Bool {
        let result = await method.checkKey()

        switch result {
        case .success:
            action()
            return true
        case .failure:
            return false
        case .cancelled:
            return false
        }
    }
}
