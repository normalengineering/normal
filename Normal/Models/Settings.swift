import Foundation
import SwiftData

@Model
final class Settings {
    @Attribute(.unique) var id: String = "APP_SETTINGS"

    var emergencyUnblockDates: [Date]
    var defaultKeyType: KeyType?
    var defaultUnblockDuration: UnblockDuration?
    var hasCompletedOnboarding: Bool = false
    var blockAllPreventsAppDelete: Bool = true
    var defaultTab: AppTab?

    static let maxEmergencyUnblocks = 3
    private static let emergencyWindowDays = 180

    init() {
        self.emergencyUnblockDates = []
        self.defaultKeyType = nil
        self.defaultUnblockDuration = nil
    }

    var emergencyUnblocksAvailable: Int {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -Self.emergencyWindowDays, to: .now
        )!
        let recentCount = emergencyUnblockDates.filter { $0 > cutoff }.count
        return max(Self.maxEmergencyUnblocks - recentCount, 0)
    }

    func recordEmergencyUnblock() {
        emergencyUnblockDates.append(.now)
    }
}

extension Array where Element == Settings {
    var unwrapped: Settings {
        guard let settings = first else {
            preconditionFailure("Settings row missing — NormalApp.init must insert one on launch")
        }
        return settings
    }
}
