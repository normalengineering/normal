import FamilyControls
import Foundation
import ManagedSettings

nonisolated struct ManualEntry: Codable, Equatable {
    let isBlocked: Bool
    let date: Date
}

nonisolated struct ManualLayer<Token: Hashable & Codable>: Codable, Equatable {
    private struct StoredEntry: Codable {
        let token: Token
        let entry: ManualEntry
    }

    private enum CodingKeys: String, CodingKey {
        case baseline
        case entries
    }

    private(set) var baseline = ManualEntry(isBlocked: false, date: .distantPast)
    private(set) var entries: [Token: ManualEntry] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseline = try container.decode(ManualEntry.self, forKey: .baseline)
        let stored = try container.decode([StoredEntry].self, forKey: .entries)
        entries = Dictionary(stored.map { ($0.token, $0.entry) }, uniquingKeysWith: { _, latest in latest })
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseline, forKey: .baseline)
        try container.encode(entries.map { StoredEntry(token: $0.key, entry: $0.value) }, forKey: .entries)
    }

    var blockedTokens: Set<Token> {
        Set(entries.filter(\.value.isBlocked).keys)
    }

    func entry(for token: Token) -> ManualEntry {
        entries[token] ?? baseline
    }

    mutating func set(_ tokens: some Sequence<Token>, blocked: Bool, at date: Date) {
        for token in tokens {
            entries[token] = ManualEntry(isBlocked: blocked, date: date)
        }
    }

    mutating func reset(blocking tokens: some Sequence<Token>, at date: Date) {
        baseline = ManualEntry(isBlocked: false, date: date)
        entries = [:]
        set(tokens, blocked: true, at: date)
    }
}

nonisolated struct ManualBlockState: Codable, Equatable {
    var applications = ManualLayer<ApplicationToken>()
    var webDomains = ManualLayer<WebDomainToken>()
    var categories = ManualLayer<ActivityCategoryToken>()
    var customDomains = ManualLayer<String>()
    var appDeletionBlocked: ManualEntry?
    var migratedAt: Date?

    mutating func blockAll(_ selection: FamilyActivitySelection, customDomains domains: [String], at date: Date) {
        applications.reset(blocking: selection.applicationTokens, at: date)
        webDomains.reset(blocking: selection.webDomainTokens, at: date)
        categories.reset(blocking: selection.categoryTokens, at: date)
        customDomains.reset(blocking: domains.compactMap(DomainNormalizer.normalize), at: date)
    }

    mutating func setAppDeletionBlocked(_ blocked: Bool, at date: Date) {
        appDeletionBlocked = ManualEntry(isBlocked: blocked, date: date)
    }

    mutating func unblockAll(at date: Date) {
        blockAll(FamilyActivitySelection(), customDomains: [], at: date)
    }

    mutating func block(_ selection: FamilyActivitySelection, customDomains domains: [String], at date: Date) {
        set(selection, customDomains: domains, blocked: true, at: date)
    }

    mutating func unblock(_ selection: FamilyActivitySelection, customDomains domains: [String], at date: Date) {
        set(selection, customDomains: domains, blocked: false, at: date)
    }

    private mutating func set(
        _ selection: FamilyActivitySelection,
        customDomains domains: [String],
        blocked: Bool,
        at date: Date
    ) {
        applications.set(selection.applicationTokens, blocked: blocked, at: date)
        webDomains.set(selection.webDomainTokens, blocked: blocked, at: date)
        categories.set(selection.categoryTokens, blocked: blocked, at: date)
        customDomains.set(domains.compactMap(DomainNormalizer.normalize), blocked: blocked, at: date)
    }
}

nonisolated struct ShieldPlan: Equatable {
    var applications: Set<ApplicationToken> = []
    var webDomains: Set<WebDomainToken> = []
    var categories: Set<ActivityCategoryToken> = []
    var customDomains: Set<String> = []
    var blocksAdultContent = false
    var hiddenApplications: Set<ApplicationToken> = []
    var denyAppRemoval: Bool?

    var selection: FamilyActivitySelection {
        var selection = FamilyActivitySelection()
        selection.applicationTokens = applications
        selection.webDomainTokens = webDomains
        selection.categoryTokens = categories
        return selection
    }

    mutating func formUnion(_ selection: FamilyActivitySelection, customDomains domains: [String]) {
        applications.formUnion(selection.applicationTokens)
        webDomains.formUnion(selection.webDomainTokens)
        categories.formUnion(selection.categoryTokens)
        customDomains.formUnion(domains.compactMap(DomainNormalizer.normalize))
    }
}

