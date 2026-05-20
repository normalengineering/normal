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

    var selectedTokenCounts: String {
        Self.selectedTokenCounts(
            apps: applicationTokens.count,
            websites: webDomainTokens.count,
            categories: categoryTokens.count
        )
    }

    static func selectedTokenCounts(apps: Int, websites: Int, categories: Int) -> String {
        var parts: [String] = []
        if apps > 0 {
            parts.append(String(localized: "^[\(apps) App](inflect: true)"))
        }
        if websites > 0 {
            parts.append(String(localized: "^[\(websites) Website](inflect: true)"))
        }
        if categories > 0 {
            parts.append(String(localized: "^[\(categories) Category](inflect: true)"))
        }
        if parts.isEmpty {
            return String(localized: "No items selected")
        }
        return parts.joined(separator: ", ")
    }

    func isSubset(of other: FamilyActivitySelection) -> Bool {
        applicationTokens.isSubset(of: other.applicationTokens)
            && webDomainTokens.isSubset(of: other.webDomainTokens)
            && categoryTokens.isSubset(of: other.categoryTokens)
    }
}

enum SelectedTokenKind: Hashable {
    case application(ApplicationToken)
    case webDomain(WebDomainToken)
    case category(ActivityCategoryToken)

    init?(_ hashable: AnyHashable) {
        let base = hashable.base
        if let token = base as? ApplicationToken { self = .application(token); return }
        if let token = base as? WebDomainToken { self = .webDomain(token); return }
        if let token = base as? ActivityCategoryToken { self = .category(token); return }
        return nil
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
