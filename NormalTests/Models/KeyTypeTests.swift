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
        #expect(KeyType.qr.label == "QR Code / Barcode")
    }

    @Test func scanPromptsAreSet() {
        #expect(!KeyType.nfc.scanPrompt.isEmpty)
        #expect(!KeyType.qr.scanPrompt.isEmpty)
    }

    @Test func idMatchesRawValue() {
        #expect(KeyType.nfc.id == "NFC")
        #expect(KeyType.qr.id == "QR")
    }

    @Test func selectableIsIntersectionOfRegisteredAndOnDevice() {
        let result = KeyType.selectable(registered: [.nfc, .qr], onDevice: [.qr])
        #expect(result == [.qr])
    }

    @Test func selectableIncludesBothWhenRegisteredAndAvailable() {
        let result = KeyType.selectable(registered: [.nfc, .qr], onDevice: [.nfc, .qr])
        #expect(result == [.nfc, .qr])
    }

    @Test func selectableEmptyWhenNoneRegistered() {
        #expect(KeyType.selectable(registered: [], onDevice: [.nfc, .qr]).isEmpty)
    }

    @Test func selectableExcludesRegisteredTypeUnsupportedOnDevice() {
        #expect(KeyType.selectable(registered: [.nfc], onDevice: [.qr]).isEmpty)
    }

    @Test func selectableFollowsDeviceOrderNotRegisteredOrder() {
        let result = KeyType.selectable(registered: [.qr, .nfc], onDevice: [.nfc, .qr])
        #expect(result == [.nfc, .qr])
    }

    @Test func selectableDeduplicatesRepeatedRegistrations() {
        let result = KeyType.selectable(registered: [.qr, .qr], onDevice: [.nfc, .qr])
        #expect(result == [.qr])
    }
}
