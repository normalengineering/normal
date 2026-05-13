@testable import Normal
import Foundation
import SwiftData
import Testing

struct SettingsTests {
    @Test @MainActor func defaultSettingsHaveThreeEmergencyUnblocks() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let settings = Settings()
        context.insert(settings)

        #expect(settings.emergencyUnblocksAvailable == 3)
    }

    @Test @MainActor func recordEmergencyUnblockDecrementsAvailable() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let settings = Settings()
        context.insert(settings)
        settings.recordEmergencyUnblock()

        #expect(settings.emergencyUnblocksAvailable == 2)
    }

    @Test @MainActor func threeUnblocksExhaustsAvailability() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let settings = Settings()
        context.insert(settings)

        settings.recordEmergencyUnblock()
        settings.recordEmergencyUnblock()
        settings.recordEmergencyUnblock()

        #expect(settings.emergencyUnblocksAvailable == 0)
    }

    @Test @MainActor func oldUnblocksExpireAfter180Days() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let settings = Settings()
        context.insert(settings)

        let oldDate = Calendar.current.date(byAdding: .day, value: -181, to: .now)!
        settings.emergencyUnblockDates = [oldDate, oldDate, oldDate]

        #expect(settings.emergencyUnblocksAvailable == 3)
    }

    @Test @MainActor func mixOfOldAndRecentUnblocks() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let settings = Settings()
        context.insert(settings)

        let oldDate = Calendar.current.date(byAdding: .day, value: -200, to: .now)!
        settings.emergencyUnblockDates = [oldDate, oldDate, .now]

        #expect(settings.emergencyUnblocksAvailable == 2)
    }

    @Test @MainActor func defaultPropertiesAreNil() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let settings = Settings()
        context.insert(settings)

        #expect(settings.defaultKeyType == nil)
        #expect(settings.defaultUnblockDuration == nil)
        #expect(settings.hasCompletedOnboarding == false)
    }

    @Test @MainActor func blockAllPreventsAppDeleteDefaultsToTrue() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let settings = Settings()
        context.insert(settings)

        #expect(settings.blockAllPreventsAppDelete == true)
    }

    @Test @MainActor func defaultTabDefaultsToHome() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let settings = Settings()
        context.insert(settings)

        #expect(settings.defaultTab == .home)
    }

    @Test @MainActor func defaultTabCanBeChanged() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let settings = Settings()
        context.insert(settings)

        settings.defaultTab = .groups
        #expect(settings.defaultTab == .groups)

        settings.defaultTab = .schedules
        #expect(settings.defaultTab == .schedules)
    }
}
