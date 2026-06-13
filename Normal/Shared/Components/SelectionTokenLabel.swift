import FamilyControls
import ManagedSettings
import SwiftUI

struct SelectionTokenLabel: View {
    let kind: SelectedTokenKind

    var body: some View {
        switch kind {
        case let .application(token): Label(token)
        case let .webDomain(token): Label(token)
        case let .category(token): Label(token)
        }
    }
}
