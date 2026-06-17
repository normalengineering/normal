@testable import Normal
import Testing

struct DomainNormalizerTests {
    @Test func stripsSchemeAndPath() {
        #expect(DomainNormalizer.normalize("https://reddit.com/r/swift") == "reddit.com")
        #expect(DomainNormalizer.normalize("http://example.com") == "example.com")
    }

    @Test func stripsQueryFragmentPortAndUserInfo() {
        #expect(DomainNormalizer.normalize("example.com:8080") == "example.com")
        #expect(DomainNormalizer.normalize("example.com/path?q=1#frag") == "example.com")
        #expect(DomainNormalizer.normalize("user@example.com") == "example.com")
    }

    @Test func stripsLeadingWww() {
        #expect(DomainNormalizer.normalize("www.reddit.com") == "reddit.com")
        // Only the leading www. is stripped, not embedded labels.
        #expect(DomainNormalizer.normalize("www.news.example.com") == "news.example.com")
    }

    @Test func lowercasesAndTrims() {
        #expect(DomainNormalizer.normalize("  Reddit.COM  ") == "reddit.com")
    }

    @Test func keepsSubdomains() {
        #expect(DomainNormalizer.normalize("news.ycombinator.com") == "news.ycombinator.com")
    }

    @Test func rejectsInvalidInput() {
        #expect(DomainNormalizer.normalize("") == nil)
        #expect(DomainNormalizer.normalize("notadomain") == nil)
        #expect(DomainNormalizer.normalize("reddit") == nil)
        #expect(DomainNormalizer.normalize(".com") == nil)
        #expect(DomainNormalizer.normalize("example.") == nil)
        #expect(DomainNormalizer.normalize("exa mple.com") == nil)
        #expect(DomainNormalizer.normalize("under_score.com") == nil)
        #expect(DomainNormalizer.normalize("-bad.com") == nil)
        #expect(DomainNormalizer.normalize("example.123") == nil)
    }

    @Test func normalizeAllDedupesPreservingOrder() {
        let input = ["www.reddit.com", "https://Reddit.com/r/x", "news.com", "bad", "news.com"]
        #expect(DomainNormalizer.normalize(all: input) == ["reddit.com", "news.com"])
    }
}
