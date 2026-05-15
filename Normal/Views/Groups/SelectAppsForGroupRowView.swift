import FamilyControls
import ManagedSettings
import SwiftUI

struct SelectAppForGroupRowView<T: Hashable>: View {
    let token: T
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                tokenLabel
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var tokenLabel: some View {
        if let appToken = token as? ApplicationToken {
            Label(appToken)
        } else if let webDomainToken = token as? WebDomainToken {
            Label(webDomainToken)
        }
    }
}
