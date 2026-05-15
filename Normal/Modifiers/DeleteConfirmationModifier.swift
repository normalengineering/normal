import SwiftUI

struct DeleteConfirmationModifier: ViewModifier {
    let title: LocalizedStringKey
    let itemName: String
    @Binding var isPresented: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(itemName) will be permanently removed.")
        }
    }
}

extension View {
    func deleteConfirmation(
        title: LocalizedStringKey,
        itemName: String,
        isPresented: Binding<Bool>,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(DeleteConfirmationModifier(
            title: title,
            itemName: itemName,
            isPresented: isPresented,
            onDelete: onDelete
        ))
    }
}
