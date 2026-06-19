import FamilyControls
import SwiftData
import SwiftUI

struct GroupListCardView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(\.modelContext) private var modelContext

    @Query private var selectedApps: [SelectedApps]
    @Query private var allSettings: [Settings]
    @Query private var allKeys: [Key]

    let appGroup: AppGroup
    // Hosted on the stable GroupsView list rather than this card: a sheet attached to
    // a card row whose block/unblock buttons swap gets wedged and won't re-present.
    @Binding var authAction: (@MainActor () -> Void)?
    @Binding var allowBypass: Bool
    @Binding var pendingGroupID: UUID?
    @Binding var pendingDurationGroup: AppGroup?

    @State private var isEditing = false
    @State private var isReselecting = false
    @State private var showDeleteConfirmation = false

    private var settings: Settings { allSettings.unwrapped }

    private var customDomains: [String] {
        settings.enableCustomDomains ? appGroup.customDomains : []
    }

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var hasGlobalKey: Bool { Key.hasGlobalKey(in: allKeys) }

    private var blockStatus: BlockStatus {
        screenTimeService.blockStatus(selection: appGroup.selection, customDomains: customDomains)
    }

    private var isTimedUnblockActive: Bool {
        timedUnblockService.isGroupUnblockActive(groupId: appGroup.id)
    }

    private var unblockEndDate: Date? {
        timedUnblockService.groupUnblockEndDate(groupId: appGroup.id)
    }

    private var showsTimedUnblock: Bool {
        isTimedUnblockActive && blockStatus != .all
    }

    private var needsSync: Bool {
        guard let main = selectedApps.first else { return false }
        if !appGroup.selection.isSubset(of: main.selection) { return true }
        if settings.enableCustomDomains,
           CustomDomains.needsResync(appGroup.customDomains, main: main.customDomains) { return true }
        return false
    }

    var body: some View {
        GlassCard {
            header
            tokenStrip
            if needsSync { syncWarningText }
            if !needsSync, showsTimedUnblock, let endDate = unblockEndDate, endDate > .now {
                timedUnblockRow(endDate: endDate)
            }
            if !needsSync && !showsTimedUnblock { actionRow }
        }
        .opacity(needsSync ? DS.Opacity.dim : 1)
        .onTapGesture {
            if needsSync { isReselecting = true } else { isEditing = true }
        }
        .editDeleteContextMenu(
            isDisabled: isBlocked,
            onEdit: { if needsSync { isReselecting = true } else { isEditing = true } },
            onDelete: { showDeleteConfirmation = true }
        )
        .sheet(isPresented: $isEditing) {
            GroupFormSheet(existing: appGroup)
        }
        .sheet(isPresented: $isReselecting) {
            SelectAppsForGroupSheet(selection: reselectionBinding, customDomains: reselectionDomainsBinding)
        }
        .deleteConfirmation(
            title: "Delete Group?",
            itemName: appGroup.name,
            isPresented: $showDeleteConfirmation,
            onDelete: {
                appGroup.deleteCascading(keys: allKeys, from: modelContext)
            }
        )
    }

    private func requestAction(allowBypass: Bool, _ action: @escaping @MainActor () -> Void) {
        pendingGroupID = appGroup.id
        self.allowBypass = allowBypass
        authAction = action
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(appGroup.name)
                .font(.headline)
            Spacer()
            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if needsSync {
            StatusBadge(title: "Needs Update", systemImage: "exclamationmark.triangle.fill", tint: .yellow)
        } else if showsTimedUnblock {
            StatusBadge(title: "Timed Unblock", systemImage: "timer", tint: .orange)
        } else {
            StatusBadge(title: LocalizedStringKey(blockStatus.shortLabel), systemImage: blockStatus.icon, tint: blockStatus.color)
        }
    }

    private var tokenStrip: some View {
        HStack(spacing: DS.Spacing.sm) {
            SelectionIconsView(
                tokens: appGroup.selection.allTokens,
                customDomains: customDomains,
                limit: 6
            )
        }
    }

    private var reselectionBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: { appGroup.selection },
            set: { newValue in
                appGroup.selection = newValue
                appGroup.lastUpdated = .now
                timedUnblockService.updateGroupSelection(
                    groupId: appGroup.id,
                    selection: newValue,
                    customDomains: customDomains
                )
            }
        )
    }

    private var reselectionDomainsBinding: Binding<[String]> {
        Binding(
            get: { appGroup.customDomains },
            set: { newValue in
                appGroup.customDomains = newValue
                appGroup.lastUpdated = .now
                timedUnblockService.updateGroupSelection(
                    groupId: appGroup.id,
                    selection: appGroup.selection,
                    customDomains: settings.enableCustomDomains ? newValue : []
                )
            }
        )
    }

    private var syncWarningText: some View {
        Text("Your selection changed. Please re-select apps or domains in this group.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func timedUnblockRow(endDate: Date) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "timer").foregroundStyle(.orange)
            Text(timerInterval: .now ... endDate, countsDown: true)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                requestAction(allowBypass: true) {
                    timedUnblockService.cancelGroup(
                        groupId: appGroup.id,
                        selection: appGroup.selection,
                        customDomains: customDomains,
                        screenTimeService: screenTimeService
                    )
                }
            } label: {
                Text("Block Now").font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }

    private var actionRow: some View {
        HStack(spacing: DS.Spacing.md - 2) {
            if blockStatus != .all {
                blockButton
            }
            if blockStatus != .none {
                unblockButton
            }
        }
    }

    private var blockButton: some View {
        CardActionButton(
            title: blockStatus == .some ? "Block All" : "Block",
            systemImage: "lock.fill",
            prominent: true,
            tint: .blue
        ) {
            requestAction(allowBypass: true) {
                screenTimeService.addToShields(selection: appGroup.selection, customDomains: customDomains)
            }
        }
        .accessibilityIdentifier("group.blockButton")
        .disabled(!hasGlobalKey)
    }

    private var unblockButton: some View {
        CardActionButton(
            title: blockStatus == .some ? "Unblock All" : "Unblock",
            systemImage: "lock.open.fill",
            prominent: false
        ) {
            requestAction(allowBypass: false) {
                if let duration = settings.defaultUnblockDuration {
                    try? timedUnblockService.startGroup(
                        duration: duration,
                        groupId: appGroup.id,
                        selection: appGroup.selection,
                        customDomains: customDomains,
                        screenTimeService: screenTimeService
                    )
                } else {
                    pendingDurationGroup = appGroup
                }
            }
        }
        .accessibilityIdentifier("group.unblockButton")
    }
}
