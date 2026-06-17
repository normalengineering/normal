import Foundation

enum UITestSupport {
    private static let arguments = ProcessInfo.processInfo.arguments

    static let isActive = arguments.contains("-uiTestMode")

    static let skipOnboarding = arguments.contains("-uiTestSkipOnboarding")

    static let seedSchedule = arguments.contains("-uiTestSeedSchedule")

    static let noKeys = arguments.contains("-uiTestNoKeys")

    static let startBlocked = arguments.contains("-uiTestStartBlocked")

    static let customDomains = arguments.contains("-uiTestCustomDomains")

    static let seedGroupKey = arguments.contains("-uiTestSeedGroupKey")

    static let stubScanValue = "UITEST-SCAN-VALUE"
}
