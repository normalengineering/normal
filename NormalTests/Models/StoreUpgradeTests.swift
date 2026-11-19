import FamilyControls
import Foundation
import SwiftData
import Testing

@testable import Normal

enum Version14Schema {
    enum KeyType: String, Codable, Sendable {
        case nfc = "NFC"
        case qr = "QR"
        case location = "LOCATION"
    }

    enum ScanCodeKind: String, Codable, Sendable {
        case qr
        case barcode
    }

    enum LocationRadiusKind: String, Codable, Sendable {
        case unblock = "UNBLOCK"
        case block = "BLOCK"
    }

    enum UnblockDuration: Int, Codable, Sendable {
        case fifteenMinutes = 900
        case thirtyMinutes = 1800
        case oneHour = 3600
        case fourHours = 14400
    }

    enum AppTab: String, Codable {
        case home
        case groups
        case schedules
        case appSelect
        case keys
    }

    static let models: [any PersistentModel.Type] = [
        AppGroup.self, SelectedApps.self, Key.self, BlockSchedule.self, Settings.self,
    ]

    @Model
    final class AppGroup {
        @Attribute(.unique) var id: UUID
        var name: String
        var selection: FamilyActivitySelection
        var lastUpdated: Date
        var sortIndex: Int = 0
        var customDomains: [String] = []

        init(id: UUID, name: String, selection: FamilyActivitySelection, lastUpdated: Date, sortIndex: Int, customDomains: [String]) {
            self.id = id
            self.name = name
            self.selection = selection
            self.lastUpdated = lastUpdated
            self.sortIndex = sortIndex
            self.customDomains = customDomains
        }
    }

    @Model
    final class SelectedApps {
        @Attribute(.unique) var id: String = "APP_MAIN_SELECTION"
        var selection: FamilyActivitySelection
        var lastUpdated: Date
        var customDomains: [String] = []

        init(selection: FamilyActivitySelection, lastUpdated: Date, customDomains: [String]) {
            self.selection = selection
            self.lastUpdated = lastUpdated
            self.customDomains = customDomains
        }
    }

    @Model
    final class Key {
        @Attribute(.unique) var id: UUID
        var name: String
        var type: KeyType
        var scanKind: ScanCodeKind?
        var latitude: Double?
        var longitude: Double?
        var radiusMeters: Double?
        var radiusKind: LocationRadiusKind?
        var sortIndex: Int = 0
        var groupID: UUID?
        var hashedValue: String
        var salt: String

        init(
            name: String,
            type: KeyType,
            scanKind: ScanCodeKind? = nil,
            location: (latitude: Double, longitude: Double, radiusMeters: Double, kind: LocationRadiusKind)? = nil,
            sortIndex: Int,
            groupID: UUID? = nil,
            hashedValue: String = "",
            salt: String = ""
        ) {
            id = UUID()
            self.name = name
            self.type = type
            self.scanKind = scanKind
            latitude = location?.latitude
            longitude = location?.longitude
            radiusMeters = location?.radiusMeters
            radiusKind = location?.kind
            self.sortIndex = sortIndex
            self.groupID = groupID
            self.hashedValue = hashedValue
            self.salt = salt
        }
    }

    @Model
    final class BlockSchedule {
        @Attribute(.unique) var id: UUID
        var name: String
        var selection: FamilyActivitySelection
        var startHour: Int
        var startMinute: Int
        var durationMinutes: Int
        var weekdays: Set<Int>
        var shouldBlock: Bool
        var isTimed: Bool
        var isEnabled: Bool
        var sortIndex: Int = 0
        var customDomains: [String] = []

        init(name: String, selection: FamilyActivitySelection, customDomains: [String]) {
            id = UUID()
            self.name = name
            self.selection = selection
            startHour = 21
            startMinute = 30
            durationMinutes = 600
            weekdays = [2, 3, 4, 5, 6]
            shouldBlock = true
            isTimed = false
            isEnabled = true
            sortIndex = 1
            self.customDomains = customDomains
        }
    }

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

        init(emergencyUnblockDates: [Date]) {
            self.emergencyUnblockDates = emergencyUnblockDates
            defaultKeyType = .location
            defaultUnblockDuration = .oneHour
            hasCompletedOnboarding = true
            blockAllPreventsAppDelete = false
            defaultTab = .keys
            hideDonateButton = true
            showTimedUnblockLiveActivity = true
            enableCustomDomains = true
        }
    }
}

enum Version15Schema {
    static let models: [any PersistentModel.Type] = [
        Version14Schema.AppGroup.self,
        Version14Schema.SelectedApps.self,
        Version14Schema.Key.self,
        Version14Schema.BlockSchedule.self,
        Settings.self,
        UsageLimit.self,
    ]

