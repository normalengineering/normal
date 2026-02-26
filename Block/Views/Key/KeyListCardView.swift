import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct KeyListCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    let key: Key

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: key.type == .nfc ? "sensor.tag.radiowaves.forward.fill" : "qrcode")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(key.name)
                    .font(.headline)

                Text(key.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .onTapGesture { if !isBlocked { isEditing = true } }
        .sheet(isPresented: $isEditing) {
            KeyFormSheet(existing: key)
        }
        .contextMenu {
            Button {
                isEditing = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .disabled(isBlocked)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(isBlocked)
        }
        .alert("Delete Key?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(key)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(key.name) will be permanently removed.")
        }
    }
}
