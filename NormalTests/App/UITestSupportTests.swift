import Testing

@testable import Normal

struct UITestSupportTests {
    @Test func unitTestBundleRunsInUnitTestHostMode() {
        #expect(UITestSupport.isUnitTestHost)
        #expect(!UITestSupport.isActive)
    }
}
