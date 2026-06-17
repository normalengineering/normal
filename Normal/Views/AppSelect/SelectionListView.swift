import FamilyControls
import SwiftUI

struct ViewOnlyAppsList: View {
    let selection: FamilyActivitySelection

    var body: some View {
        List {
            tokenSection("Categories", tokens: selection.categoryTokens.asHashableArray)
            tokenSection("Apps", tokens: selection.applicationTokens.asHashableArray)
            tokenSection("Websites", tokens: selection.webDomainTokens.sortedStably.map { $0 as AnyHashable })
        }
        .navigationTitle("Apps")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if selection.allTokens.isEmpty {
                ContentUnavailableView("No Apps Selected", systemImage: "app.dashed")
            }
        }
    }

    @ViewBuilder
    private func tokenSection(_ title: LocalizedStringKey, tokens: [AnyHashable]) -> some View {
        if !tokens.isEmpty {
            Section(title) {
                ForEach(tokens, id: \.self) { token in
                    if let kind = SelectedTokenKind(token) {
                        SelectionTokenLabel(kind: kind)
                    }
                }
            }
        }
    }
}

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
