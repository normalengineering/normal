import Foundation
@testable import Normal

final class FakeSharedStore: SharedStoreProviding, @unchecked Sendable {
    var timedUnblocks: [TimedUnblockDTO] = []
    var schedules: [ScheduleDTO] = []
    var scheduleOverrideActive = false
    var scheduleOverrideSince: Date?
    var customDomainsEnabled = false
    var adultContentEnabled = false
    var hideBlockedAppsEnabled = false
    var usageLimits: [UsageLimitDTO] = []
    var usageDayState: UsageDayStateDTO = .empty
    var usageRegistration: String?
    var manualBlockState: ManualBlockState?
    private(set) var manualBlockStateSaveCount = 0

    func loadTimedUnblocks() -> [TimedUnblockDTO] {
        timedUnblocks
    }

    func saveTimedUnblocks(_ unblocks: [TimedUnblockDTO]) {
        timedUnblocks = unblocks
    }

    func upsertTimedUnblock(_ unblock: TimedUnblockDTO) {
        timedUnblocks.removeAll { $0.id == unblock.id }
        timedUnblocks.append(unblock)
    }

    func removeTimedUnblock(id: String) {
        timedUnblocks.removeAll { $0.id == id }
    }

    func findTimedUnblock(activityName: String) -> TimedUnblockDTO? {
        timedUnblocks.first { $0.activityName == activityName }
    }

    func saveSchedules(_ dtos: [ScheduleDTO]) {
        schedules = dtos
    }

    func loadSchedules() -> [ScheduleDTO] {
        schedules
    }

    func isScheduleOverrideActive() -> Bool {
        scheduleOverrideActive
    }

    func loadScheduleOverrideSince() -> Date? {
        scheduleOverrideSince
    }

    func isCustomDomainsEnabled() -> Bool {
        customDomainsEnabled
    }

    func setCustomDomainsEnabled(_ enabled: Bool) {
        customDomainsEnabled = enabled
    }

    func isAdultContentEnabled() -> Bool {
        adultContentEnabled
    }

    func setAdultContentEnabled(_ enabled: Bool) {
        adultContentEnabled = enabled
    }

    func isHideBlockedAppsEnabled() -> Bool {
        hideBlockedAppsEnabled
    }

    func setHideBlockedAppsEnabled(_ enabled: Bool) {
        hideBlockedAppsEnabled = enabled
    }

    func saveUsageLimits(_ limits: [UsageLimitDTO]) {
        usageLimits = limits
    }

    func loadUsageLimits() -> [UsageLimitDTO] {
        usageLimits
    }

    func saveUsageDayState(_ state: UsageDayStateDTO) {
        usageDayState = state
    }

    func loadUsageDayState() -> UsageDayStateDTO {
        usageDayState
    }

    func saveUsageRegistration(_ fingerprint: String?) {
        usageRegistration = fingerprint
    }

    func loadUsageRegistration() -> String? {
        usageRegistration
    }

    var usageLimitsIntervalStart: Date?
    func saveUsageLimitsIntervalStart(_ date: Date) {
        usageLimitsIntervalStart = date
    }

    func loadUsageLimitsIntervalStart() -> Date? {
        usageLimitsIntervalStart
    }

    var usageLimitConfig = UsageLimitConfig()
    func saveUsageLimitConfig(_ config: UsageLimitConfig) {
        usageLimitConfig = config
    }

    func loadUsageLimitConfig() -> UsageLimitConfig {
        usageLimitConfig
    }

    func saveManualBlockState(_ state: ManualBlockState) {
        manualBlockState = state
        manualBlockStateSaveCount += 1
    }

    func loadManualBlockState() -> ManualBlockState? {
        manualBlockState
    }
}
