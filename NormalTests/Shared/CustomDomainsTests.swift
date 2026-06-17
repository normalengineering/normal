@testable import Normal
import Testing

struct CustomDomainsTests {
    // MARK: - subset

    @Test func subsetKeepsOnlyMainDomainsPreservingOrder() {
        let result = CustomDomains.subset(["b.com", "x.com", "a.com"], of: ["a.com", "b.com"])
        #expect(result == ["b.com", "a.com"])
    }

    @Test func subsetIsEmptyWhenMainIsEmpty() {
        #expect(CustomDomains.subset(["a.com"], of: []) == [])
    }

    @Test func subsetUnchangedWhenAlreadyContained() {
        #expect(CustomDomains.subset(["a.com"], of: ["a.com", "b.com"]) == ["a.com"])
    }

    // MARK: - needsResync

    @Test func needsResyncWhenChosenHasDomainNotInMain() {
        #expect(CustomDomains.needsResync(["a.com", "gone.com"], main: ["a.com"]))
    }

    @Test func noResyncWhenChosenIsSubsetOfMain() {
        #expect(!CustomDomains.needsResync(["a.com"], main: ["a.com", "b.com"]))
        #expect(!CustomDomains.needsResync([], main: ["a.com"]))
    }

    // MARK: - evaluateAdd

    @Test func evaluateAddRejectsInvalidInput() {
        #expect(CustomDomains.evaluateAdd("not a domain", existing: [], otherItemCount: 0) == .invalid)
    }

    @Test func evaluateAddNormalizesBeforeChecking() {
        let result = CustomDomains.evaluateAdd("https://www.Example.com/path", existing: [], otherItemCount: 0)
        #expect(result == .added("example.com", overLimit: false))
    }

    @Test func evaluateAddDetectsDuplicateAfterNormalizing() {
        let result = CustomDomains.evaluateAdd("WWW.example.com", existing: ["example.com"], otherItemCount: 0)
        #expect(result == .duplicate("example.com"))
    }

    @Test func evaluateAddIsNotOverLimitWellUnderCap() {
        let result = CustomDomains.evaluateAdd("a.com", existing: [], otherItemCount: 10)
        #expect(result == .added("a.com", overLimit: false))
    }

    @Test func evaluateAddFlagsOverLimitAtTheCap() {
        // 40 other items + 9 existing + this one = 50 → at the cap.
        let existing = (0 ..< 9).map { "d\($0).com" }
        let result = CustomDomains.evaluateAdd("new.com", existing: existing, otherItemCount: 40)
        #expect(result == .added("new.com", overLimit: true))
    }

    @Test func evaluateAddNotOverLimitOneBelowTheCap() {
        // 40 other + 8 existing + this one = 49 → under the cap.
        let existing = (0 ..< 8).map { "d\($0).com" }
        let result = CustomDomains.evaluateAdd("new.com", existing: existing, otherItemCount: 40)
        #expect(result == .added("new.com", overLimit: false))
    }
}
