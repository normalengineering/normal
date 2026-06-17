import ManagedSettings
@testable import Normal
import Testing

struct WebFilterTests {
    private func domains(_ strings: String...) -> Set<WebDomain> {
        Set(strings.map { WebDomain(domain: $0) })
    }

    @Test func webDomainsNormalizesAndDedupes() {
        let result = WebFilter.webDomains(from: ["https://www.Reddit.com", "reddit.com", "bad"])
        #expect(result == domains("reddit.com"))
    }

    @Test func unionAddsDomains() {
        let current = domains("a.com")
        #expect(WebFilter.union(current: current, adding: ["b.com"]) == domains("a.com", "b.com"))
    }

    @Test func subtractRemovesDomains() {
        let current = domains("a.com", "b.com")
        #expect(WebFilter.subtract(current: current, removing: ["b.com"]) == domains("a.com"))
    }

    @Test func subtractIsNotRefcounted() {
        let current = WebFilter.union(current: domains("shared.com"), adding: ["shared.com"])
        #expect(WebFilter.subtract(current: current, removing: ["shared.com"]).isEmpty)
    }

    @Test func policyIsNilForEmptySet() {
        #expect(WebFilter.policy(for: []) == nil)
    }

    @Test func policyIsSpecificForNonEmptySet() {
        let policy = WebFilter.policy(for: domains("a.com"))
        #expect(policy == .specific(domains("a.com")))
    }
}
