import FamilyControls
import Foundation
import SwiftData

@Model
final class SelectedApps {
    @Attribute(.unique) var id: String = "APP_MAIN_SELECTION"
    var selection: FamilyActivitySelection
    var lastUpdated: Date

    init(selection: FamilyActivitySelection) {
        self.selection = selection
        lastUpdated = .now
    }
}
