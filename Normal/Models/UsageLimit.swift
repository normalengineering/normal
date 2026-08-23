import FamilyControls
import Foundation
import SwiftData

/// A daily ceiling on real usage of a chosen set of apps.
///
/// The apps in one limit share its allowance, the way Screen Time's own App
/// Limits work. When it runs out they are shielded again for the rest of the
/// day, whatever else is unblocked.
@Model
final class UsageLimit: Identifiable {
    @Attribute(.unique) var id: UUID

    var selection: FamilyActivitySelection
    var minutesPerDay: Int
    var sortIndex: Int = 0

    /// Shortest allowance we offer. `DeviceActivity` thresholds below a few
    /// minutes fire unreliably, so the picker never goes lower.
    static let minimumMinutes = 5
    static let maximumMinutes = 23 * 60 + 55

    init(
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        minutesPerDay: Int,
        sortIndex: Int = 0
    ) {
        id = UUID()
        self.selection = selection
        self.minutesPerDay = minutesPerDay
        self.sortIndex = sortIndex
    }

    /// Flattens for the monitor extension, which must be able to re-shield
    /// without the app running.
    func toDTO() -> UsageLimitDTO? {
        guard let data = try? selection.toData() else { return nil }
        return UsageLimitDTO(id: id, selectionData: data, minutesPerDay: minutesPerDay)
    }
}
