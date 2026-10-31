import Foundation
import ManagedSettings

nonisolated protocol ShieldApplying: AnyObject {
    func currentShields() -> ShieldPlan
    func apply(_ plan: ShieldPlan)
}

nonisolated enum SharedFileLock {
    private static var defaultURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID)?
            .appending(path: "shields.lock")
    }

    static func withLock<T>(at url: URL? = nil, _ body: () throws -> T) rethrows -> T? {
        guard let path = (url ?? defaultURL)?.path(percentEncoded: false) else { return try body() }
        let descriptor = open(path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else {
            return errno == EPERM || errno == EACCES ? nil : try body()
        }
        defer { close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else { return try body() }
        }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}

nonisolated enum ShieldReconciler {
    @discardableResult
    static func reconcile(
        sharedStore: some SharedStoreProviding,
        shields: some ShieldApplying,
        monitoredActivities: Set<String>,
        at date: Date = .now,
        lockURL: URL? = nil,
        update: (inout ManualBlockState) -> Void = { _ in }
    ) -> ShieldPlan? {
        SharedFileLock.withLock(at: lockURL) {
            let schedules = sharedStore.loadSchedules()
                .filter { $0.isEffectivelyEnabled(monitoredActivities: monitoredActivities) }
            let timedUnblocks = sharedStore.loadTimedUnblocks()
            let current = shields.currentShields()

            let saved = sharedStore.loadManualBlockState()
            var manual = saved
                ?? ShieldResolver.migratedManualState(
                    shielded: current,
                    enabledSchedules: schedules,
                    timedUnblocks: timedUnblocks,
                    scheduleOverrideActive: sharedStore.isScheduleOverrideActive(),
                    scheduleOverrideSince: sharedStore.loadScheduleOverrideSince(),
                    at: date
                )
            update(&manual)
            if manual != saved {
                sharedStore.saveManualBlockState(manual)
            }

            let plan = ShieldResolver.plan(
                manual: manual,
                enabledSchedules: schedules,
                timedUnblocks: timedUnblocks,
                customDomainsEnabled: sharedStore.isCustomDomainsEnabled(),
                adultContentEnabled: sharedStore.isAdultContentEnabled(),
                hideBlockedAppsEnabled: sharedStore.isHideBlockedAppsEnabled(),
                at: date
            )
            if plan.differs(from: current) {
                shields.apply(plan)
            }
            return plan
        }
    }
}

nonisolated extension ShieldPlan {
    func differs(from current: ShieldPlan) -> Bool {
        applications != current.applications
            || webDomains != current.webDomains
            || categories != current.categories
            || customDomains != current.customDomains
            || blocksAdultContent != current.blocksAdultContent
            || hiddenApplications != current.hiddenApplications
            || (denyAppRemoval != nil && denyAppRemoval != current.denyAppRemoval)
    }
}

extension ManagedSettingsStore: ShieldApplying {
    func currentShields() -> ShieldPlan {
        var plan = ShieldPlan()
        plan.applications = shield.applications ?? []
        plan.webDomains = shield.webDomains ?? []
        plan.categories = shield.applicationCategories.tokenSet
        plan.customDomains = Set(filterDomains().compactMap(\.domain))
        plan.blocksAdultContent = blocksAdultContent
        plan.hiddenApplications = Set(application.blockedApplications?.compactMap(\.token) ?? [])
        plan.denyAppRemoval = application.denyAppRemoval ?? false
        return plan
    }

    func apply(_ plan: ShieldPlan) {
        replaceShields(with: plan.selection)
        replaceFilter(domains: Array(plan.customDomains), blockingAdultContent: plan.blocksAdultContent)
        application.blockedApplications = plan.hiddenApplications.isEmpty
            ? nil
            : Set(plan.hiddenApplications.map { Application(token: $0) })
        if let deny = plan.denyAppRemoval {
            application.denyAppRemoval = deny
        }
    }
}
