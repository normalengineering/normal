@testable import Normal
import Testing

struct KeyTypeTests {
    @Test func nfcProperties() {
        #expect(KeyType.nfc.icon == "wave.3.right")
        #expect(KeyType.nfc.label == "NFC Tag")
        #expect(!KeyType.nfc.scanPrompt.isEmpty)
    }

    @Test func qrProperties() {
        #expect(KeyType.qr.icon == "qrcode.viewfinder")
        #expect(KeyType.qr.label == "QR Code")
        #expect(!KeyType.qr.scanPrompt.isEmpty)
    }

    @Test func allCases() {
        #expect(KeyType.allCases.count == 2)
        #expect(KeyType.allCases.contains(.nfc))
        #expect(KeyType.allCases.contains(.qr))
    }
}
