import Foundation
@testable import Normal
import Testing

struct SharedConstantsTests {
    @Test func appGroupIDIsStable() {
        #expect(SharedConstants.appGroupID == "group.com.normalengineering.block")
    }

    @Test func defaultsKeysAreVersioned() {
        #expect(SharedConstants.DefaultsKey.timedUnblocks.hasSuffix("_v1"))
        #expect(SharedConstants.DefaultsKey.schedules.hasSuffix("_v1"))
    }

    @Test func mainTimedUnblockActivityNameIsStable() {
        #expect(SharedConstants.mainTimedUnblockActivityName == "timedUnblock_main")
    }

    @Test func groupTimedUnblockActivityNameIsPrefixed() {
        let id = UUID()
        let name = SharedConstants.groupTimedUnblockActivityName(for: id)
        #expect(name.hasPrefix("timedUnblock_group_"))
        #expect(name.contains(id.uuidString))
    }

    /// Renaming these orphans activities and defaults blobs already written on
    /// device, so they are pinned like the rest.
    @Test func usageLimitsActivityNameIsStable() {
        #expect(SharedConstants.usageLimitsActivityName == "usageLimits_daily")
    }

    @Test func usageDefaultsKeysAreStable() {
        #expect(SharedConstants.DefaultsKey.usageLimits == "usageLimits_v1")
        #expect(SharedConstants.DefaultsKey.usageDayState == "usageDayState_v1")
        #expect(SharedConstants.DefaultsKey.usageRegistration == "usageRegistration_v1")
        #expect(SharedConstants.DefaultsKey.usageLimitsIntervalStart == "usageLimitsIntervalStart_v1")
    }

    @Test func usageLimitEventNamesRoundTrip() {
        let id = UUID()

        #expect(SharedConstants.usageLimitID(fromEventName: SharedConstants.usageLimitEventName(for: id)) == id)
        #expect(SharedConstants.usageLimitID(fromEventName: "schedule_\(id.uuidString)") == nil)
        #expect(SharedConstants.usageLimitID(fromEventName: "usage_not-a-uuid") == nil)
    }

    @Test func scheduleActivityNameIsPrefixed() {
        let id = UUID()
        let name = SharedConstants.scheduleActivityName(for: id)
        #expect(name.hasPrefix("schedule_"))
        #expect(name.contains(id.uuidString))
    }
}
