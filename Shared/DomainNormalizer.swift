import Foundation

nonisolated enum DomainNormalizer {
    static func normalize(_ raw: String) -> String? {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty else { return nil }

        if let range = host.range(of: "://") {
            host = String(host[range.upperBound...])
        }

        if let cut = host.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
            host = String(host[..<cut])
        }

        if let at = host.lastIndex(of: "@") {
            host = String(host[host.index(after: at)...])
        }
        if let colon = host.firstIndex(of: ":") {
            host = String(host[..<colon])
        }

        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }

        guard isValidHost(host) else { return nil }
        return host
    }

    static func normalize(all raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in raw {
            guard let normalized = normalize(value), seen.insert(normalized).inserted else { continue }
            result.append(normalized)
        }
        return result
    }

    private static func isValidHost(_ host: String) -> Bool {
        guard host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".") else { return false }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }

        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        for label in labels {
            guard !label.isEmpty,
                  !label.hasPrefix("-"),
                  !label.hasSuffix("-"),
                  label.allSatisfy({ allowed.contains($0) })
            else { return false }
        }

        guard let tld = labels.last, tld.allSatisfy(\.isLetter) else { return false }
        return true
    }
}
