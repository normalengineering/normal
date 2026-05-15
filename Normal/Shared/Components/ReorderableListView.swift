import SwiftUI

struct ReorderableListView<T: Identifiable, Content: View>: View {
    let items: [T]
    @ViewBuilder let rowContent: (T) -> Content
    let onMove: (IndexSet, Int) -> Void

    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                rowContent(item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: DS.Spacing.sm - 2,
                        leading: DS.Spacing.lg,
                        bottom: DS.Spacing.sm - 2,
                        trailing: DS.Spacing.lg
                    ))
            }
            .onMove(perform: onMove)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }
}
