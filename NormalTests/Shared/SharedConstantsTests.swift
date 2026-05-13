@testable import Normal
import Foundation
import Testing

struct SharedConstantsTests {
    @Test func appGroupIDIsNotEmpty() {
        #expect(!SharedConstants.appGroupID.isEmpty)
    }

    @Test func mainTimedUnblockActivityName() {
        #expect(SharedConstants.mainTimedUnblockActivityName == "timedUnblock_main")
    }

    @Test func groupTimedUnblockActivityNameContainsUUID() {
        let uuid = UUID()
        let name = SharedConstants.groupTimedUnblockActivityName(for: uuid)
        #expect(name.hasPrefix("timedUnblock_group_"))
        #expect(name.contains(uuid.uuidString))
    }

    @Test func scheduleActivityNameContainsUUID() {
        let uuid = UUID()
        let name = SharedConstants.scheduleActivityName(for: uuid)
        #expect(name.hasPrefix("schedule_"))
        #expect(name.contains(uuid.uuidString))
    }
}
