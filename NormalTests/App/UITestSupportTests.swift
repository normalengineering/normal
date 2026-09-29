@testable import Normal
import Testing

struct UITestSupportTests {
    @Test func unitTestBundleRunsInUnitTestHostMode() {
        #expect(UITestSupport.isUnitTestHost)
        #expect(!UITestSupport.isActive)
    }
}
