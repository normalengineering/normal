import SwiftUI

struct ReorderableListView<T: Identifiable, Content: View, Footer: View>: View {
    let items: [T]
    let rowContent: (T) -> Content
    let onMove: (IndexSet, Int) -> Void
    let footer: Footer

    init(
        items: [T],
        @ViewBuilder rowContent: @escaping (T) -> Content,
        onMove: @escaping (IndexSet, Int) -> Void,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.items = items
        self.rowContent = rowContent
        self.onMove = onMove
        self.footer = footer()
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(
            top: DS.Spacing.sm - 2,
            leading: DS.Spacing.lg,
            bottom: DS.Spacing.sm - 2,
            trailing: DS.Spacing.lg
        )
    }

    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                rowContent(item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(rowInsets)
            }
            .onMove(perform: onMove)

            footer
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }
}
