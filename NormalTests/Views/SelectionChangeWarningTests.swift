import Testing

@testable import Normal

struct SelectionChangeWarningTests {
    @Test func noWarningWithoutGroupsOrSchedules() {
        #expect(SelectionChangeWarning(hasGroups: false, hasSchedules: false) == nil)
    }

    @Test func warnsAboutGroupsOnly() {
        #expect(SelectionChangeWarning(hasGroups: true, hasSchedules: false) == .groups)
    }

    @Test func warnsAboutSchedulesOnly() {
        #expect(SelectionChangeWarning(hasGroups: false, hasSchedules: true) == .schedules)
    }

    @Test func warnsAboutGroupsAndSchedules() {
        #expect(SelectionChangeWarning(hasGroups: true, hasSchedules: true) == .groupsAndSchedules)
    }
}
