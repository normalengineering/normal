import SwiftData
import SwiftUI

struct GroupKeyRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService
    let key: Key

    @State private var isEditing = false

    private var isBlocked: Bool { screenTimeService.activeShieldCount() > 0 }

    var body: some View {
        Button { isEditing = true } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                        Text(key.name).lineLimit(1)
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
            isDisabled: isBlocked,
            onEdit: { isEditing = true },
            onDelete: { modelContext.delete(key) }
        )
        .sheet(isPresented: $isEditing) {
            KeyFormSheet(existing: key)
        }
    }
}
