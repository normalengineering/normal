import CommonCrypto
import Foundation
import SwiftData

@Model
final class Key: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: KeyType
    private(set) var hashedValue: String
    private(set) var salt: String

    private static let pbkdf2Rounds: UInt32 = 100_000
    private static let saltLength = 16
    private static let hashLength = 32

    init(name: String, type: KeyType, rawValue: String) {
        self.id = UUID()
        self.name = name
        self.type = type
        let salt = Self.generateSalt()
        self.salt = salt
        self.hashedValue = Self.hash(unhashedString: rawValue, salt: salt)
    }

    static func matchingKeyExists(keys: [Key], unhashedId: String) -> Bool {
        keys.contains { $0.matches(unhashedId: unhashedId) }
    }

    func matches(unhashedId: String) -> Bool {
        Self.hash(unhashedString: unhashedId, salt: salt) == hashedValue
    }

    private static func hash(unhashedString: String, salt: String) -> String {
        let password = Array(unhashedString.utf8)
        let saltBytes = Array(salt.utf8)
        var result = [UInt8](repeating: 0, count: hashLength)

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
        var bytes = [UInt8](repeating: 0, count: saltLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).hexString
    }
}
