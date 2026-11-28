import Foundation

enum EditProtectionMode: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case requireKey = "requireKey"
    case unblockAll = "unblockAll"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .requireKey: String(localized: "With a Key")
        case .unblockAll: String(localized: "When All Apps Unblocked")
        }
    }

    var shortLabel: String {
        switch self {
        case .requireKey: String(localized: "With a Key")
        case .unblockAll: String(localized: "All Unblocked")
        }
    }

    var description: String {
        switch self {
        case .requireKey:
            String(localized: "Scan a global key to unblock editing. Blocked apps stay blocked.")
        case .unblockAll:
            String(localized: "Editing is available whenever no apps are blocked.")
        }
    }

    var footer: String {
        switch self {
        case .requireKey:
            String(localized: "Protects apps, groups, schedules, and keys even when no apps are blocked.")
        case .unblockAll:
            String(localized: "When a schedule unblocks all apps, editing becomes available without a key.")
        }
    }
}
