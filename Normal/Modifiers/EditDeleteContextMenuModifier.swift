import SwiftUI

struct EditDeleteContextMenuModifier: ViewModifier {
    let onEdit: () -> Void
    let onDuplicate: (() -> Void)?
    let onDelete: () -> Void
    var isDisabled: Bool
    var isDuplicateDisabled: Bool

    func body(content: Content) -> some View {
        content.contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .disabled(isDisabled)

            if let onDuplicate {
                Button(action: onDuplicate) {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .disabled(isDisabled || isDuplicateDisabled)
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(isDisabled)
        }
    }
}

extension View {
    func editDeleteContextMenu(
        isDisabled: Bool = false,
        isDuplicateDisabled: Bool = false,
        onEdit: @escaping () -> Void,
        onDuplicate: (() -> Void)? = nil,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(EditDeleteContextMenuModifier(
            onEdit: onEdit,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
            isDisabled: isDisabled,
            isDuplicateDisabled: isDuplicateDisabled
        ))
    }
}
