import FamilyControls
import SwiftUI

struct SelectionListView: View {
    var selection: FamilyActivitySelection

    var body: some View {
        if !selection.categoryTokens.isEmpty {
            Section("Selected Categories") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 32))], spacing: 10) {
                    SelectionIconsView(tokens: tokenToHashableArray(tokens: selection.categoryTokens))
                }
            }
        }

        if !selection.applicationTokens.isEmpty {
            Section("Selected Apps") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 32))], spacing: 10) {
                    SelectionIconsView(tokens: tokenToHashableArray(tokens: selection.applicationTokens))
                }
            }
        }

        if !selection.webDomainTokens.isEmpty {
            Section("Selected Domains") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                        Label(token)
                            .scaleEffect(0.85, anchor: .leading)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
