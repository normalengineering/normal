import SwiftData
import SwiftUI

struct GroupKeyRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(EditSessionService.self) private var editSessionService
    @Query private var allKeys: [Key]
    @Query private var allSettings: [Settings]
    let key: Key

    @State private var isEditing = false

    private var isEditBlocked: Bool {
        editSessionService.isEditingBlocked(
            mode: allSettings.unwrapped.editProtectionMode,
            keys: allKeys,
            activeShieldCount: screenTimeService.activeShieldCount()
        )
    }

    var body: some View {
        Button {
            isEditing = true
        } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                        Text(key.name)
                        Text(key.displayTypeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: key.symbolName)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .editDeleteContextMenu(
            isDisabled: isEditBlocked,
            onEdit: { isEditing = true },
            onDelete: {
                guard !isEditBlocked else { return }
                modelContext.delete(key)
            }
        )
        .sheet(isPresented: $isEditing) {
            KeyFormSheet(existing: key)
        }
    }
}
