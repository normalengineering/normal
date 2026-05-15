import SwiftData
import SwiftUI

struct KeyListCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var keys: [Key]

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var showLastKeyAlert = false

    let key: Key

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var isLastKey: Bool { keys.count <= 1 }

    private var iconName: String {
        key.type == .nfc ? "sensor.tag.radiowaves.forward.fill" : "qrcode"
    }

    var body: some View {
        GlassCard(spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.lg) {
                CircleIconAvatar(systemImage: iconName)

                VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                    Text(key.name).font(.headline)
                    Text(key.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .onTapGesture { if !isBlocked { isEditing = true } }
        .sheet(isPresented: $isEditing) {
            KeyFormSheet(existing: key)
        }
        .editDeleteContextMenu(
            isDisabled: isBlocked,
            onEdit: { isEditing = true },
            onDelete: attemptDelete
        )
        .deleteConfirmation(
            title: "Delete Key?",
            itemName: key.name,
            isPresented: $showDeleteConfirmation,
            onDelete: { modelContext.delete(key) }
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
