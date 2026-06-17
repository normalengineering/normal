import CoreLocation
@testable import Normal
import Testing

struct KeyTests {
    @Test func storesNameAndType() {
        let key = Key(name: "Front Door", type: .nfc, rawValue: "abc")
        #expect(key.name == "Front Door")
        #expect(key.type == .nfc)
    }

    @Test func keyHashesRawValue() {
        let key = Key(name: "k", type: .qr, rawValue: "secret")
        #expect(key.hashedValue != "secret")
        #expect(key.hashedValue.count == 64)
        #expect(key.salt.count == 32)
    }

    @Test func twoKeysWithSameValueProduceDifferentHashes() {
        let a = Key(name: "a", type: .qr, rawValue: "same")
        let b = Key(name: "b", type: .qr, rawValue: "same")
        #expect(a.hashedValue != b.hashedValue)
    }

    @Test func matchesCorrectId() {
        let key = Key(name: "k", type: .qr, rawValue: "open-sesame")
        #expect(key.matches(unhashedId: "open-sesame"))
        #expect(!key.matches(unhashedId: "wrong"))
    }

    @Test func matchingKeyExistsReturnsTrueForMatch() {
        let keys = [
            Key(name: "a", type: .nfc, rawValue: "id-1"),
            Key(name: "b", type: .qr, rawValue: "id-2"),
        ]
        #expect(Key.matchingKeyExists(keys: keys, unhashedId: "id-2"))
    }

    @Test func matchingKeyExistsReturnsFalseForNoMatch() {
        let keys = [Key(name: "a", type: .nfc, rawValue: "id-1")]
        #expect(!Key.matchingKeyExists(keys: keys, unhashedId: "id-unknown"))
    }

    @Test func matchingKeyExistsReturnsFalseForEmpty() {
        #expect(!Key.matchingKeyExists(keys: [], unhashedId: "anything"))
    }

    @Test func displayTypeLabelReflectsScanKind() {
        let qr = Key(name: "q", type: .qr, rawValue: "v", scanKind: .qr)
        let barcode = Key(name: "b", type: .qr, rawValue: "v", scanKind: .barcode)
        #expect(qr.displayTypeLabel == "QR Code")
        #expect(barcode.displayTypeLabel == "Barcode")
    }

    @Test func displayTypeLabelTreatsLegacyCameraKeysAsQRCode() {
        let legacy = Key(name: "old", type: .qr, rawValue: "v")
        #expect(legacy.displayTypeLabel == "QR Code")
    }

    @Test func displayTypeLabelForNFCIgnoresScanKind() {
        let nfc = Key(name: "tag", type: .nfc, rawValue: "v")
        #expect(nfc.displayTypeLabel == "NFC Tag")
    }

    // MARK: - Location keys

    private static let cupertino = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

    private static func locationKey(
        name: String = "Place",
        at coordinate: CLLocationCoordinate2D = cupertino,
        radius: Double = 200,
        kind: LocationRadiusKind = .unblock
    ) -> Key {
        Key(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMeters: radius,
            radiusKind: kind
        )
    }

    @Test func locationKeyStoresCoordinateRadiusAndKind() {
        let key = Self.locationKey(radius: 350, kind: .block)
        #expect(key.type == .location)
        #expect(key.radiusKind == .block)
        #expect(key.radiusMeters == 350)
        #expect(key.coordinate?.latitude == Self.cupertino.latitude)
        #expect(key.coordinate?.longitude == Self.cupertino.longitude)
    }

    @Test func locationKeyHasNoScanSecret() {
        let key = Self.locationKey()
        // Location keys are not scan-based, so they never match a scanned id.
        #expect(!key.matches(unhashedId: "anything"))
    }

    @Test func displayTypeLabelUsesRadiusKind() {
        #expect(Self.locationKey(kind: .unblock).displayTypeLabel == "Unblock Radius")
        #expect(Self.locationKey(kind: .block).displayTypeLabel == "Block Radius")
    }

    @Test func coordinateIsNilForNonLocationKey() {
        let key = Key(name: "k", type: .qr, rawValue: "v")
        #expect(key.coordinate == nil)
    }

    @Test func matchesLocationInsideRadius() {
        let key = Self.locationKey(radius: 200)
        // ~100m north of the center stays within the 200m radius.
        let nearby = CLLocation(latitude: Self.cupertino.latitude + 0.0009, longitude: Self.cupertino.longitude)
        #expect(key.matches(location: nearby))
    }

    @Test func doesNotMatchLocationOutsideRadius() {
        let key = Self.locationKey(radius: 200)
        // ~1.1km north is well outside the 200m radius.
        let far = CLLocation(latitude: Self.cupertino.latitude + 0.01, longitude: Self.cupertino.longitude)
        #expect(!key.matches(location: far))
    }

    @Test func nonLocationKeyNeverMatchesLocation() {
        let key = Key(name: "k", type: .qr, rawValue: "v")
        let here = CLLocation(latitude: Self.cupertino.latitude, longitude: Self.cupertino.longitude)
        #expect(!key.matches(location: here))
    }

    @Test func locationKeysFiltersOnlyLocationKeys() {
        let keys = [
            Key(name: "scan", type: .qr, rawValue: "v"),
            Self.locationKey(name: "loc"),
        ]
        let locationKeys = Key.locationKeys(in: keys)
        #expect(locationKeys.count == 1)
        #expect(locationKeys.first?.name == "loc")
    }

