import FamilyControls
import Foundation
import SwiftData

@Model
final class SelectedApps {
    @Attribute(.unique) var id: String = "APP_MASTER_SELECTION"
    var selection: FamilyActivitySelection
    var lastUpdated: Date
    var isBlocked: Bool
    var strictMode: Bool

    init(selection: FamilyActivitySelection) {
        self.selection = selection
        lastUpdated = .now
        isBlocked = false
        strictMode = false
    }

    func toggleBlockedStatus() {
        isBlocked.toggle()
    }
}
