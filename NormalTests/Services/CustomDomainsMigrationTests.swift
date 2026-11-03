import FamilyControls
import Foundation
@testable import Normal
import SwiftData
import Testing

@MainActor
struct CustomDomainsMigrationTests {
    private let container: ModelContainer
    private let store = FakeSharedStore()

    init() throws {
        container = try InMemoryModelContainer.make()
    }

    private var context: ModelContext {
        container.mainContext
    }

    private func seed(domains: [String]) throws {
        context.insert(SelectedApps(selection: FamilyActivitySelection(), customDomains: domains))
        context.insert(AppGroup(name: "Social", selection: FamilyActivitySelection(), customDomains: domains))
        context.insert(BlockSchedule(
            name: "Work",
            selection: FamilyActivitySelection(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 60,
            weekdays: [2, 3, 4],
            customDomains: domains
        ))
        try context.save()

        store.schedules = [ScheduleDTO(
            id: UUID(),
            name: "Work",
            selectionData: Data(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 60,
            weekdays: [2, 3, 4],
            shouldBlock: true,
            isTimed: false,
            customDomains: domains,
            isEnabled: true
        )]
        store.timedUnblocks = [TimedUnblockDTO(
            id: "main",
            selectionData: Data(),
            endDate: .distantFuture,
            activityName: "timed-main",
            isGroupUnblock: false,
            blockAllPreventsAppDelete: true,
            customDomains: domains
        )]
        var manual = ManualBlockState()
        manual.block(FamilyActivitySelection(), customDomains: domains, at: .now)
        store.manualBlockState = manual
    }

    private func modelDomains() throws -> [[String]] {
        try context.fetch(FetchDescriptor<SelectedApps>()).map(\.customDomains)
            + context.fetch(FetchDescriptor<AppGroup>()).map(\.customDomains)
            + context.fetch(FetchDescriptor<BlockSchedule>()).map(\.customDomains)
    }

    @Test func legacyDisabledFlagClearsHiddenDomainsEverywhere() throws {
        try seed(domains: ["reddit.com"])
        store.customDomainsEnabled = false

        CustomDomainsMigration.run(context: context, sharedStore: store)

        #expect(try modelDomains() == [[], [], []])
        #expect(store.schedules.map(\.customDomains) == [[]])
        #expect(store.schedules.first?.name == "Work")
        #expect(store.schedules.first?.isEnabled == true)
        #expect(store.timedUnblocks.map(\.customDomains) == [[]])
        #expect(store.timedUnblocks.first?.endDate == .distantFuture)
        #expect(store.timedUnblocks.first?.blockAllPreventsAppDelete == true)
        #expect(store.manualBlockState?.customDomains.blockedTokens.isEmpty == true)
        #expect(store.customDomainsEnabled == nil)
    }

    @Test func legacyEnabledFlagKeepsDomains() throws {
        try seed(domains: ["reddit.com"])
        store.customDomainsEnabled = true

        CustomDomainsMigration.run(context: context, sharedStore: store)

        #expect(try modelDomains() == [["reddit.com"], ["reddit.com"], ["reddit.com"]])
        #expect(store.schedules.map(\.customDomains) == [["reddit.com"]])
        #expect(store.timedUnblocks.map(\.customDomains) == [["reddit.com"]])
        #expect(store.manualBlockState?.customDomains.blockedTokens == ["reddit.com"])
        #expect(store.customDomainsEnabled == nil)
    }

    @Test func missingFlagLeavesDomainsAlone() throws {
        try seed(domains: ["reddit.com"])

        CustomDomainsMigration.run(context: context, sharedStore: store)

        #expect(try modelDomains() == [["reddit.com"], ["reddit.com"], ["reddit.com"]])
        #expect(store.schedules.map(\.customDomains) == [["reddit.com"]])
        #expect(store.manualBlockState?.customDomains.blockedTokens == ["reddit.com"])
    }
}
