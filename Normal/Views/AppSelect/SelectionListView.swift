import FamilyControls
import SwiftUI

struct SelectionListView: View {
    let selection: FamilyActivitySelection

    var body: some View {
        if !selection.categoryTokens.isEmpty {
            tokenGridSection(
                title: "Selected Categories",
                tokens: selection.categoryTokens.asHashableArray
            )
        }

        if !selection.applicationTokens.isEmpty {
            tokenGridSection(
                title: "Selected Apps",
                tokens: selection.applicationTokens.asHashableArray
            )
        }

        if !selection.webDomainTokens.isEmpty {
            Section("Selected Domains") {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(selection.webDomainTokens.sortedStably, id: \.self) { token in
                        Label(token).scaleEffect(0.85, anchor: .leading)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }
        }
    }

    private func tokenGridSection(title: LocalizedStringKey, tokens: [AnyHashable]) -> some View {
        Section(title) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 32))], spacing: DS.Spacing.md - 2) {
                SelectionIconsView(tokens: tokens)
            }
        }
    }
}
