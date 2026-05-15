@testable import Normal
import Testing

struct KeySelectLogicTests {
    @Test func noAvailableKeysShowsAlert() {
        let result = KeySelectLogic.decide(availableKeyTypes: [], allowBypass: false, defaultKeyType: nil)
        #expect(result == .showNoKeysAlert)
    }

    @Test func noAvailableKeysShowsAlertEvenWithBypass() {
        let result = KeySelectLogic.decide(availableKeyTypes: [], allowBypass: true, defaultKeyType: nil)
        #expect(result == .showNoKeysAlert)
    }

    @Test func unblockOnlyQRShowsSheet() {
        let result = KeySelectLogic.decide(availableKeyTypes: [.qr], allowBypass: false, defaultKeyType: nil)
        #expect(result == .showSheet)
    }

    @Test func unblockDefaultQRShowsSheet() {
        let result = KeySelectLogic.decide(availableKeyTypes: [.qr], allowBypass: false, defaultKeyType: .qr)
        #expect(result == .showSheet)
    }

    @Test func unblockOnlyNFCAutoSelectsNFC() {
        let result = KeySelectLogic.decide(availableKeyTypes: [.nfc], allowBypass: false, defaultKeyType: nil)
        #expect(result == .autoSelect(.nfc))
    }

    @Test func unblockDefaultNFCWithBothTypesAutoSelects() {
        let result = KeySelectLogic.decide(availableKeyTypes: [.nfc, .qr], allowBypass: false, defaultKeyType: .nfc)
        #expect(result == .autoSelect(.nfc))
    }

    @Test func blockWithBypassShowsSheet() {
        let result = KeySelectLogic.decide(availableKeyTypes: [.nfc], allowBypass: true, defaultKeyType: nil)
        #expect(result == .showSheet)
    }

    @Test func blockBypassDefaultKeyShowsSheet() {
        let result = KeySelectLogic.decide(availableKeyTypes: [.nfc], allowBypass: true, defaultKeyType: .nfc)
        #expect(result == .showSheet)
    }

    @Test func unblockBothTypesNoDefaultShowsSheet() {
        let result = KeySelectLogic.decide(availableKeyTypes: [.nfc, .qr], allowBypass: false, defaultKeyType: nil)
        #expect(result == .showSheet)
    }

    @Test func unblockBothTypesDefaultQRShowsSheet() {
        let result = KeySelectLogic.decide(availableKeyTypes: [.nfc, .qr], allowBypass: false, defaultKeyType: .qr)
        #expect(result == .showSheet)
    }

    @Test func unblockUnavailableDefaultFallsBackToSheet() {
        let result = KeySelectLogic.decide(availableKeyTypes: [.qr], allowBypass: false, defaultKeyType: .nfc)
        #expect(result == .showSheet)
    }
}
