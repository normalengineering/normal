import Foundation

enum SharedConstants {
    static let appGroupID = "group.com.normalengineering.block"

    enum DefaultsKey {
        static let timedUnblocks = "timedUnblocks_v1"
        static let schedules = "schedules_v1"
        static let scheduleOverride = "scheduleOverride_v1"
        static let customDomainsEnabled = "customDomainsEnabled_v1"
        static let widgetGroups = "widgetGroups_v1"
        static let widgetKeyTypes = "widgetKeyTypes_v1"
        static let widgetBlockStatuses = "widgetBlockStatuses_v1"
        static let usageLimits = "usageLimits_v1"
        static let usageDayState = "usageDayState_v1"
        static let usageRegistration = "usageRegistration_v1"
        static let usageLimitsIntervalStart = "usageLimitsIntervalStart_v1"
    }

    static let mainTimedUnblockActivityName = "timedUnblock_main"

    static func groupTimedUnblockActivityName(for groupId: UUID) -> String {
        "timedUnblock_group_\(groupId.uuidString)"
    }

    static func scheduleActivityName(for id: UUID) -> String {
        "schedule_\(id.uuidString)"
    }

    /// Single repeating midnight-to-midnight activity that carries one
    /// threshold event per usage limit.
    static let usageLimitsActivityName = "usageLimits_daily"

    private static let usageEventPrefix = "usage_"

    static func usageLimitEventName(for id: UUID) -> String {
        usageEventPrefix + id.uuidString
    }

    static func usageLimitID(fromEventName name: String) -> UUID? {
        guard name.hasPrefix(usageEventPrefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(usageEventPrefix.count)))
    }
}
