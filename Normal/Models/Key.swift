import CommonCrypto
import CoreLocation
import Foundation
import SwiftData

@Model
final class Key: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: KeyType
    var scanKind: ScanCodeKind?
    var latitude: Double?
    var longitude: Double?
    var radiusMeters: Double?
    var radiusKind: LocationRadiusKind?
    var sortIndex: Int = 0
    var groupID: UUID? = nil
    private(set) var hashedValue: String
    private(set) var salt: String

    private static let pbkdf2Rounds: UInt32 = 100_000
    private static let saltLength = 16
    private static let hashLength = 32

    init(
        name: String,
        type: KeyType,
        rawValue: String,
        scanKind: ScanCodeKind? = nil,
        sortIndex: Int = 0,
        groupID: UUID? = nil
    ) {
        id = UUID()
        self.name = name
        self.type = type
        self.scanKind = scanKind
        latitude = nil
        longitude = nil
        radiusMeters = nil
        radiusKind = nil
        self.sortIndex = sortIndex
        self.groupID = groupID
        let salt = Self.generateSalt()
        self.salt = salt
        hashedValue = Self.hash(unhashedString: rawValue, salt: salt)
    }

    init(
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        radiusKind: LocationRadiusKind,
        sortIndex: Int = 0,
        groupID: UUID? = nil
    ) {
        id = UUID()
        self.name = name
        type = .location
        scanKind = nil
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.radiusKind = radiusKind
        self.sortIndex = sortIndex
        self.groupID = groupID
        salt = ""
        hashedValue = ""
    }

    var displayTypeLabel: String {
        switch type {
        case .nfc: KeyType.nfc.label
        case .qr: (scanKind ?? .qr).label
        case .location: radiusKind?.label ?? KeyType.location.label
        }
    }

    var symbolName: String {
        switch type {
        case .nfc: "sensor.tag.radiowaves.forward.fill"
        case .qr: scanKind?.icon ?? "qrcode"
        case .location: radiusKind?.icon ?? KeyType.location.icon
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isGlobal: Bool { groupID == nil }

    static func matchingKeyExists(keys: [Key], unhashedId: String) -> Bool {
        keys.contains { $0.matches(unhashedId: unhashedId) }
    }

    static func scoped(_ keys: [Key], toGroup groupID: UUID?) -> [Key] {
        keys.filter { $0.isGlobal || $0.groupID == groupID }
    }

    static func hasGlobalKey(in keys: [Key]) -> Bool {
        keys.contains(where: \.isGlobal)
    }

    static func canDelete(_ key: Key, in keys: [Key]) -> Bool {
        guard key.isGlobal else { return true }
        return hasGlobalKey(in: keys.filter { $0.id != key.id })
    }

    func matches(unhashedId: String) -> Bool {
        guard type != .location, !hashedValue.isEmpty else { return false }
        return Self.hash(unhashedString: unhashedId, salt: salt) == hashedValue
    }

    func matches(location: CLLocation) -> Bool {
        guard type == .location, let latitude, let longitude, let radiusMeters else { return false }
        let target = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: target) <= radiusMeters
    }

    static func locationKeys(in keys: [Key]) -> [Key] {
        keys.filter { $0.type == .location }
    }

    static func existingLocationKind(in keys: [Key]) -> LocationRadiusKind? {
        locationKeys(in: keys).first?.radiusKind
    }

    static func locationKeyVerifies(keys: [Key], location: CLLocation) -> Bool {
        let locKeys = locationKeys(in: keys)
        guard let kind = locKeys.first?.radiusKind else { return false }
        let inside = locKeys.contains { $0.matches(location: location) }
        switch kind {
        case .unblock: return inside
        case .block: return !inside
        }
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
