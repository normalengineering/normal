import Foundation

enum CustomDomains {
    static func subset(_ chosen: [String], of main: [String]) -> [String] {
        let allowed = Set(main)
        return chosen.filter(allowed.contains)
    }

    static func needsResync(_ chosen: [String], main: [String]) -> Bool {
        !Set(chosen).isSubset(of: Set(main))
    }

    enum AddResult: Equatable {
        case invalid
        case duplicate(String)
        case added(String, overLimit: Bool)
    }

    static func evaluateAdd(_ raw: String, existing: [String], otherItemCount: Int) -> AddResult {
        guard let domain = DomainNormalizer.normalize(raw) else { return .invalid }
        guard !existing.contains(domain) else { return .duplicate(domain) }
        let totalAfterAdd = otherItemCount + existing.count + 1
        return .added(domain, overLimit: totalAfterAdd >= ScreenTimeLimits.maxBlockedItems)
    }
}
