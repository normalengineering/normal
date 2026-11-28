import SwiftData
import SwiftUI

struct KeyListCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(EditSessionService.self) private var editSessionService

    @Query private var keys: [Key]
    @Query private var allSettings: [Settings]

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var showLastKeyAlert = false

    let key: Key

    private var isEditBlocked: Bool {
        editSessionService.isEditingBlocked(
            mode: allSettings.unwrapped.editProtectionMode,
            keys: keys,
            activeShieldCount: screenTimeService.activeShieldCount()
        )
    }

    private var isLastKey: Bool {
        !Key.canDelete(key, in: keys)
    }

    var body: some View {
        GlassCard(spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.lg) {
                CircleIconAvatar(systemImage: key.symbolName)

                VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                    Text(key.name).font(.headline)
                    Text(key.displayTypeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityIdentifier("key.card")
        .onTapGesture { isEditing = true }
        .sheet(isPresented: $isEditing) {
            KeyFormSheet(existing: key)
        }
        .editDeleteContextMenu(
            isDisabled: isEditBlocked,
            onEdit: { isEditing = true },
            onDelete: attemptDelete
        )
        .deleteConfirmation(
            title: "Delete Key?",
            itemName: key.name,
            isPresented: $showDeleteConfirmation,
            onDelete: {
                guard !isEditBlocked, Key.canDelete(key, in: keys) else { return }
                modelContext.delete(key)
            }
        )
        .alert("Can't Delete Key", isPresented: $showLastKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("At least one key must exist. Add another key before deleting this one.")
        }
    }

    private func attemptDelete() {
        if isLastKey {
            showLastKeyAlert = true
        } else {
            showDeleteConfirmation = true
        }
    }
}
