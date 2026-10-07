import Foundation

enum UITestSupport {
    private static let arguments = ProcessInfo.processInfo.arguments

    static let isActive = arguments.contains("-uiTestMode")

    static let isUnitTestHost = !isActive
        && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    static let skipOnboarding = arguments.contains("-uiTestSkipOnboarding")

    static let seedSchedule = arguments.contains("-uiTestSeedSchedule")

    static let noKeys = arguments.contains("-uiTestNoKeys")

    static let startBlocked = arguments.contains("-uiTestStartBlocked")

    static let customDomains = arguments.contains("-uiTestCustomDomains")

    static let seedGroupKey = arguments.contains("-uiTestSeedGroupKey")

    static let seedGroupID = UUID(uuidString: "6E0A1C9B-2D4F-4B7A-9C3E-5F8D1A2B3C4D")!

    static let skipBypassConfirm = arguments.contains("-uiTestSkipBypassConfirm")

    static let unblockDurationSeconds: [Int]? = value(after: "-uiTestUnblockDurations")?
        .split(separator: ",")
        .compactMap { Int($0) }

    static let defaultDurationSeconds: Int? = value(after: "-uiTestDefaultDuration").flatMap(Int.init)

    static let stubScanValue = "UITEST-SCAN-VALUE"

    private static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
