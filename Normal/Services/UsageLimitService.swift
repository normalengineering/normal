import DeviceActivity
import FamilyControls
import Foundation
import Observation
import OSLog

/// Owns daily usage limits: registers the `DeviceActivity` threshold events that
/// enforce them, reads back the state the monitor extension writes, and applies
/// the weekly rules for loosening them.
///
/// Usage totals themselves are never readable — `DeviceActivity` only reports
/// threshold crossings — so every "how much is left" answer here is a state, not
/// a number.
@MainActor
@Observable
final class UsageLimitService {
    private let activityCenter: any DeviceActivityProviding
    private let sharedStore: any SharedStoreProviding
    private let ledger: any UsageLimitLedger

    /// Bumped whenever shared-extension state may have changed, so views that
    /// read through `sharedStore` re-evaluate. Mirrors `ScreenTimeService`.
    private(set) var lastUpdate: Date = .now

    /// Cached so views can read the weekly lock without a Keychain hit per render.
    private(set) var lastLoosenedAt: Date?

    /// Minutes of usage before a limit is hit that `eventWillReachThresholdWarning` fires.
    ///
    /// Must stay below `UsageLimit.minimumMinutes`, or the shortest limit would
    /// report "Almost Up" from the first minute of the day.
    static let warningMinutes = 3

    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "UsageLimits")

    init(
        activityCenter: any DeviceActivityProviding = DeviceActivityCenter(),
        sharedStore: any SharedStoreProviding = SharedStore(),
        ledger: any UsageLimitLedger = KeychainUsageLimitLedger()
    ) {
        self.activityCenter = activityCenter
        self.sharedStore = sharedStore
        self.ledger = ledger
        lastLoosenedAt = ledger.loadLastLoosened()
    }

    func notifyUpdate() {
        lastUpdate = .now
    }

    // MARK: - Registration

    /// Mirrors limits to the app group and re-registers the daily activity.
    ///
    /// Safe to call on every launch and after every edit: `includesPastActivity`
    /// makes a re-registered event account for usage already spent today, so
    /// re-registering cannot hand back a fresh allowance.
    func registerAll(_ limits: [UsageLimit], on date: Date = .now) {
        let dtos = limits.compactMap { $0.toDTO() }
        if dtos.count != limits.count {
            logger.error("Dropped \(limits.count - dtos.count, privacy: .public) limit(s) that failed to encode")
        }
        sharedStore.saveUsageLimits(dtos)

        // An emergency unblock outranks the caps for the rest of the day, so
        // arming their events would just re-block minutes later.
        let overridden = sharedStore.isUsageDayOverridden(on: date)
        let specs = overridden ? [] : Self.eventSpecs(for: dtos).filter(\.isArmable)
        let fingerprint = Self.fingerprint(for: dtos, overridden: overridden, on: date)
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
                during: DeviceActivityScheduleFactory.daily(warningMinutes: Self.warningMinutes),
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

        var name: DeviceActivityEvent.Name { DeviceActivityEvent.Name(eventName) }

        /// A selection with no tokens has nothing to meter. Registering it
        /// would leave a limit that looks armed but can never fire.
        var isArmable: Bool { !selection.isEmpty }

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

    /// Identifies a registration so an unchanged one can be skipped.
    ///
    /// `registerAll` runs on every foreground; tearing monitoring down and
    /// re-arming it that often risks disturbing threshold accumulation, so it
    /// only happens when the limits actually changed or the day rolled over.
    ///
    /// Derived from the limits rather than the armed events, so a limit that
    /// currently has nothing to meter still counts as a change once it does.
    static func fingerprint(for dtos: [UsageLimitDTO], overridden: Bool, on date: Date) -> String {
        let body = dtos
            .map { "\($0.id.uuidString):\($0.minutesPerDay):\($0.selectionData.stableChecksum)" }
            .sorted()
            .joined(separator: "|")
        return "\(UsageDayKey.key(for: date))#\(overridden ? "override" : "armed")#\(body)"
    }

    // MARK: - Today's state

    func state(for limit: UsageLimit, on date: Date = .now) -> UsageLimitState {
        _ = lastUpdate
        return sharedStore.usageState(for: limit.id, on: date)
    }

    func nextReset(after date: Date = .now) -> Date {
        UsageDayKey.nextReset(after: date)
    }

    func isDayOverridden(on date: Date = .now) -> Bool {
        _ = lastUpdate
        return sharedStore.isUsageDayOverridden(on: date)
    }

    // MARK: - Weekly change policy

    func lockState(now: Date = .now) -> UsageLimitLockState {
        UsageLimitEditPolicy.lockState(lastLoosenedAt: lastLoosenedAt, now: now)
    }

    func decide(_ edit: UsageLimitEdit, now: Date = .now) -> UsageLimitEditDecision {
        UsageLimitEditPolicy.decide(edit, lastLoosenedAt: lastLoosenedAt, now: now)
    }

    /// Persists the weekly anchor after an allowed change. Only a change made
    /// outside the grace window starts a new week.
    func commit(_ allowance: UsageLimitEditAllowance, now: Date = .now) {
        let anchor = UsageLimitEditPolicy.anchor(
            after: allowance,
            current: lastLoosenedAt,
            now: now
        )
        ledger.saveLastLoosened(anchor)
        lastLoosenedAt = anchor
        notifyUpdate()
    }

    /// Wipes every limit's state for today.
    ///
    /// Reserved for emergency unblock: that escape hatch is already rationed to
    /// three uses per 180 days, so it outranks the daily cap rather than being
    /// silently undone by the usage floor in `ScreenTimeService`.
    func overrideToday(on date: Date = .now) {
        sharedStore.overrideUsageDay(on: date)
        // Disarm the events too. Clearing the record alone is not enough: the
        // next re-registration would re-fire every already-spent threshold and
        // silently undo an unblock that cost one of three per 180 days.
        activityCenter.stopMonitoring([DeviceActivityName(SharedConstants.usageLimitsActivityName)])
        sharedStore.saveUsageRegistration(nil)
        notifyUpdate()
    }

    /// Drops today's record for one limit and lifts the shields the monitor
    /// applied when it ran out, so a raised ceiling takes effect immediately
    /// rather than leaving its apps blocked while the UI reads "Available".
    func clearState(
        for limit: UsageLimit,
        screenTimeService: any ScreenTimeProviding,
        on date: Date = .now
    ) {
        let wasReached = sharedStore.usageState(for: limit.id, on: date) == .reached
        sharedStore.clearUsageState(for: limit.id, on: date)
        if wasReached {
            screenTimeService.removeFromShields(selection: limit.selection, customDomains: [])
        }
        notifyUpdate()
    }
}
