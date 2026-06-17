import ManagedSettings

extension ManagedSettingsStore {
    func filterDomains() -> Set<WebDomain> {
        if case let .specific(domains)? = webContent.blockedByFilter {
            return domains
        }
        return []
    }

    func unionFilterDomains(_ domains: [String]) {
        guard !domains.isEmpty else { return }
        writeFilter(WebFilter.union(current: filterDomains(), adding: domains))
    }

    func subtractFilterDomains(_ domains: [String]) {
        guard !domains.isEmpty else { return }
        writeFilter(WebFilter.subtract(current: filterDomains(), removing: domains))
    }

    func replaceFilterDomains(_ domains: [String]) {
        writeFilter(WebFilter.webDomains(from: domains))
    }

    func clearFilterDomains() {
        webContent.blockedByFilter = nil
    }

    private func writeFilter(_ domains: Set<WebDomain>) {
        webContent.blockedByFilter = WebFilter.policy(for: domains)
    }
}

enum WebFilter {
    static func webDomains(from domains: [String]) -> Set<WebDomain> {
        Set(domains.compactMap(DomainNormalizer.normalize).map { WebDomain(domain: $0) })
    }

    static func union(current: Set<WebDomain>, adding domains: [String]) -> Set<WebDomain> {
        current.union(webDomains(from: domains))
    }

    static func subtract(current: Set<WebDomain>, removing domains: [String]) -> Set<WebDomain> {
        current.subtracting(webDomains(from: domains))
    }

    static func policy(for domains: Set<WebDomain>) -> WebContentSettings.FilterPolicy? {
        domains.isEmpty ? nil : .specific(domains)
    }
}
