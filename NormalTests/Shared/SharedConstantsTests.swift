@testable import Normal
import Foundation
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

    @Test func scheduleActivityNameIsPrefixed() {
        let id = UUID()
        let name = SharedConstants.scheduleActivityName(for: id)
        #expect(name.hasPrefix("schedule_"))
        #expect(name.contains(id.uuidString))
    }
}
