import SwiftData

enum CustomDomainsMigration {
    static func run(context: ModelContext, sharedStore: some SharedStoreProviding) {
        if !sharedStore.isCustomDomainsEnabled() {
            do {
                try clearDomains(in: context)
            } catch {
                return
            }
            stripDomains(in: sharedStore)
        }
        sharedStore.clearCustomDomainsEnabled()
    }

    private static func clearDomains(in context: ModelContext) throws {
        for apps in try context.fetch(FetchDescriptor<SelectedApps>()) {
            apps.customDomains = []
        }
        for group in try context.fetch(FetchDescriptor<AppGroup>()) {
            group.customDomains = []
        }
        for schedule in try context.fetch(FetchDescriptor<BlockSchedule>()) {
            schedule.customDomains = []
        }
        try context.save()
    }

    private static func stripDomains(in sharedStore: some SharedStoreProviding) {
        sharedStore.saveSchedules(sharedStore.loadSchedules().map { $0.withoutCustomDomains() })
        sharedStore.saveTimedUnblocks(sharedStore.loadTimedUnblocks().map { $0.withoutCustomDomains() })
        if var manual = sharedStore.loadManualBlockState() {
            manual.customDomains = ManualLayer()
            sharedStore.saveManualBlockState(manual)
        }
    }
}

private extension ScheduleDTO {
    func withoutCustomDomains() -> ScheduleDTO {
        ScheduleDTO(
            id: id,
            name: name,
            selectionData: selectionData,
            startHour: startHour,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            weekdays: weekdays,
            shouldBlock: shouldBlock,
            isTimed: isTimed,
            isEnabled: isEnabled,
            activatedAt: activatedAt
        )
    }
}

private extension TimedUnblockDTO {
    func withoutCustomDomains() -> TimedUnblockDTO {
        TimedUnblockDTO(
            id: id,
            selectionData: selectionData,
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: isGroupUnblock,
            blockAllPreventsAppDelete: blockAllPreventsAppDelete,
            startDate: startDate
        )
    }
}
