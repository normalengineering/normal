import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct GroupListCardView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(\.modelContext) private var modelContext

    let appGroup: AppGroup

    @State private var authAction: (@MainActor () -> Void)?
    @State private var allowBypass = false
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    private var blockStatus: BlockStatus {
        screenTimeService.blockStatus(selection: appGroup.selection)
    }

    var body: some View {
        CardView {
            HStack(alignment: .center) {
                Text(appGroup.name)
                    .font(.headline)

                Spacer()

                Label(blockStatus.shortLabel, systemImage: blockStatus.icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(blockStatus.color)
            }

            HStack(spacing: 8) {
                let allTokens = allTokensFromSelection(selection: appGroup.selection)
                SelectionIconsView(tokens: allTokens)
            }

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
                            screenTimeService.removeFromShields(selection: appGroup.selection)
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
        .onTapGesture { isEditing = true }
        .contextMenu { contextActions }
        .sheet(isPresented: $isEditing) {
            GroupFormSheet(existing: appGroup)
        }
        .alert("Delete Group?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(appGroup)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(appGroup.name) will be permanently removed.")
        }
        .keySelect(action: $authAction, allowBypass: allowBypass)
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

extension BlockStatus {
    var shortLabel: String {
        switch self {
        case .all: "Blocked"
        case .some: "Partial"
        case .none: "Unblocked"
        }
    }
}
