@testable import Normal
import Testing

struct KeySelectLogicTests {
    @Test func noAvailableKeysShowsAlert() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [],
            allowBypass: false,
            defaultKeyType: nil
        )
        #expect(result == .showNoKeysAlert)
    }

    @Test func noAvailableKeysShowsAlertEvenWithBypass() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [],
            allowBypass: true,
            defaultKeyType: nil
        )
        #expect(result == .showNoKeysAlert)
    }

    @Test func unblockWithOnlyQRShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.qr],
            allowBypass: false,
            defaultKeyType: nil
        )
        #expect(result == .showSheet)
    }

    @Test func unblockWithDefaultQRShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.qr],
            allowBypass: false,
            defaultKeyType: .qr
        )
        #expect(result == .showSheet)
    }

    @Test func unblockWithOnlyQRAndDefaultQRShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.qr],
            allowBypass: false,
            defaultKeyType: .qr
        )
        #expect(result == .showSheet)
    }

    @Test func unblockWithOnlyNFCAutoSelects() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.nfc],
            allowBypass: false,
            defaultKeyType: nil
        )
        #expect(result == .autoSelect(.nfc))
    }

    @Test func unblockWithDefaultNFCAutoSelects() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.nfc, .qr],
            allowBypass: false,
            defaultKeyType: .nfc
        )
        #expect(result == .autoSelect(.nfc))
    }

    @Test func blockWithNFCOnlyShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.nfc],
            allowBypass: true,
            defaultKeyType: nil
        )
        #expect(result == .showSheet)
    }

    @Test func blockWithDefaultKeyShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.nfc],
            allowBypass: true,
            defaultKeyType: .nfc
        )
        #expect(result == .showSheet)
    }

    @Test func blockWithQROnlyShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.qr],
            allowBypass: true,
            defaultKeyType: nil
        )
        #expect(result == .showSheet)
    }

    @Test func unblockWithMultipleTypesNoDefaultShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.nfc, .qr],
            allowBypass: false,
            defaultKeyType: nil
        )
        #expect(result == .showSheet)
    }

    @Test func unblockWithMultipleTypesDefaultQRShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.nfc, .qr],
            allowBypass: false,
            defaultKeyType: .qr
        )
        #expect(result == .showSheet)
    }

    @Test func unblockWithUnavailableDefaultShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.qr],
            allowBypass: false,
            defaultKeyType: .nfc
        )
        #expect(result == .showSheet)
    }

    @Test func unblockWithUnavailableDefaultNFCAndOnlyQRShowsSheet() {
        let result = KeySelectLogic.decide(
            availableKeyTypes: [.qr],
            allowBypass: false,
            defaultKeyType: .nfc
        )
        #expect(result == .showSheet)
    }
}
