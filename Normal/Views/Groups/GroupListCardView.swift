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

    private var settings: Settings { allSettings.first! }

    private var blockStatus: BlockStatus {
        screenTimeService.blockStatus(selection: appGroup.selection)
    }

    private var isGroupTimedUnblockActive: Bool {
        timedUnblockService.isGroupUnblockActive(groupId: appGroup.id)
    }

    private var groupUnblockEndDate: Date? {
        timedUnblockService.groupUnblockEndDate(groupId: appGroup.id)
    }

    private var needsSync: Bool {
        guard let mainSelection = selectedApps.first?.selection else { return false }
        return !isSelectionSynced(selection: appGroup.selection, with: mainSelection)
    }

    var body: some View {
        CardView {
            HStack(alignment: .center) {
                Text(appGroup.name)
                    .font(.headline)

                Spacer()

                if needsSync {
                    Label("Needs Update", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.yellow)
                } else if isGroupTimedUnblockActive {
                    Label("Timed Unblock", systemImage: "timer")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                } else {
                    Label(blockStatus.shortLabel, systemImage: blockStatus.icon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(blockStatus.color)
                }
            }

            HStack(spacing: 8) {
                SelectionIconsView(tokens: allTokensFromSelection(selection: appGroup.selection))
            }

            if needsSync {
                Text("App selection changed. Please re-select apps in this group.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !needsSync, let endDate = groupUnblockEndDate, endDate > .now {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)

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
                        Text("Block Now")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }

            if !needsSync && !isGroupTimedUnblockActive {
                HStack(spacing: 10) {
                    if blockStatus != .all {
                        Button {
                            allowBypass = true
                            authAction = {
                                screenTimeService.addToShields(selection: appGroup.selection)
                            }
                        } label: {
                            Label(
                                blockStatus == .some ? "Block All" : "Block",
                                systemImage: "lock.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }

                    if blockStatus != .none {
                        Button {
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
                        } label: {
                            Label(
                                blockStatus == .some ? "Unblock All" : "Unblock",
                                systemImage: "lock.open.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .opacity(needsSync ? 0.6 : 1.0)
        .onTapGesture { isEditing = true }
        .contextMenu { contextActions }
        .sheet(isPresented: $isEditing) {
            GroupFormSheet(existing: appGroup)
        }
        .sheet(isPresented: $showTimedUnblockSheet) {
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
        .alert("Delete Group?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(appGroup)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(appGroup.name) will be permanently removed.")
        }
        .keySelect(action: $authAction, allowBypass: allowBypass, defaultKeyType: settings.defaultKeyType)
    }

    @ViewBuilder
    private var contextActions: some View {
        Button {
            isEditing = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
