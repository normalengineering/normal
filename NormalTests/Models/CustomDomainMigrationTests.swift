import FamilyControls
import Foundation
@testable import Normal
import SwiftData
import Testing

@MainActor
struct CustomDomainMigrationTests {
    private static let models: [any PersistentModel.Type] = [
        Key.self, Settings.self, BlockSchedule.self, SelectedApps.self, AppGroup.self,
    ]

    private func storeURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("customdomainmig-\(UUID().uuidString).store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: url.deletingLastPathComponent()
                    .appendingPathComponent(url.lastPathComponent + suffix)
            )
        }
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(Self.models),
            configurations: ModelConfiguration(schema: Schema(Self.models), url: url)
        )
    }

    @Test func selectedAppsCustomDomainsDefaultsEmptyAndPersists() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        do {
            let container = try makeContainer(at: url)
            // Inserted without custom domains — mirrors rows written before the column existed.
            container.mainContext.insert(SelectedApps(selection: FamilyActivitySelection()))
            container.mainContext.insert(AppGroup(name: "Social", selection: FamilyActivitySelection()))
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: url)
        let apps = try #require(try reopened.mainContext.fetch(FetchDescriptor<SelectedApps>()).first)
        let group = try #require(try reopened.mainContext.fetch(FetchDescriptor<AppGroup>()).first)
        #expect(apps.customDomains == [])
        #expect(group.customDomains == [])
    }

    @Test func customDomainsPersistAcrossReopen() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        let scheduleId: UUID
        do {
            let container = try makeContainer(at: url)
            let apps = SelectedApps(selection: FamilyActivitySelection(), customDomains: ["reddit.com"])
            let group = AppGroup(name: "Social", selection: FamilyActivitySelection(), customDomains: ["x.com"])
            let schedule = BlockSchedule(
                name: "Work",
                selection: FamilyActivitySelection(),
                startHour: 9,
                startMinute: 0,
                durationMinutes: 60,
                weekdays: [2, 3, 4],
                customDomains: ["news.com"]
            )
            scheduleId = schedule.id
            container.mainContext.insert(apps)
            container.mainContext.insert(group)
            container.mainContext.insert(schedule)
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: url)
        let apps = try #require(try reopened.mainContext.fetch(FetchDescriptor<SelectedApps>()).first)
        let group = try #require(try reopened.mainContext.fetch(FetchDescriptor<AppGroup>()).first)
        let schedule = try #require(
            try reopened.mainContext.fetch(FetchDescriptor<BlockSchedule>()).first { $0.id == scheduleId }
        )
        #expect(apps.customDomains == ["reddit.com"])
        #expect(group.customDomains == ["x.com"])
        #expect(schedule.customDomains == ["news.com"])
    }

    @Test func settingsEnableCustomDomainsDefaultsFalseAfterReopen() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        do {
            let container = try makeContainer(at: url)
            container.mainContext.insert(Settings())
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: url)
        let settings = try #require(try reopened.mainContext.fetch(FetchDescriptor<Settings>()).first)
        #expect(settings.enableCustomDomains == false)
    }
}
