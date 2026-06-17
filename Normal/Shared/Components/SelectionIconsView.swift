import FamilyControls
import ManagedSettings
import SwiftUI

struct SelectionIconsView: View {
    let tokens: [AnyHashable]
    var customDomains: [String] = []
    var limit: Int?

    private enum Item: Hashable {
        case token(AnyHashable)
        case domain(String)
    }

    var body: some View {
        let items = tokens.sortedStably.map(Item.token) + customDomains.map(Item.domain)
        let shown = limit.map { Array(items.prefix($0)) } ?? items
        let overflow = items.count - shown.count

        ForEach(shown, id: \.self) { item in
            Group {
                switch item {
                case let .token(token):
                    if let kind = SelectedTokenKind(token) {
                        SelectionTokenLabel(kind: kind)
                    }
                case let .domain(domain):
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                        .overlay {
                            Text(domain.prefix(1).lowercased())
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.primary)
                        }
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
