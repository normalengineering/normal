import Foundation

enum SharedConstants {
    static let appGroupID = "group.com.normalengineering.block"

    enum DefaultsKey {
        static let timedUnblocks = "timedUnblocks_v1"
        static let schedules = "schedules_v1"
        static let scheduleOverride = "scheduleOverride_v1"
        static let widgetGroups = "widgetGroups_v1"
        static let widgetKeyTypes = "widgetKeyTypes_v1"
        static let widgetBlockStatuses = "widgetBlockStatuses_v1"
    }

    static let mainTimedUnblockActivityName = "timedUnblock_main"

    static func groupTimedUnblockActivityName(for groupId: UUID) -> String {
        "timedUnblock_group_\(groupId.uuidString)"
    }

    static func scheduleActivityName(for id: UUID) -> String {
        "schedule_\(id.uuidString)"
    }
}
