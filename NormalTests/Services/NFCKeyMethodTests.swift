@testable import Normal
import Testing

struct NFCKeyMethodTests {
    @Test func unvalidatedScanIsRejected() async {
        let key = Key(name: "k", type: .nfc, rawValue: "abc")
        let scanner = FakeKeyScanning(outcome: .acceptAny, rawValue: "abc")
        let method = NFCKeyMethod(nfcService: scanner, keys: [key])
        #expect(await method.checkKey() == .failure)
    }

    @Test func cancelledOnUserCancel() async {
        let scanner = FakeKeyScanning(outcome: .cancel)
        let method = NFCKeyMethod(nfcService: scanner, keys: [])
        #expect(await method.checkKey() == .cancelled)
    }

    @Test func failureOnInvalidKey() async {
        let scanner = FakeKeyScanning(outcome: .throwInvalidKey)
        let method = NFCKeyMethod(nfcService: scanner, keys: [])
        #expect(await method.checkKey() == .failure)
    }

    @Test func failureOnGenericError() async {
        let scanner = FakeKeyScanning(outcome: .throwGeneric)
        let method = NFCKeyMethod(nfcService: scanner, keys: [])
        #expect(await method.checkKey() == .failure)
    }

    @Test func validatorChecksMatchingKey() async {
        let key = Key(name: "k", type: .nfc, rawValue: "abc")
        let scanner = FakeKeyScanning(outcome: .acceptMatching, rawValue: "abc")
        let method = NFCKeyMethod(nfcService: scanner, keys: [key])
        #expect(await method.checkKey() == .success)
    }

    @Test func validatorRejectsNonMatchingKey() async {
        let key = Key(name: "k", type: .nfc, rawValue: "abc")
        let scanner = FakeKeyScanning(outcome: .acceptMatching, rawValue: "other")
        let method = NFCKeyMethod(nfcService: scanner, keys: [key])
        #expect(await method.checkKey() == .failure)
    }
}

struct QRKeyMethodTests {
    @Test func successOnValidScan() async {
        let key = Key(name: "k", type: .qr, rawValue: "code")
        let scanner = FakeKeyScanning(outcome: .acceptMatching, rawValue: "code")
        let method = QRKeyMethod(qrService: scanner, keys: [key])
        #expect(await method.checkKey() == .success)
    }

    @Test func unvalidatedScanIsRejected() async {
        let key = Key(name: "k", type: .qr, rawValue: "code")
        let scanner = FakeKeyScanning(outcome: .acceptAny, rawValue: "code")
        let method = QRKeyMethod(qrService: scanner, keys: [key])
        #expect(await method.checkKey() == .failure)
    }

    @Test func cancelledOnUserCancel() async {
        let scanner = FakeKeyScanning(outcome: .cancel)
        let method = QRKeyMethod(qrService: scanner, keys: [])
        #expect(await method.checkKey() == .cancelled)
    }

    @Test func failureOnInvalidKey() async {
        let scanner = FakeKeyScanning(outcome: .throwInvalidKey)
        let method = QRKeyMethod(qrService: scanner, keys: [])
        #expect(await method.checkKey() == .failure)
    }
}