    @Model
    final class Settings {
        @Attribute(.unique) var id: String = "APP_SETTINGS"
        var emergencyUnblockDates: [Date]
        var defaultKeyType: Version14Schema.KeyType?
        var defaultUnblockDuration: Version14Schema.UnblockDuration?
        var customUnblockDurationSeconds: [Int]?
        var defaultUnblockSeconds: Int?
        var hasCompletedOnboarding: Bool = false
        var blockAllPreventsAppDelete: Bool = true
        var defaultTab: Version14Schema.AppTab?
        var hideDonateButton: Bool = false
        var showTimedUnblockLiveActivity: Bool = false
        var enableCustomDomains: Bool = false
        var skipBlockWithoutKeyConfirmation: Bool = false
        var dailyLimitResetMinutes: Int = 0

        init() {
            emergencyUnblockDates = []
            defaultKeyType = .qr
            defaultUnblockDuration = nil
            customUnblockDurationSeconds = [900, 5700]
            defaultUnblockSeconds = 5700
            hasCompletedOnboarding = true
            skipBlockWithoutKeyConfirmation = true
            dailyLimitResetMinutes = 240
        }
    }

    @Model
    final class UsageLimit {
        @Attribute(.unique) var id: UUID
        var selection: FamilyActivitySelection
        var minutesPerDay: Int
        var sortIndex: Int = 0
        var lockAnchor: Date?

        init(id: UUID, selection: FamilyActivitySelection, minutesPerDay: Int, lockAnchor: Date) {
            self.id = id
            self.selection = selection
            self.minutesPerDay = minutesPerDay
            self.lockAnchor = lockAnchor
        }
    }
}

@MainActor
struct StoreUpgradeTests {
    private static let groupID = UUID(uuidString: "6E0A1C9B-2D4F-4B7A-9C3E-5F8D1A2B3C4D")!
    private static let updated = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let emergencyDates = [Date(timeIntervalSinceReferenceDate: 810_000_000)]
    private static let keySecret = "NORMAL-TEST-KEY"
    private static let keySalt = "000102030405060708090a0b0c0d0e0f"
    private static let keyHash = "ebc8228f98582451940d67ff91117618a8e9579547926f9bcb2aca807838c4d3"

