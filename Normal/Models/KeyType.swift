@preconcurrency import CoreNFC
import Foundation

enum KeyType: String, Codable, CaseIterable, Identifiable, Sendable {
    case nfc = "NFC"
    case qr = "QR"

    var id: String { rawValue }

    var isAvailableOnDevice: Bool {
        switch self {
        case .nfc: NFCTagReaderSession.readingAvailable
        case .qr: true
        }
    }

    static var availableOnDevice: [KeyType] {
        allCases.filter(\.isAvailableOnDevice)
    }

    var icon: String {
        switch self {
        case .nfc: "wave.3.right"
        case .qr: "qrcode.viewfinder"
        }
    }

    var label: String {
        switch self {
        case .nfc: "NFC Tag"
        case .qr: "QR Code / Barcode"
        }
    }

    var shortLabel: String {
        switch self {
        case .nfc: "NFC"
        case .qr: "QR / Barcode"
        }
    }

    var scanPrompt: String {
        switch self {
        case .nfc: "Hold your device near an NFC tag"
        case .qr: "Scan with your camera"
        }
    }
}
