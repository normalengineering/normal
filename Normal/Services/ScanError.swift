import Foundation

enum ScanError: LocalizedError {
    case alreadyScanning
    case userCanceled
    case invalidKey
    case systemError(Error)
    case nfc(NFCError)

    enum NFCError: LocalizedError, Sendable, Equatable {
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

    var errorDescription: String {
        switch self {
        case .alreadyScanning: "A scan is already in progress."
        case .userCanceled: "Scanning was canceled."
        case .invalidKey: "This key hasn't been registered."
        case let .systemError(e): e.localizedDescription
        case let .nfc(nfcError): nfcError.errorDescription ?? "Unknown NFC error"
        }
    }
}
