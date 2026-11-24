import DeviceActivity
import FamilyControls
import Foundation
import OSLog

private nonisolated let dailyLimitMonitoringLogger = Logger(
    subsystem: "com.normalengineering.normal",
    category: "UsageLimits"
)

protocol DeviceActivityProviding {
    func startMonitoring(
        _ activityName: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws

    func stopMonitoring(_ activityNames: [DeviceActivityName])

    var monitoredActivityNames: Set<String> { get }

    func registeredSchedule(for activityName: DeviceActivityName) -> DeviceActivitySchedule?

    func events(for activity: DeviceActivityName) -> [DeviceActivityEvent.Name: DeviceActivityEvent]
}

extension DeviceActivityCenter: DeviceActivityProviding {
    var monitoredActivityNames: Set<String> {
        Set(activities.map(\.rawValue))
    }

    func registeredSchedule(for activityName: DeviceActivityName) -> DeviceActivitySchedule? {
        schedule(for: activityName)
    }
}

extension DeviceActivitySchedule {
    func hasSameWindow(as other: DeviceActivitySchedule) -> Bool {
        repeats == other.repeats
            && Self.time(intervalStart) == Self.time(other.intervalStart)
            && Self.time(intervalEnd) == Self.time(other.intervalEnd)
    }

    private static func time(_ components: DateComponents) -> [Int?] {
        [components.year, components.month, components.day, components.hour, components.minute, components.second ?? 0]
    }
}

enum DailyLimitMonitoring {
    private static let maxReconcilePasses = 3

    static func repairOnHeartbeat(
        _ activity: DeviceActivityName,
        center: any DeviceActivityProviding,
        store: any SharedStoreProviding,
        on date: Date = .now
    ) {
        guard activity.rawValue == SharedConstants.reblockHeartbeatActivityName else { return }
        guard !store.loadUsageLimits().isEmpty else { return }
        try? reconcile(center: center, store: store, on: date, source: "monitor")
    }

    static func reconcile(
        center: any DeviceActivityProviding,
        store: any SharedStoreProviding,
        on date: Date,
        source: String
    ) throws {
        var limits = store.loadUsageLimits()
        var period = store.usagePeriod
        var changedWhileRegistering = false
        for _ in 0..<maxReconcilePasses {
            guard
                try update(
                    limits: limits,
                    period: period,
                    force: changedWhileRegistering,
                    center: center,
                    store: store,
                    on: date,
                    source: source
                )
            else { return }
            let latest = store.loadUsageLimits()
            let latestPeriod = store.usagePeriod
            guard latest != limits || latestPeriod != period else { return }
            limits = latest
            period = latestPeriod
            changedWhileRegistering = true
        }
    }

    private static func update(
        limits: [UsageLimitDTO],
        period: UsagePeriod,
        force: Bool,
        center: any DeviceActivityProviding,
        store: any SharedStoreProviding,
        on date: Date,
        source: String
    ) throws -> Bool {
        let activity = DeviceActivityName(SharedConstants.usageLimitsActivityName)
        let specs = eventSpecs(for: limits, period: period, on: date).filter(\.isArmable)
        let monitored = center.monitoredActivityNames.contains(activity.rawValue)
        guard !specs.isEmpty else {
            store.saveUsageRegistration(nil)
            guard monitored else { return false }
            center.stopMonitoring([activity])
            return true
        }

        let schedule = daily(resetMinutes: period.resetMinutes, warningMinutes: SharedConstants.usageLimitWarningMinutes)
        let expected = specs.reduce(into: [DeviceActivityEvent.Name: DeviceActivityEvent]()) { $0[$1.name] = $1.event }
        let registration = fingerprint(for: specs, period: period)
        let scheduleMatches = center.registeredSchedule(for: activity)?.hasSameWindow(as: schedule) == true
        let namesMatch = Set(center.events(for: activity).keys) == Set(expected.keys)
        let unchanged = store.loadUsageRegistration() == registration
        guard force || !monitored || !scheduleMatches || !namesMatch || !unchanged else { return false }

        store.saveUsageRegistration(nil)
        do {
            store.saveUsageLimitsRegisteredAt(date)
            try center.startMonitoring(activity, during: schedule, events: expected)
            store.saveUsageRegistration(registration)
            dailyLimitMonitoringLogger.notice(
                "\(source, privacy: .public) usage limits: registered \(expected.count, privacy: .public) event(s)"
            )
            CallbackLog.record(
                "\(source) usage limits: registered \(specs.map { "\($0.minutes) min" }.joined(separator: ", "))"
            )
            return true
        } catch {
            dailyLimitMonitoringLogger.error(
                "\(source, privacy: .public) usage limits: startMonitoring failed, code=\((error as NSError).code, privacy: .public)"
            )
            CallbackLog.record("\(source) usage limits: startMonitoring failed: \(error)")
            throw error
        }
    }

