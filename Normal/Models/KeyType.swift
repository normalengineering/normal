import Foundation

enum KeyType: String, Codable, CaseIterable, Identifiable, Sendable {
    case nfc = "NFC"
    case qr = "QR"
    case location = "LOCATION"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nfc: "wave.3.right"
        case .qr: "qrcode.viewfinder"
        case .location: "location.fill"
        }
    }

    var label: String {
        switch self {
        case .nfc: "NFC Tag"
        case .qr: "QR Code / Barcode"
        case .location: "Location"
        }
    }

    var shortLabel: String {
        switch self {
        case .nfc: "NFC"
        case .qr: "QR / Barcode"
        case .location: "Location"
        }
    }

    var scanPrompt: String {
        switch self {
        case .nfc: "Hold your device near an NFC tag"
        case .qr: "Scan with your camera"
        case .location: "Verify you're at a saved place"
        }
    }

    var autoSelectable: Bool {
        switch self {
        case .nfc, .location: true
        case .qr: false
        }
    }
}
