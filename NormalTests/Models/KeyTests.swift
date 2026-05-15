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
}