    private static func fingerprint(for specs: [EventSpec], period: UsagePeriod) -> String {
        let body =
            specs
            .map { "\($0.id.uuidString):\($0.minutes):\(checksum(of: $0.selection)):\($0.includesPastActivity)" }
            .sorted()
            .joined(separator: "|")
        return "\(period.resetMinutes)@\(SharedConstants.usageLimitWarningMinutes)#\(body)"
    }

    private static func checksum(of selection: FamilyActivitySelection) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        func sorted<Token: Encodable>(_ tokens: Set<Token>) -> String {
            tokens.compactMap { try? encoder.encode($0).base64EncodedString() }.sorted().joined(separator: ",")
        }
        let tokens = [
            sorted(selection.applicationTokens),
            sorted(selection.categoryTokens),
            sorted(selection.webDomainTokens),
        ]
        return Data(tokens.joined(separator: "|").utf8).stableChecksum
    }

    static func daily(resetMinutes: Int, warningMinutes: Int) -> DeviceActivitySchedule {
        let startSeconds = resetMinutes * 60
        let endSeconds = (startSeconds - 1 + 86400) % 86400
        return DeviceActivitySchedule(
            intervalStart: DateComponents(hour: resetMinutes / 60, minute: resetMinutes % 60, second: 0),
            intervalEnd: DateComponents(
                hour: endSeconds / 3600,
                minute: endSeconds % 3600 / 60,
                second: endSeconds % 60
            ),
            repeats: true,
            warningTime: DateComponents(minute: warningMinutes)
        )
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
        let includesPastActivity: Bool

        var name: DeviceActivityEvent.Name {
            DeviceActivityEvent.Name(eventName)
        }

        /// A selection with no tokens has nothing to meter. Registering it
        /// would leave a limit that looks armed but can never fire.
        var isArmable: Bool {
            !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
        }

        var event: DeviceActivityEvent {
            DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minutes),
                // A limit counts from when it's created on its first day. After
                // that it counts the whole interval, so re-registering mid-day
                // cannot refund an allowance.
                includesPastActivity: includesPastActivity
            )
        }
    }

    /// Drops only limits whose selection cannot be decoded; whether a spec is
    /// worth arming is `EventSpec.isArmable`, kept separate so the naming and
    /// threshold rules stay checkable without real `ManagedSettings` tokens.
    static func eventSpecs(for dtos: [UsageLimitDTO], period: UsagePeriod, on date: Date) -> [EventSpec] {
        dtos.compactMap { dto in
            guard let selection = try? FamilyActivitySelection.fromData(dto.selectionData)
            else { return nil }
            return EventSpec(
                id: dto.id,
                eventName: SharedConstants.usageLimitEventName(for: dto.id),
                minutes: dto.minutesPerDay,
                selection: selection,
                includesPastActivity: period.countsPastActivity(createdAt: dto.createdAt, on: date)
            )
        }
    }
}
