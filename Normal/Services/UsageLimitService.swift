import DeviceActivity
import FamilyControls
import Foundation
import Observation
import OSLog

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

    /// Minutes of usage before a limit is hit that `eventWillReachThresholdWarning` fires.
    static let warningMinutes = SharedConstants.usageLimitWarningMinutes

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
        self.limitShield = limitShield
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
        sharedStore.saveUsageLimitConfig(config)
        syncShields(on: date)

        let specs = Self.eventSpecs(for: dtos).filter(\.isArmable)
        let fingerprint = Self.fingerprint(for: dtos, period: config.period, on: date)
        guard fingerprint != sharedStore.loadUsageRegistration() else { return }

        let activityName = DeviceActivityName(SharedConstants.usageLimitsActivityName)
        activityCenter.stopMonitoring([activityName])
        sharedStore.saveUsageRegistration(nil)

        guard !specs.isEmpty else {
            sharedStore.saveUsageRegistration(fingerprint)
            notifyUpdate()
            return
        }

        do {
            try activityCenter.startMonitoring(
                activityName,
                during: DeviceActivityScheduleFactory.daily(
                    resetMinutes: config.period.resetMinutes,
                    warningMinutes: Self.warningMinutes
                ),
                events: specs.reduce(into: [:]) { $0[$1.name] = $1.event }
            )
            sharedStore.saveUsageRegistration(fingerprint)
        } catch {
            // Every limit shares one activity, so a throw here disables all of
            // them. Leave the fingerprint cleared so the next launch retries.
            logger.error("Usage limit monitoring failed: \(error.localizedDescription, privacy: .public)")
        }
        notifyUpdate()
    }

    /// One threshold event per limit that still has something to watch.
    ///
    /// Split out from the `DeviceActivityEvent` construction so the naming and
    /// filtering rules are checkable without real `ManagedSettings` tokens.
    struct EventSpec: Equatable {
        let id: UUID
        let eventName: String
        let minutes: Int
        let selection: FamilyActivitySelection

        var name: DeviceActivityEvent.Name {
            DeviceActivityEvent.Name(eventName)
        }

        /// A selection with no tokens has nothing to meter. Registering it
        /// would leave a limit that looks armed but can never fire.
        var isArmable: Bool {
            !selection.isEmpty
        }

        var event: DeviceActivityEvent {
            DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minutes),
                // Accounts for usage already spent earlier in the interval, so
                // re-registering mid-day cannot refund an allowance.
                includesPastActivity: true
            )
        }
    }

    /// Drops only limits whose selection cannot be decoded; whether a spec is
    /// worth arming is `EventSpec.isArmable`, kept separate so the naming and
    /// threshold rules stay checkable without real `ManagedSettings` tokens.
    static func eventSpecs(for dtos: [UsageLimitDTO]) -> [EventSpec] {
        dtos.compactMap { dto in
            guard let selection = try? FamilyActivitySelection.fromData(dto.selectionData)
            else { return nil }
            return EventSpec(
                id: dto.id,
                eventName: SharedConstants.usageLimitEventName(for: dto.id),
                minutes: dto.minutesPerDay,
                selection: selection
            )
        }
    }

    static func fingerprint(for dtos: [UsageLimitDTO], period: UsagePeriod, on date: Date) -> String {
        let body = dtos
            .map { "\($0.id.uuidString):\($0.minutesPerDay):\($0.selectionData.stableChecksum)" }
            .sorted()
            .joined(separator: "|")
        return "\(period.key(for: date))@\(period.resetMinutes)#\(body)"
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
