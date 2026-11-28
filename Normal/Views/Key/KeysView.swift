import SwiftData
import SwiftUI

struct KeysView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(EditSessionService.self) private var editSessionService

    @Query(filter: #Predicate<Key> { $0.groupID == nil }, sort: [SortDescriptor(\Key.sortIndex)])
    private var keys: [Key]
    @Query(filter: #Predicate<Key> { $0.groupID != nil })
    private var groupKeys: [Key]
    @Query private var allKeys: [Key]
    @Query private var allSettings: [Settings]
    @State private var isShowingSheet = false
    @State private var isShowingGroupKeys = false

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var isEditBlocked: Bool {
        editSessionService.isEditingBlocked(
            mode: settings.editProtectionMode,
            keys: allKeys,
            activeShieldCount: screenTimeService.activeShieldCount(),
            allowWhenNoKeys: true
        )
    }

    var body: some View {
        NavigationStack {
            content
                .editProtectionBar(unblockAllMessage: BlockedMessage.keys, allowWhenNoKeys: true)
                .sheet(isPresented: $isShowingGroupKeys) { groupKeysSheet }
                .navigationTitle("Keys")
                .settingsToolbar()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            guard !isEditBlocked else { return }
                            isShowingSheet.toggle()
                        } label: {
                            Label("Add Key", systemImage: "plus")
                        }
                        .accessibilityIdentifier("keys.addButton")
                        .disabled(isEditBlocked)
                        .sheet(isPresented: $isShowingSheet) {
                            KeyFormSheet()
                        }
                    }
                }
        }
    }

    private var content: some View {
        Group {
            if keys.isEmpty {
                VStack(spacing: 0) {
                    KeysEmptyStateView(isAddDisabled: isEditBlocked) {
                        guard !isEditBlocked else { return }
                        isShowingSheet = true
                    }
                    if !groupKeys.isEmpty {
                        groupKeysLink
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.sm)
                    }
                }
            } else {
                ReorderableListView(
                    items: keys,
                    rowContent: { key in
                        KeyListCardView(key: key)
                    },
                    onMove: isEditBlocked ? nil : { move(from: $0, to: $1) },
                    footer: { groupKeysRow }
                )
            }
        }
    }

    @ViewBuilder
    private var groupKeysRow: some View {
        if !groupKeys.isEmpty {
            groupKeysLink
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
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
        guard !isEditBlocked else { return }
        _ = SortIndexing.reorder(keys, from: source, to: destination, sortIndex: \.sortIndex)
    }
}
