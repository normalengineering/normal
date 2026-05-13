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
}
