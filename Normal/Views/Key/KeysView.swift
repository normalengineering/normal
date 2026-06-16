import SwiftData
import SwiftUI

struct KeysView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query(sort: [SortDescriptor(\Key.sortIndex)])
    private var keys: [Key]
    @State private var isShowingSheet = false

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0 && !keys.isEmpty
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Keys")
                .settingsToolbar()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { isShowingSheet.toggle() } label: {
                            Label("Add Key", systemImage: "plus")
                        }
                        .accessibilityIdentifier("keys.addButton")
                        .disabled(isBlocked)
                        .sheet(isPresented: $isShowingSheet) {
                            KeyFormSheet()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if keys.isEmpty {
            KeysEmptyStateView { isShowingSheet = true }
        } else {
            ReorderableListView(items: keys, rowContent: { key in
                KeyListCardView(key: key)
            }, onMove: move)
                .safeAreaInset(edge: .bottom) {
                    if isBlocked {
                        FooterMessage(text: "Unblock all apps to edit or delete keys.")
                    }
                }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        _ = SortIndexing.reorder(keys, from: source, to: destination, sortIndex: \.sortIndex)
    }
}
