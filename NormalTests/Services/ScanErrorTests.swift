import Foundation
@testable import Normal
import Testing

struct ScanErrorTests {
    @Test func alreadyScanningHasDescription() {
        #expect(ScanError.alreadyScanning.errorDescription == "A scan is already in progress.")
    }

    @Test func userCanceledHasDescription() {
        #expect(ScanError.userCanceled.errorDescription == "Scanning was canceled.")
    }

    @Test func invalidKeyHasDescription() {
        #expect(ScanError.invalidKey.errorDescription == "This key hasn't been registered.")
    }

    @Test func systemErrorUsesUnderlyingDescription() {
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "boom"])
        #expect(ScanError.systemError(underlying).errorDescription == "boom")
    }

    @Test func nfcUnavailableHasMessage() {
        #expect(ScanError.NFCError.unavailable.errorDescription == "NFC is not supported on this device.")
    }

    @Test func nfcConnectionFailedHasMessage() {
        #expect(ScanError.NFCError.connectionFailed.errorDescription == "Could not connect to the tag. Please try again.")
    }

    @Test func nfcUnsupportedTagHasMessage() {
        #expect(ScanError.NFCError.unsupportedTag.errorDescription == "This tag type isn't compatible with this app.")
    }

    @Test func nfcAlertMessagesAreSet() {
        #expect(!ScanError.NFCError.unavailable.alertMessage.isEmpty)
        #expect(!ScanError.NFCError.connectionFailed.alertMessage.isEmpty)
        #expect(!ScanError.NFCError.unsupportedTag.alertMessage.isEmpty)
    }
}
