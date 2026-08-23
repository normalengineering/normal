import FamilyControls
import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    static let dailyLimits = Self("normal.dailyLimits")
}

extension ManagedSettingsStore {
    func applyDailyLimits(_ reached: [UsageLimitDTO], preventsAppDelete: Bool) {
        let selections = reached.compactMap { try? FamilyActivitySelection.fromData($0.selectionData) }
        guard !selections.isEmpty else {
            clearAllSettings()
            return
        }

        replaceShields(with: selections.reduce(FamilyActivitySelection()) { $0.union($1) })
        application.denyAppRemoval = preventsAppDelete ? true : nil
    }

    func syncDailyLimits(from sharedStore: some SharedStoreProviding, on date: Date = .now) {
        applyDailyLimits(
            sharedStore.reachedUsageLimits(on: date),
            preventsAppDelete: sharedStore.loadUsageLimitConfig().preventsAppDelete
        )
    }
}
