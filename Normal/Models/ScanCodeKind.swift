import Foundation

enum ScanCodeKind: String, Codable, Sendable {
    case qr
    case barcode

    var label: String {
        switch self {
        case .qr: "QR Code"
        case .barcode: "Barcode"
        }
    }

    var icon: String {
        switch self {
        case .qr: "qrcode"
        case .barcode: "barcode"
        }
    }
}
