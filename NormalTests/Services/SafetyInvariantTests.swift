import FamilyControls
import Foundation
import Testing

@testable import Normal

@MainActor
struct SafetyInvariantTests {
    @Test func registeredKeyAlwaysSelfValidatesAcrossArbitraryPayloads() {
        let payloads = [
            "abc", "", " ", "  leading-trailing  ", "0123456789ABCDEF",
            "emoji-🔐-key", "ünïçødé", String(repeating: "x", count: 4096),
            "line\nbreak\ttab", "https://example.com/path?q=1",
        ]
        for payload in payloads {
            let key = Key(name: "k", type: .nfc, rawValue: payload)
            #expect(key.matches(unhashedId: payload))
            #expect(!key.matches(unhashedId: payload + "x"))
        }
    }

    @Test func manyRandomKeysNeverFalseMatchOrFailToMatch() {
        for _ in 0..<200 {
            let value = UUID().uuidString + String(UInt64.random(in: .min ... .max))
            let key = Key(name: "k", type: .qr, rawValue: value)
            #expect(key.matches(unhashedId: value))
            #expect(!key.matches(unhashedId: UUID().uuidString))
        }
    }

    @Test func hashAndSaltFormatIsLowercaseHexWithFixedLength() {
        let hexOnly = CharacterSet(charactersIn: "0123456789abcdef")
        for _ in 0..<50 {
            let key = Key(name: "k", type: .nfc, rawValue: UUID().uuidString)
            #expect(key.hashedValue.count == 64)
            #expect(key.salt.count == 32)
            #expect(CharacterSet(charactersIn: key.hashedValue).isSubset(of: hexOnly))
            #expect(CharacterSet(charactersIn: key.salt).isSubset(of: hexOnly))
        }
    }

    @Test func mismatchedPreventDeleteFlagsStrandTheEscapeHatch() {
        let spy = StatefulScreenTimeSpy()
        let selection = FamilyActivitySelection()

        spy.blockAll(selection: selection, blockAllPreventsAppDelete: true)
        spy.unblockAll(blockAllPreventsAppDelete: false)

        #expect(spy.invariantViolated)
    }
}
