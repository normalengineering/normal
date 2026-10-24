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

    @Test func policyIsNilForEmptySet() {
        #expect(WebFilter.policy(for: []) == nil)
    }

    @Test func policyIsSpecificForNonEmptySet() {
        let policy = WebFilter.policy(for: domains("a.com"))
        #expect(policy == .specific(domains("a.com")))
    }

    @Test func policyIsAutoWhenBlockingAdultContentWithNoDomains() {
        #expect(WebFilter.policy(for: [], blockingAdultContent: true) == .auto([]))
    }

    @Test func policyKeepsCustomDomainsWhenBlockingAdultContent() {
        let policy = WebFilter.policy(for: domains("a.com", "b.com"), blockingAdultContent: true)
        #expect(policy == .auto(domains("a.com", "b.com")))
    }
}