    private func storeURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("upgrade-\(UUID().uuidString).store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: url.deletingLastPathComponent()
                    .appendingPathComponent(url.lastPathComponent + suffix)
            )
        }
    }

    private func writeVersion14Store(at url: URL) throws {
        let schema = Schema(Version14Schema.models)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let context = container.mainContext
        context.insert(
            Version14Schema.AppGroup(
                id: Self.groupID,
                name: "Social",
                selection: TokenFixtures.selection(apps: [1, 2], categories: [1]),
                lastUpdated: Self.updated,
                sortIndex: 2,
                customDomains: ["reddit.com"]
            ))
        context.insert(
            Version14Schema.SelectedApps(
                selection: TokenFixtures.selection(apps: [1, 2, 3], webDomains: [1]),
                lastUpdated: Self.updated,
                customDomains: ["example.com"]
            ))
        context.insert(
            Version14Schema.Key(
                name: "Desk",
                type: .qr,
                scanKind: .barcode,
                sortIndex: 0,
                hashedValue: Self.keyHash,
                salt: Self.keySalt
            ))
        context.insert(
            Version14Schema.Key(
                name: "Social Tag",
                type: .nfc,
                sortIndex: 1,
                groupID: Self.groupID,
                hashedValue: Self.keyHash,
                salt: Self.keySalt
            ))
        context.insert(
            Version14Schema.Key(
                name: "Office",
                type: .location,
                location: (latitude: 37.3349, longitude: -122.009, radiusMeters: 150, kind: .block),
                sortIndex: 2
            ))
        context.insert(
            Version14Schema.BlockSchedule(
                name: "Night",
                selection: TokenFixtures.selection(apps: [3]),
                customDomains: ["news.com"]
            ))
        context.insert(Version14Schema.Settings(emergencyUnblockDates: Self.emergencyDates))
        try context.save()
    }

    private func reopen(at url: URL) throws -> ModelContainer {
        let schema = Schema(NormalApp.models)
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
    }

    @Test func version14StoreOpensWithEveryValueIntact() throws {
        let url = storeURL()
        defer { removeStore(at: url) }
        try writeVersion14Store(at: url)

        let container = try reopen(at: url)
        let context = container.mainContext

        let group = try #require(try context.fetch(FetchDescriptor<AppGroup>()).first)
        #expect(group.id == Self.groupID)
        #expect(group.name == "Social")
        #expect(group.selection == TokenFixtures.selection(apps: [1, 2], categories: [1]))
        #expect(group.lastUpdated == Self.updated)
        #expect(group.sortIndex == 2)
        #expect(group.customDomains == ["reddit.com"])
        #expect(group.durationOverride == .appDefault)
        #expect(group.keyOverride == .appDefault)

        let main = try #require(try context.fetch(FetchDescriptor<SelectedApps>()).first)
        #expect(main.selection == TokenFixtures.selection(apps: [1, 2, 3], webDomains: [1]))
        #expect(main.lastUpdated == Self.updated)
        #expect(main.customDomains == ["example.com"])

        let schedule = try #require(try context.fetch(FetchDescriptor<BlockSchedule>()).first)
        #expect(schedule.name == "Night")
        #expect(schedule.selection == TokenFixtures.selection(apps: [3]))
        #expect(schedule.startHour == 21)
        #expect(schedule.startMinute == 30)
        #expect(schedule.durationMinutes == 600)
        #expect(schedule.weekdays == [2, 3, 4, 5, 6])
        #expect(schedule.shouldBlock)
        #expect(!schedule.isTimed)
        #expect(schedule.isEnabled)
        #expect(schedule.sortIndex == 1)
        #expect(schedule.customDomains == ["news.com"])

        #expect(try context.fetchCount(FetchDescriptor<UsageLimit>()) == 0)
    }

    @Test func version14KeysStillUnlockAndKeepTheirScope() throws {
        let url = storeURL()
        defer { removeStore(at: url) }
        try writeVersion14Store(at: url)

        let container = try reopen(at: url)
        let keys = try container.mainContext.fetch(FetchDescriptor<Key>(sortBy: [SortDescriptor(\.sortIndex)]))
        try #require(keys.count == 3)

        let desk = keys[0]
        #expect(desk.type == .qr)
        #expect(desk.scanKind == .barcode)
        #expect(desk.isGlobal)
        #expect(desk.matches(unhashedId: Self.keySecret))
        #expect(!desk.matches(unhashedId: "WRONG"))

        let tag = keys[1]
        #expect(tag.type == .nfc)
        #expect(tag.groupID == Self.groupID)
        #expect(tag.matches(unhashedId: Self.keySecret))

        let office = keys[2]
        #expect(office.type == .location)
        #expect(office.radiusKind == .block)
        #expect(office.latitude == 37.3349)
        #expect(office.longitude == -122.009)
        #expect(office.radiusMeters == 150)
    }

    @Test func version14SettingsKeepTheirValuesAndDefaultTheNewOnes() throws {
        let url = storeURL()
        defer { removeStore(at: url) }
        try writeVersion14Store(at: url)

        let container = try reopen(at: url)
        let settings = try #require(try container.mainContext.fetch(FetchDescriptor<Normal.Settings>()).first)
        #expect(settings.emergencyUnblockDates == Self.emergencyDates)
        #expect(settings.defaultKeyType == .location)
        #expect(settings.defaultUnblockDuration == .oneHour)
        #expect(settings.defaultDuration == .oneHour)
        #expect(settings.hasCompletedOnboarding)
        #expect(!settings.blockAllPreventsAppDelete)
        #expect(settings.defaultTab == .keys)
        #expect(settings.hideDonateButton)
        #expect(settings.showTimedUnblockLiveActivity)
        #expect(settings.enableCustomDomains)

        #expect(settings.customUnblockDurationSeconds == nil)
        #expect(settings.defaultUnblockSeconds == nil)
        #expect(!settings.skipBlockWithoutKeyConfirmation)
        #expect(settings.dailyLimitResetMinutes == 0)
        #expect(settings.unblockDurations == TimedUnblockDuration.presets)
    }

    @Test func version15StoreKeepsDurationsResetTimeAndDailyLimits() throws {
        let url = storeURL()
        defer { removeStore(at: url) }
        let limitID = UUID()
        do {
            let schema = Schema(Version15Schema.models)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            container.mainContext.insert(Version15Schema.Settings())
            container.mainContext.insert(
                Version15Schema.UsageLimit(
                    id: limitID,
                    selection: TokenFixtures.selection(apps: [4]),
                    minutesPerDay: 45,
                    lockAnchor: Self.updated
                ))
            try container.mainContext.save()
        }

        let container = try reopen(at: url)
        let settings = try #require(try container.mainContext.fetch(FetchDescriptor<Normal.Settings>()).first)
        #expect(settings.defaultKeyType == .qr)
        #expect(settings.customUnblockDurationSeconds == [900, 5700])
        #expect(settings.defaultUnblockSeconds == 5700)
        #expect(settings.defaultDuration?.seconds == 5700)
        #expect(settings.skipBlockWithoutKeyConfirmation)
        #expect(settings.dailyLimitResetMinutes == 240)

        let limit = try #require(try container.mainContext.fetch(FetchDescriptor<UsageLimit>()).first)
        #expect(limit.id == limitID)
        #expect(limit.selection == TokenFixtures.selection(apps: [4]))
        #expect(limit.minutesPerDay == 45)
        #expect(limit.lockAnchor == Self.updated)
    }
}
