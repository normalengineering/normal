import SwiftData
import SwiftUI

struct KeyListCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    let key: Key

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

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
            onDelete: { showDeleteConfirmation = true }
        )
        .deleteConfirmation(
            title: "Delete Key?",
            itemName: key.name,
            isPresented: $showDeleteConfirmation,
            onDelete: { modelContext.delete(key) }
        )
    }
}
