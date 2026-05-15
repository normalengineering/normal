import Foundation
@testable import Normal
import Testing

struct SettingsTests {
    @Test func freshSettingsStartsWithAllUnblocksAvailable() {
        let s = Settings()
        #expect(s.emergencyUnblocksAvailable == Settings.maxEmergencyUnblocks)
        #expect(s.emergencyUnblockDates.isEmpty)
    }

    @Test func recordingDecrementsAvailable() {
        let s = Settings()
        s.recordEmergencyUnblock()
        #expect(s.emergencyUnblocksAvailable == Settings.maxEmergencyUnblocks - 1)
    }

    @Test func recordingPersistsTimestamp() {
        let s = Settings()
        s.recordEmergencyUnblock()
        s.recordEmergencyUnblock()
        #expect(s.emergencyUnblockDates.count == 2)
    }

    @Test func availableNeverNegative() {
        let s = Settings()
        for _ in 0 ..< (Settings.maxEmergencyUnblocks + 5) {
            s.recordEmergencyUnblock()
        }
        #expect(s.emergencyUnblocksAvailable == 0)
    }

    @Test func oldEmergencyUnblocksRegenerate() {
        let s = Settings()
        let oldDate = Date.now.addingTimeInterval(-60 * 60 * 24 * 200)
        s.emergencyUnblockDates = [oldDate, oldDate, oldDate]
        #expect(s.emergencyUnblocksAvailable == Settings.maxEmergencyUnblocks)
    }

    @Test func recentEmergencyUnblocksCount() {
        let s = Settings()
        let recent = Date.now.addingTimeInterval(-60 * 60 * 24 * 10)
        s.emergencyUnblockDates = [recent]
        #expect(s.emergencyUnblocksAvailable == Settings.maxEmergencyUnblocks - 1)
    }

    @Test func defaultsAreNil() {
        let s = Settings()
        #expect(s.defaultKeyType == nil)
        #expect(s.defaultUnblockDuration == nil)
        #expect(s.blockAllPreventsAppDelete == true)
        #expect(s.hasCompletedOnboarding == false)
        #expect(s.defaultTab == nil)
    }
}
