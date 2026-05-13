@testable import Normal
import Testing

struct AppTabTests {
    @Test func allCasesExist() {
        let cases = AppTab.allCases
        #expect(cases.count == 5)
        #expect(cases.contains(.home))
        #expect(cases.contains(.groups))
        #expect(cases.contains(.schedules))
        #expect(cases.contains(.appSelect))
        #expect(cases.contains(.keys))
    }

    @Test func labels() {
        #expect(AppTab.home.label == "Home")
        #expect(AppTab.groups.label == "Groups")
        #expect(AppTab.schedules.label == "Schedules")
        #expect(AppTab.appSelect.label == "App Select")
        #expect(AppTab.keys.label == "Keys")
    }
}