    @Test func existingLocationKindReturnsNilWhenNoLocationKeys() {
        let keys = [Key(name: "scan", type: .nfc, rawValue: "v")]
        #expect(Key.existingLocationKind(in: keys) == nil)
    }

    @Test func existingLocationKindReturnsKindOfLocationKey() {
        let keys = [Self.locationKey(kind: .block)]
        #expect(Key.existingLocationKind(in: keys) == .block)
    }

    // MARK: - locationKeyVerifies

    @Test func unblockVerifiesWhenInsideAnyZone() {
        let inZone = CLLocation(latitude: Self.cupertino.latitude, longitude: Self.cupertino.longitude)
        let keys = [
            Self.locationKey(name: "office", at: Self.cupertino, kind: .unblock),
            Self.locationKey(name: "gym", at: .init(latitude: 40, longitude: -74), kind: .unblock),
        ]
        #expect(Key.locationKeyVerifies(keys: keys, location: inZone))
    }

    @Test func unblockFailsWhenOutsideEveryZone() {
        let elsewhere = CLLocation(latitude: 51.5074, longitude: -0.1278)
        let keys = [Self.locationKey(kind: .unblock)]
        #expect(!Key.locationKeyVerifies(keys: keys, location: elsewhere))
    }

    @Test func blockVerifiesWhenOutsideEveryZone() {
        let elsewhere = CLLocation(latitude: 51.5074, longitude: -0.1278)
        let keys = [Self.locationKey(kind: .block)]
        #expect(Key.locationKeyVerifies(keys: keys, location: elsewhere))
    }

    @Test func blockFailsWhenInsideAnyZone() {
        let inZone = CLLocation(latitude: Self.cupertino.latitude, longitude: Self.cupertino.longitude)
        let keys = [Self.locationKey(kind: .block)]
        #expect(!Key.locationKeyVerifies(keys: keys, location: inZone))
    }

    @Test func locationKeyVerifiesIsFalseWithoutLocationKeys() {
        let here = CLLocation(latitude: Self.cupertino.latitude, longitude: Self.cupertino.longitude)
        let keys = [Key(name: "scan", type: .qr, rawValue: "v")]
        #expect(!Key.locationKeyVerifies(keys: keys, location: here))
    }

    // MARK: - Group scoping

    @Test func newKeyIsGlobalByDefault() {
        #expect(Key(name: "k", type: .nfc, rawValue: "v").groupID == nil)
    }

    @Test func scopedToNilReturnsGlobalKeysOnly() {
        let groupA = UUID()
        let global = Key(name: "global", type: .nfc, rawValue: "a")
        let grouped = Key(name: "grouped", type: .nfc, rawValue: "b", groupID: groupA)
        let result = Key.scoped([global, grouped], toGroup: nil)
        #expect(result.map(\.name) == ["global"])
    }

    @Test func scopedToGroupReturnsGlobalPlusThatGroup() {
        let groupA = UUID()
        let groupB = UUID()
        let global = Key(name: "global", type: .nfc, rawValue: "a")
        let inA = Key(name: "inA", type: .nfc, rawValue: "b", groupID: groupA)
        let inB = Key(name: "inB", type: .nfc, rawValue: "c", groupID: groupB)
        let result = Key.scoped([global, inA, inB], toGroup: groupA)
        #expect(Set(result.map(\.name)) == ["global", "inA"])
    }

    @Test func canDeleteEnforcesAtLeastOneGlobalKey() {
        let groupA = UUID()
        let global1 = Key(name: "g1", type: .nfc, rawValue: "a")
        let global2 = Key(name: "g2", type: .nfc, rawValue: "b")
        let group1 = Key(name: "grp1", type: .nfc, rawValue: "c", groupID: groupA)
        let group2 = Key(name: "grp2", type: .nfc, rawValue: "d", groupID: groupA)

        // With 2 globals, either global is deletable; the last global is not.
        let all = [global1, global2, group1, group2]
        #expect(Key.canDelete(global1, in: all))
        #expect(!Key.canDelete(global1, in: [global1, group1, group2]))

        // Group keys are always deletable, even when they are the only keys left.
        #expect(Key.canDelete(group1, in: all))
        #expect(Key.canDelete(group1, in: [group1]))
    }

    @Test func hasGlobalKeyIgnoresGroupKeys() {
        let groupA = UUID()
        #expect(!Key.hasGlobalKey(in: []))
        #expect(!Key.hasGlobalKey(in: [Key(name: "g", type: .qr, rawValue: "a", groupID: groupA)]))
        #expect(Key.hasGlobalKey(in: [
            Key(name: "global", type: .qr, rawValue: "b"),
            Key(name: "g", type: .qr, rawValue: "a", groupID: groupA),
        ]))
    }

    @Test func groupKeyMatchesOnlyWithinItsScope() {
        let groupA = UUID()
        let groupKey = Key(name: "g", type: .qr, rawValue: "secret", groupID: groupA)
        let allKeys = [Key(name: "global", type: .qr, rawValue: "other"), groupKey]

        #expect(!Key.matchingKeyExists(keys: Key.scoped(allKeys, toGroup: nil), unhashedId: "secret"))
        #expect(Key.matchingKeyExists(keys: Key.scoped(allKeys, toGroup: groupA), unhashedId: "secret"))
        #expect(!Key.matchingKeyExists(keys: Key.scoped(allKeys, toGroup: UUID()), unhashedId: "secret"))
    }
}
