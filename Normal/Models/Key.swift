@preconcurrency import CoreNFC
import CommonCrypto
import Foundation
import SwiftData

enum KeyType: String, Codable, CaseIterable, Identifiable {
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
        case .qr: "QR Code"
        }
    }

    var scanPrompt: String {
        switch self {
        case .nfc: "Hold your device near an NFC tag"
        case .qr: "Scan a QR code with your camera"
        }
    }
}

@Model
final class Key: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: KeyType
    private(set) var hashedValue: String
    private(set) var salt: String

    private static let pbkdf2Rounds: UInt32 = 100_000

    init(name: String, type: KeyType, rawValue: String) {
        id = UUID()
        self.name = name
        self.type = type
        let salt = Self.generateSalt()
        self.salt = salt
        hashedValue = Self.hash(unhashedString: rawValue, salt: salt)
    }

    private static func hash(unhashedString: String, salt: String) -> String {
        let password = Array(unhashedString.utf8)
        let saltBytes = Array(salt.utf8)
        var result = [UInt8](repeating: 0, count: 32)

        CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password, password.count,
            saltBytes, saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            pbkdf2Rounds,
            &result, result.count
        )

        return Data(result).hexString
    }

    private static func generateSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).hexString
    }

    static func matchingKeyExists(keys: [Key], unhashedId: String) -> Bool {
        keys.contains {
            $0.hashedValue == Self.hash(unhashedString: unhashedId, salt: $0.salt)
        }
    }
}
