@testable import Normal
import Testing

struct AppTabTests {
    @Test func labelsAreNonEmpty() {
        for tab in AppTab.allCases {
            #expect(!tab.label.isEmpty)
        }
    }

    @Test func labelsAreDistinct() {
        let labels = AppTab.allCases.map(\.label)
        #expect(Set(labels).count == labels.count)
    }

    @Test func rawValuesAreStable() {
        #expect(AppTab.home.rawValue == "home")
        #expect(AppTab.groups.rawValue == "groups")
        #expect(AppTab.schedules.rawValue == "schedules")
        #expect(AppTab.appSelect.rawValue == "appSelect")
        #expect(AppTab.keys.rawValue == "keys")
    }
}
