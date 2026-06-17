import SwiftData
import SwiftUI

struct KeysView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query(filter: #Predicate<Key> { $0.groupID == nil }, sort: [SortDescriptor(\Key.sortIndex)])
    private var keys: [Key]
    @Query(filter: #Predicate<Key> { $0.groupID != nil })
    private var groupKeys: [Key]
    @State private var isShowingSheet = false
    @State private var isShowingGroupKeys = false

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0 && !keys.isEmpty
    }

    var body: some View {
        NavigationStack {
            content
                .sheet(isPresented: $isShowingGroupKeys) { groupKeysSheet }
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
        Group {
            if keys.isEmpty {
                KeysEmptyStateView { isShowingSheet = true }
            } else {
                ReorderableListView(items: keys, rowContent: { key in
                    KeyListCardView(key: key)
                }, onMove: move, footer: { groupKeysRow })
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isBlocked {
                FooterMessage(text: "Unblock all apps to edit or delete keys.")
            } else if keys.isEmpty, !groupKeys.isEmpty {
                groupKeysLink
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private var groupKeysRow: some View {
        if !groupKeys.isEmpty {
            groupKeysLink
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: DS.Spacing.sm - 2,
                    leading: DS.Spacing.lg,
                    bottom: DS.Spacing.sm - 2,
                    trailing: DS.Spacing.lg
                ))
        }
    }

    private var groupKeysLink: some View {
        Button {
            isShowingGroupKeys = true
        } label: {
            GlassCard {
                CountChevronRow(title: "Group Keys", count: groupKeys.count)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("keys.groupKeysLink")
    }

    private var groupKeysSheet: some View {
        NavigationStack {
            GroupKeysViewer()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isShowingGroupKeys = false }
                    }
                }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        _ = SortIndexing.reorder(keys, from: source, to: destination, sortIndex: \.sortIndex)
    }
}
