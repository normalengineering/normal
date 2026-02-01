import FamilyControls
import Foundation
import SwiftData

@Model
final class AppGroup: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var selection: FamilyActivitySelection

    init(name: String, selection: FamilyActivitySelection) {
        id = UUID()
        self.name = name
        self.selection = selection
    }
}
