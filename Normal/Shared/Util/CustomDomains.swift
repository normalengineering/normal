import Foundation

/// Pure logic for custom-domain editing, factored out of the SwiftUI views so it
/// can be unit-tested directly.
enum CustomDomains {
    /// Keep only the chosen domains that still exist in the main list, preserving
    /// order. Enforces the subset invariant when a group/schedule is saved.
    static func subset(_ chosen: [String], of main: [String]) -> [String] {
        let allowed = Set(main)
        return chosen.filter(allowed.contains)
    }

    /// A group/schedule needs re-selection when it references a domain that is no
    /// longer in the main list.
    static func needsResync(_ chosen: [String], main: [String]) -> Bool {
        !Set(chosen).isSubset(of: Set(main))
    }

    enum AddResult: Equatable {
        case invalid
        case duplicate(String)
        /// `overLimit` is true when this addition lands at or beyond the Screen
        /// Time cap (a soft warning — the add still happens).
        case added(String, overLimit: Bool)
    }

    /// Decides what happens when the user submits `raw` in the editor.
    static func evaluateAdd(_ raw: String, existing: [String], otherItemCount: Int) -> AddResult {
        guard let domain = DomainNormalizer.normalize(raw) else { return .invalid }
        guard !existing.contains(domain) else { return .duplicate(domain) }
        let totalAfterAdd = otherItemCount + existing.count + 1
        return .added(domain, overLimit: totalAfterAdd >= ScreenTimeLimits.maxBlockedItems)
    }
}
