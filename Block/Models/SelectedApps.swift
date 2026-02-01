import FamilyControls
import Foundation
import SwiftData

@Model
final class SelectedApps {
    var selection: FamilyActivitySelection
    var lastUpdated: Date
    var isBlocked: Bool

    init(selection: FamilyActivitySelection) {
        self.selection = selection
        lastUpdated = .now
        isBlocked = false
    }

    func toggleBlockedStatus() {
        isBlocked.toggle()
    }
}
