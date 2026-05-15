import FamilyControls
import Foundation
import SwiftData

@Model
final class AppGroup: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var lastUpdated: Date
    var sortIndex: Int = 0

    init(name: String, selection: FamilyActivitySelection, sortIndex: Int = 0) {
        id = UUID()
        self.name = name
        self.selection = selection
        lastUpdated = .now
        self.sortIndex = sortIndex
    }
}
