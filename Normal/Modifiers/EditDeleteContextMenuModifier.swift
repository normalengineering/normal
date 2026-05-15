import SwiftUI

struct EditDeleteContextMenuModifier: ViewModifier {
    let onEdit: () -> Void
    let onDelete: () -> Void
    var isDisabled: Bool

    func body(content: Content) -> some View {
        content.contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .disabled(isDisabled)

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
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(EditDeleteContextMenuModifier(
            onEdit: onEdit,
            onDelete: onDelete,
            isDisabled: isDisabled
        ))
    }
}
