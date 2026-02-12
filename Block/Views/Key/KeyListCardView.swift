import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct KeyListCardView: View {
    @Environment(\.modelContext) private var modelContext
    let key: Key

    var body: some View {
        HStack(spacing: 16) {
            // Icon representing the physical hardware
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
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(key)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
