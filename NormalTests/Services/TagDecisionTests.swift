@testable import Normal
import Testing

struct TagDecisionTests {
    @Test func proceedsWithHexIdForStableNonMRTDTag() {
        let decision = TagDecision.decide(
            hexId: "deadbeef",
            hasRandomIdentifier: false,
            hasMRTDApplication: false
        )
        #expect(decision == .proceed(hexId: "deadbeef"))
    }

    @Test func rejectsAsUnsupportedWhenHexIdMissing() {
        let decision = TagDecision.decide(
            hexId: nil,
            hasRandomIdentifier: false,
            hasMRTDApplication: false
        )
        #expect(decision == .reject(.unsupportedTag))
    }

    @Test func rejectsAsUnstableForRandomUID() {
        let decision = TagDecision.decide(
            hexId: "08abcdef",
            hasRandomIdentifier: true,
            hasMRTDApplication: false
        )
        #expect(decision == .reject(.unstableIdentifier))
    }

    @Test func rejectsAsUnstableForMRTDApplication() {
        let decision = TagDecision.decide(
            hexId: "deadbeef0102",
            hasRandomIdentifier: false,
            hasMRTDApplication: true
        )
        #expect(decision == .reject(.unstableIdentifier))
    }

    @Test func missingHexIdTakesPriorityOverRandomUID() {
        let decision = TagDecision.decide(
            hexId: nil,
            hasRandomIdentifier: true,
            hasMRTDApplication: false
        )
        #expect(decision == .reject(.unsupportedTag))
    }

    @Test func missingHexIdTakesPriorityOverMRTD() {
        let decision = TagDecision.decide(
            hexId: nil,
            hasRandomIdentifier: false,
            hasMRTDApplication: true
        )
        #expect(decision == .reject(.unsupportedTag))
    }
}
