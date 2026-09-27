import Foundation
@testable import Normal
import SwiftData
import Testing

enum LegacySettingsSchema {
    @Model
    final class Settings {
        @Attribute(.unique) var id: String = "APP_SETTINGS"

        var emergencyUnblockDates: [Date]
        var defaultKeyType: KeyType?
        var defaultUnblockDuration: UnblockDuration?
        var hasCompletedOnboarding: Bool = false
        var blockAllPreventsAppDelete: Bool = true
        var defaultTab: AppTab?
        var hideDonateButton: Bool = false
        var showTimedUnblockLiveActivity: Bool = false
        var enableCustomDomains: Bool = false
        var skipBlockWithoutKeyConfirmation: Bool = false

        init(defaultUnblockDuration: UnblockDuration?) {
            emergencyUnblockDates = []
            defaultKeyType = nil
            self.defaultUnblockDuration = defaultUnblockDuration
        }
    }
}

@MainActor
struct UnblockDurationMigrationTests {
    private static let currentModels: [any PersistentModel.Type] = [
        Key.self, Normal.Settings.self, BlockSchedule.self, SelectedApps.self, AppGroup.self,
    ]

    private func storeURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("durationmig-\(UUID().uuidString).store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: url.deletingLastPathComponent()
                    .appendingPathComponent(url.lastPathComponent + suffix)
            )
        }
    }

    private func writeLegacyStore(at url: URL, defaultUnblockDuration: UnblockDuration?) throws {
        let schema = Schema([LegacySettingsSchema.Settings.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        container.mainContext.insert(LegacySettingsSchema.Settings(defaultUnblockDuration: defaultUnblockDuration))
        try container.mainContext.save()
    }

    /// Returns the container too: a model instance dies with its container's context.
    private func reopenWithCurrentSchema(at url: URL) throws -> (ModelContainer, Normal.Settings) {
        let schema = Schema(Self.currentModels)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let settings = try #require(try container.mainContext.fetch(FetchDescriptor<Normal.Settings>()).first)
        return (container, settings)
    }

    @Test func legacyDefaultSurvivesUpgrade() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        try writeLegacyStore(at: url, defaultUnblockDuration: .fourHours)
        let (container, settings) = try reopenWithCurrentSchema(at: url)
        defer { withExtendedLifetime(container) {} }

        #expect(settings.customUnblockDurationSeconds == nil)
        #expect(settings.defaultUnblockSeconds == nil)
        #expect(settings.unblockDurations == TimedUnblockDuration.presets)
        #expect(settings.defaultDuration == .fourHours)
    }

    @Test func legacyStoreWithoutDefaultUpgradesToNone() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        try writeLegacyStore(at: url, defaultUnblockDuration: nil)
        let (container, settings) = try reopenWithCurrentSchema(at: url)
        defer { withExtendedLifetime(container) {} }

        #expect(settings.unblockDurations == TimedUnblockDuration.presets)
        #expect(settings.defaultDuration == nil)
    }

    @Test func customDurationsPersistAcrossReopen() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        do {
            let schema = Schema(Self.currentModels)
            let container = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: url)
            )
            let settings = Normal.Settings()
            settings.addUnblockDuration(try #require(TimedUnblockDuration(validating: 5700)))
            settings.defaultDuration = TimedUnblockDuration(validating: 5700)
            container.mainContext.insert(settings)
            try container.mainContext.save()
        }

        let (container, settings) = try reopenWithCurrentSchema(at: url)
        defer { withExtendedLifetime(container) {} }
        #expect(settings.unblockDurations.map(\.seconds) == [900, 1800, 3600, 5700, 14400])
        #expect(settings.defaultDuration?.seconds == 5700)
    }
}
