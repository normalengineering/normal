@testable import Normal
import Testing

struct KeyTypeTests {
    @Test func qrAlwaysAvailableOnDevice() {
        #expect(KeyType.qr.isAvailableOnDevice)
    }

    @Test func availableOnDeviceContainsQR() {
        #expect(KeyType.availableOnDevice.contains(.qr))
    }

    @Test func iconsAreSet() {
        #expect(!KeyType.nfc.icon.isEmpty)
        #expect(!KeyType.qr.icon.isEmpty)
    }

    @Test func labelsAreReadable() {
        #expect(KeyType.nfc.label == "NFC Tag")
        #expect(KeyType.qr.label == "QR Code")
    }

    @Test func scanPromptsAreSet() {
        #expect(!KeyType.nfc.scanPrompt.isEmpty)
        #expect(!KeyType.qr.scanPrompt.isEmpty)
    }

    @Test func idMatchesRawValue() {
        #expect(KeyType.nfc.id == "NFC")
        #expect(KeyType.qr.id == "QR")
    }
}
