import FamilyControls
import SwiftData
import SwiftUI

struct GroupListCardView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(\.modelContext) private var modelContext

    @Query private var selectedApps: [SelectedApps]
    @Query private var allSettings: [Settings]

    let appGroup: AppGroup

    @State private var authAction: (@MainActor () -> Void)?
    @State private var allowBypass = false
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var showTimedUnblockSheet = false

    private var settings: Settings { allSettings.unwrapped }

    private var blockStatus: BlockStatus {
        screenTimeService.blockStatus(selection: appGroup.selection)
    }

    private var isTimedUnblockActive: Bool {
        timedUnblockService.isGroupUnblockActive(groupId: appGroup.id)
    }

    private var unblockEndDate: Date? {
        timedUnblockService.groupUnblockEndDate(groupId: appGroup.id)
    }

    private var needsSync: Bool {
        guard let mainSelection = selectedApps.first?.selection else { return false }
        return !appGroup.selection.isSubset(of: mainSelection)
    }

    var body: some View {
        GlassCard {
            header
            tokenStrip
            if needsSync { syncWarningText }
            if !needsSync, let endDate = unblockEndDate, endDate > .now {
                timedUnblockRow(endDate: endDate)
            }
            if !needsSync && !isTimedUnblockActive { actionRow }
        }
        .opacity(needsSync ? DS.Opacity.dim : 1)
        .onTapGesture { isEditing = true }
        .editDeleteContextMenu(
            onEdit: { isEditing = true },
            onDelete: { showDeleteConfirmation = true }
        )
        .sheet(isPresented: $isEditing) {
            GroupFormSheet(existing: appGroup)
        }
        .sheet(isPresented: $showTimedUnblockSheet) { timedUnblockSheet }
        .deleteConfirmation(
            title: "Delete Group?",
            itemName: appGroup.name,
            isPresented: $showDeleteConfirmation,
            onDelete: { modelContext.delete(appGroup) }
        )
        .protectedAction($authAction, allowBypass: allowBypass, defaultKeyType: settings.defaultKeyType)
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
        } else if isTimedUnblockActive {
            StatusBadge(title: "Timed Unblock", systemImage: "timer", tint: .orange)
        } else {
            StatusBadge(title: LocalizedStringKey(blockStatus.shortLabel), systemImage: blockStatus.icon, tint: blockStatus.color)
        }
    }

    private var tokenStrip: some View {
        HStack(spacing: DS.Spacing.sm) {
            SelectionIconsView(tokens: appGroup.selection.allTokens)
        }
    }

    private var syncWarningText: some View {
        Text("App selection changed. Please re-select apps in this group.")
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
                allowBypass = true
                authAction = {
                    timedUnblockService.cancelGroup(
                        groupId: appGroup.id,
                        selection: appGroup.selection,
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
            allowBypass = true
            authAction = {
                screenTimeService.addToShields(selection: appGroup.selection)
            }
        }
    }

    private var unblockButton: some View {
        CardActionButton(
            title: blockStatus == .some ? "Unblock All" : "Unblock",
            systemImage: "lock.open.fill",
            prominent: false
        ) {
            allowBypass = false
            authAction = {
                if let duration = settings.defaultUnblockDuration {
                    try? timedUnblockService.startGroup(
                        duration: duration,
                        groupId: appGroup.id,
                        selection: appGroup.selection,
                        screenTimeService: screenTimeService
                    )
                } else {
                    showTimedUnblockSheet = true
                }
            }
        }
    }

    private var timedUnblockSheet: some View {
        TimedUnblockSheet(
            title: "Unblock \(appGroup.name)",
            onTimedUnblock: { duration in
                try timedUnblockService.startGroup(
                    duration: duration,
                    groupId: appGroup.id,
                    selection: appGroup.selection,
                    screenTimeService: screenTimeService
                )
            },
            onPermanentUnblock: {
                screenTimeService.removeFromShields(selection: appGroup.selection)
            }
        )
    }
}
