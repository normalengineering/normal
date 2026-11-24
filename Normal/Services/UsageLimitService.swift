import DeviceActivity
import FamilyControls
import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class UsageLimitService {
    private let activityCenter: any DeviceActivityProviding
    private let sharedStore: any SharedStoreProviding
    private let ledger: any UsageLimitLedger
    private let limitShield: any DailyLimitShielding

    /// Bumped whenever shared-extension state may have changed, so views that
    /// read through `sharedStore` re-evaluate. Mirrors `ScreenTimeService`.
    private(set) var lastUpdate: Date = .now

    private(set) var resetAnchor: Date?

    private(set) var registrationFailure: UsageLimitRegistrationFailure?

    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "UsageLimits")

    init(
        activityCenter: any DeviceActivityProviding = DeviceActivityCenter(),
        sharedStore: any SharedStoreProviding = SharedStore(),
        ledger: any UsageLimitLedger = KeychainUsageLimitLedger(),
        limitShield: (any DailyLimitShielding)? = nil
    ) {
        self.activityCenter = activityCenter
        self.sharedStore = sharedStore
        self.ledger = ledger
        self.limitShield =
            limitShield
            ?? (UITestSupport.isActive ? InMemoryDailyLimitShield() : ManagedSettingsDailyLimitShield())
        resetAnchor = ledger.loadLastLoosened()
    }

    func notifyUpdate() {
        lastUpdate = .now
    }

    // MARK: - Registration

    func registerAll(_ limits: [UsageLimit], config: UsageLimitConfig, on date: Date = .now) {
        let dtos = limits.compactMap { $0.toDTO() }
        if dtos.count != limits.count {
            logger.error("Dropped \(limits.count - dtos.count, privacy: .public) limit(s) that failed to encode")
        }
        sharedStore.saveUsageLimits(dtos)
        let previous = sharedStore.loadUsageLimitConfig()
        if previous.resetMinutes != config.resetMinutes {
            sharedStore.moveUsageDay(from: previous.period, to: config.period, on: date)
        }
        sharedStore.saveUsageLimitConfig(config)
        syncShields(on: date)

        do {
            try DailyLimitMonitoring.reconcile(center: activityCenter, store: sharedStore, on: date, source: "app")
            registrationFailure = nil
        } catch {
            registrationFailure = UsageLimitRegistrationFailure(error)
            logger.error("Usage limit monitoring failed: \(error.localizedDescription, privacy: .public)")
        }
        activityCenter.syncHeartbeat(sharedStore: sharedStore, at: date)
        notifyUpdate()
    }

    // MARK: - Today's state

    func state(for limit: UsageLimit, on date: Date = .now) -> UsageLimitState {
        _ = lastUpdate
        return sharedStore.usageState(for: limit.id, on: date)
    }

    func states(for limits: [UsageLimit], on date: Date = .now) -> [UUID: UsageLimitState] {
        _ = lastUpdate
        return sharedStore.usageStates(for: limits.map(\.id), on: date)
    }

    func countsTimeUsedEarlierToday(by limit: UsageLimit?, on date: Date = .now) -> Bool {
        guard let limit else { return false }
        return sharedStore.usagePeriod.countsPastActivity(createdAt: limit.createdAt, on: date)
    }

    func nextReset(after date: Date = .now) -> Date {
        _ = lastUpdate
        return sharedStore.usagePeriod.nextReset(after: date)
    }

    func isDayOverridden(on date: Date = .now) -> Bool {
        _ = lastUpdate
        return sharedStore.isUsageDayOverridden(on: date)
    }

    func resetLockState(now: Date = .now) -> UsageLimitLockState {
        UsageLimitEditPolicy.lockState(anchor: resetAnchor, now: now)
    }

    func decideResetChange(now: Date = .now) -> UsageLimitEditDecision {
        UsageLimitEditPolicy.decide(.changeReset, anchor: resetAnchor, now: now)
    }

    func resetLockRefreshDates() -> [Date] {
        UsageLimitEditPolicy.refreshDates(anchor: resetAnchor)
    }

    func commitResetChange(_ allowance: UsageLimitEditAllowance, now: Date = .now) {
        let anchor = UsageLimitEditPolicy.anchor(
            after: allowance,
            current: resetAnchor,
            now: now
        )
        ledger.saveLastLoosened(anchor)
        resetAnchor = anchor
        notifyUpdate()
    }

    func overrideToday(on date: Date = .now) {
        sharedStore.overrideUsageDay(on: date)
        limitShield.apply([], preventsAppDelete: false)
        notifyUpdate()
    }

    func clearState(for limit: UsageLimit, on date: Date = .now) {
        sharedStore.clearUsageState(for: limit.id, on: date)
        syncShields(on: date)
        notifyUpdate()
    }

    private func syncShields(on date: Date) {
        limitShield.apply(
            sharedStore.reachedUsageLimits(on: date),
            preventsAppDelete: sharedStore.loadUsageLimitConfig().preventsAppDelete
        )
    }
}

enum UsageLimitRegistrationFailure: Equatable {
    case tooManyActivities
    case failed

    init(_ error: any Error) {
        switch error {
        case DeviceActivityCenter.MonitoringError.excessiveActivities:
            self = .tooManyActivities
        default:
            self = .failed
        }
    }

    var message: String {
        switch self {
        case .tooManyActivities:
            String(
                localized:
                    "Daily limits are off: iOS only tracks 20 schedules and timers at once. Turn off a schedule and they'll start the next time you open Normal."
            )
        case .failed:
            String(localized: "Daily limits are off: iOS couldn't start them. Normal tries again each time you open it.")
        }
    }
}
