import FamilyControls
import ManagedSettings
import SwiftUI

struct SelectionIconsView: View {
    let tokens: [AnyHashable]
    var limit: Int?

    var body: some View {
        let sorted = tokens.sortedStably
        let shown = limit.map { Array(sorted.prefix($0)) } ?? sorted
        let overflow = sorted.count - shown.count

        ForEach(shown, id: \.self) { token in
            Group {
                if let appToken = token as? ApplicationToken {
                    Label(appToken)
                } else if let webDomainToken = token as? WebDomainToken {
                    Label(webDomainToken)
                } else if let categoryToken = token as? ActivityCategoryToken {
                    Label(categoryToken)
                }
            }
            .labelStyle(.iconOnly)
        }

        if overflow > 0 {
            Text("+\(overflow)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(.quaternary, in: Capsule())
        }
    }
}
