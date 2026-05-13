@testable import Normal
import Foundation
import SwiftData
import Testing

struct KeyTests {
    @Test @MainActor func keyInitHashesValue() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let key = Key(name: "Test", type: .nfc, rawValue: "abc123")
        context.insert(key)

        #expect(!key.hashedValue.isEmpty)
        #expect(key.hashedValue != "abc123")
        #expect(!key.salt.isEmpty)
    }

    @Test @MainActor func twoKeysWithSameValueHaveDifferentHashes() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let key1 = Key(name: "Key1", type: .nfc, rawValue: "same_value")
        let key2 = Key(name: "Key2", type: .nfc, rawValue: "same_value")
        context.insert(key1)
        context.insert(key2)

        #expect(key1.salt != key2.salt)
        #expect(key1.hashedValue != key2.hashedValue)
    }

    @Test @MainActor func matchingKeyExistsReturnsTrueForMatch() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let key = Key(name: "Test", type: .nfc, rawValue: "my_tag_id")
        context.insert(key)

        #expect(Key.matchingKeyExists(keys: [key], unhashedId: "my_tag_id"))
    }

    @Test @MainActor func matchingKeyExistsReturnsFalseForWrongValue() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let key = Key(name: "Test", type: .nfc, rawValue: "correct")
        context.insert(key)

        #expect(!Key.matchingKeyExists(keys: [key], unhashedId: "wrong"))
    }

    @Test func matchingKeyExistsReturnsFalseForEmptyArray() {
        #expect(!Key.matchingKeyExists(keys: [], unhashedId: "anything"))
    }
}