nonisolated enum ShieldResolver {
    private struct Claim {
        let date: Date
        let isBlocked: Bool
        let isTimedUnblock: Bool
        let coversEverything: Bool
        let selection: FamilyActivitySelection
        let customDomains: Set<String>
    }

    private static let maxTimedUnblockDuration: TimeInterval = 24 * 60 * 60

    static func plan(
        manual: ManualBlockState,
        enabledSchedules: [ScheduleDTO],
        timedUnblocks: [TimedUnblockDTO],
        customDomainsEnabled: Bool,
        adultContentEnabled: Bool = false,
        hideBlockedAppsEnabled: Bool = false,
        at date: Date,
        calendar: Calendar = .current
    ) -> ShieldPlan {
        let claims = enabledSchedules.compactMap {
            claim(for: $0, migratedAt: manual.migratedAt, at: date, calendar: calendar)
        }
            + timedUnblocks.compactMap { claim(for: $0, at: date) }

        var plan = ShieldPlan()
        plan.applications = resolve(manual.applications, claims, \.selection.applicationTokens)
        plan.webDomains = resolve(manual.webDomains, claims, \.selection.webDomainTokens)
        plan.categories = resolve(manual.categories, claims, \.selection.categoryTokens)
        if customDomainsEnabled {
            plan.customDomains = resolve(manual.customDomains, claims, \.customDomains)
        }
        plan.blocksAdultContent = adultContentEnabled
        if hideBlockedAppsEnabled {
            plan.hiddenApplications = plan.applications
        }
        plan.denyAppRemoval = appDeletionBlocked(manual: manual, timedUnblocks: timedUnblocks, at: date)
        return plan
    }

    static func migratedManualState(
        shielded current: ShieldPlan,
        enabledSchedules: [ScheduleDTO],
        timedUnblocks: [TimedUnblockDTO],
        scheduleOverrideActive: Bool,
        scheduleOverrideSince: Date?,
        at date: Date
    ) -> ManualBlockState {
        var restored = ShieldPlan()
        for unblock in timedUnblocks {
            guard let selection = try? FamilyActivitySelection.fromData(unblock.selectionData) else { continue }
            restored.formUnion(selection, customDomains: unblock.customDomains)
        }
        if !scheduleOverrideActive {
            var repaired = ShieldPlan()
            var scheduleBlocked = ShieldPlan()
            for schedule in enabledSchedules {
                guard let selection = try? FamilyActivitySelection.fromData(schedule.selectionData) else { continue }
                if schedule.shouldBlock {
                    scheduleBlocked.formUnion(selection, customDomains: schedule.customDomains)
                } else if schedule.isTimed {
                    repaired.formUnion(selection, customDomains: schedule.customDomains)
                }
            }
            repaired.applications.subtract(scheduleBlocked.applications)
            repaired.webDomains.subtract(scheduleBlocked.webDomains)
            repaired.categories.subtract(scheduleBlocked.categories)
            repaired.customDomains.subtract(scheduleBlocked.customDomains)
            restored.formUnion(repaired.selection, customDomains: Array(repaired.customDomains))
        }
        restored.applications.subtract(current.applications)
        restored.webDomains.subtract(current.webDomains)
        restored.categories.subtract(current.categories)
        restored.customDomains.subtract(current.customDomains)

        var state = ManualBlockState()
        state.migratedAt = date
        let shieldedSince = scheduleOverrideActive ? (scheduleOverrideSince ?? date) : .distantPast
        state.blockAll(current.selection, customDomains: Array(current.customDomains), at: shieldedSince)
        state.block(restored.selection, customDomains: Array(restored.customDomains), at: .distantPast)
        let mainUnblockLiftsAppDeletion = timedUnblocks.contains {
            !$0.isGroupUnblock && $0.blockAllPreventsAppDelete == true
        }
        if let deny = current.denyAppRemoval {
            state.setAppDeletionBlocked(deny || mainUnblockLiftsAppDeletion, at: .distantPast)
        } else if mainUnblockLiftsAppDeletion {
            state.setAppDeletionBlocked(true, at: .distantPast)
        }
        return state
    }

    private static func appDeletionBlocked(
        manual: ManualBlockState,
        timedUnblocks: [TimedUnblockDTO],
        at date: Date
    ) -> Bool? {
        let liftingUnblock = timedUnblocks.first {
            !$0.isGroupUnblock && $0.endDate > date && $0.blockAllPreventsAppDelete == true
        }
        guard let liftingUnblock else { return manual.appDeletionBlocked?.isBlocked }
        guard let entry = manual.appDeletionBlocked else { return false }
        return entry.date > startDate(of: liftingUnblock) ? entry.isBlocked : false
    }

    private static func startDate(of unblock: TimedUnblockDTO) -> Date {
        unblock.startDate ?? unblock.endDate.addingTimeInterval(-maxTimedUnblockDuration)
    }

    private static func claim(
        for schedule: ScheduleDTO,
        migratedAt: Date?,
        at date: Date,
        calendar: Calendar
    ) -> Claim? {
        let start = schedule.isTimed
            ? schedule.activeWindowStart(at: date, calendar: calendar)
            : schedule.latestStart(atOrBefore: date, calendar: calendar)
        let activation = schedule.activatedAt ?? (schedule.isTimed ? nil : migratedAt) ?? .distantPast
        guard let start,
              schedule.isTimed || start.addingTimeInterval(TimeInterval(schedule.durationMinutes * 60)) > activation,
              let selection = try? FamilyActivitySelection.fromData(schedule.selectionData)
        else { return nil }
        return Claim(
            date: max(start, activation),
            isBlocked: schedule.shouldBlock,
            isTimedUnblock: false,
            coversEverything: false,
            selection: selection,
            customDomains: Set(schedule.customDomains.compactMap(DomainNormalizer.normalize))
        )
    }

    private static func claim(for unblock: TimedUnblockDTO, at date: Date) -> Claim? {
        guard unblock.endDate > date,
              let selection = try? FamilyActivitySelection.fromData(unblock.selectionData)
        else { return nil }
        return Claim(
            date: startDate(of: unblock),
            isBlocked: false,
            isTimedUnblock: true,
            coversEverything: !unblock.isGroupUnblock,
            selection: selection,
            customDomains: Set(unblock.customDomains.compactMap(DomainNormalizer.normalize))
        )
    }

    private static func resolve<Token: Hashable & Codable>(
        _ manual: ManualLayer<Token>,
        _ claims: [Claim],
        _ tokens: KeyPath<Claim, Set<Token>>
    ) -> Set<Token> {
        var candidates = Set(manual.entries.keys)
        for claim in claims {
            candidates.formUnion(claim[keyPath: tokens])
        }
        return candidates.filter { token in
            let covering = claims.filter { $0.coversEverything || $0[keyPath: tokens].contains(token) }
            let timedUnblocks = covering.filter(\.isTimedUnblock)
            var winner = manual.entry(for: token)
            for claim in timedUnblocks.isEmpty ? covering : timedUnblocks {
                if claim.date > winner.date || (claim.date == winner.date && claim.isBlocked) {
                    winner = ManualEntry(isBlocked: claim.isBlocked, date: claim.date)
                }
            }
            return winner.isBlocked
        }
    }
}

nonisolated extension ScheduleDTO {
    func latestStart(atOrBefore date: Date, calendar: Calendar = .current) -> Date? {
        let startOfToday = calendar.startOfDay(for: date)
        for dayOffset in 0 ... 7 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: startOfToday),
                  let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day)
            else { continue }
            if start <= date, weekdays.contains(calendar.component(.weekday, from: start)) {
                return start
            }
        }
        return nil
    }
}
