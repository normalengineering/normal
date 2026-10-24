import ManagedSettings

extension ManagedSettingsStore {
    func filterDomains() -> Set<WebDomain> {
        switch webContent.blockedByFilter {
        case let .specific(domains)?: domains
        case let .auto(domains, _)?: domains
        default: []
        }
    }

    var blocksAdultContent: Bool {
        if case .auto? = webContent.blockedByFilter { return true }
        return false
    }

    func replaceFilter(domains: [String], blockingAdultContent: Bool) {
        webContent.blockedByFilter = WebFilter.policy(
            for: WebFilter.webDomains(from: domains),
            blockingAdultContent: blockingAdultContent
        )
    }
}

enum WebFilter {
    static func webDomains(from domains: [String]) -> Set<WebDomain> {
        Set(domains.compactMap(DomainNormalizer.normalize).map { WebDomain(domain: $0) })
    }

    static func policy(
        for domains: Set<WebDomain>,
        blockingAdultContent: Bool = false
    ) -> WebContentSettings.FilterPolicy? {
        if blockingAdultContent {
            return .auto(domains)
        }
        return domains.isEmpty ? nil : .specific(domains)
    }
}
