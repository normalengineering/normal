import FamilyControls
import Foundation
import ManagedSettings

extension FamilyActivitySelection {
    var allTokens: [AnyHashable] {
        applicationTokens.asHashableArray
            + webDomainTokens.asHashableArray
            + categoryTokens.asHashableArray
    }

    var isEmpty: Bool {
        applicationTokens.isEmpty
            && webDomainTokens.isEmpty
            && categoryTokens.isEmpty
    }

    var count: Int {
        applicationTokens.count + webDomainTokens.count + categoryTokens.count
    }

    func isSubset(of other: FamilyActivitySelection) -> Bool {
        applicationTokens.isSubset(of: other.applicationTokens)
            && webDomainTokens.isSubset(of: other.webDomainTokens)
            && categoryTokens.isSubset(of: other.categoryTokens)
    }
}

extension Optional where Wrapped == FamilyActivitySelection {
    var isEmpty: Bool { self?.isEmpty ?? true }
    var count: Int { self?.count ?? 0 }
    var allTokens: [AnyHashable] { self?.allTokens ?? [] }
}

extension Set where Element: Hashable {
    var asHashableArray: [AnyHashable] {
        Array(self) as [AnyHashable]
    }
}

extension Set where Element: Encodable {
    var sortedStably: [Element] {
        sorted { encodedKey($0) < encodedKey($1) }
    }
}

extension [AnyHashable] {
    var sortedStably: [AnyHashable] {
        sorted { stableSortKey(for: $0) < stableSortKey(for: $1) }
    }
}

private func stableSortKey(for hashable: AnyHashable) -> String {
    let base = hashable.base
    if let token = base as? ApplicationToken { return encodedKey(token) }
    if let token = base as? WebDomainToken { return encodedKey(token) }
    if let token = base as? ActivityCategoryToken { return encodedKey(token) }
    return String(describing: base)
}

private func encodedKey<T: Encodable>(_ value: T) -> String {
    (try? PropertyListEncoder().encode(value))?.base64EncodedString()
        ?? String(describing: value)
}
