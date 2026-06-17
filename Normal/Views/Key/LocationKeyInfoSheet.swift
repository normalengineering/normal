import CoreLocation
import SwiftUI

struct LocationKeyInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    let key: Key
    let currentLocation: CLLocation?
    let canDelete: Bool
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    private var tint: Color { key.radiusKind?.zoneColor ?? .accentColor }

    private var distanceText: String? {
        guard let currentLocation, let coordinate = key.coordinate else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return LocationFormat.distance(meters: currentLocation.distance(from: target)) + " away"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.md) {
                CircleIconAvatar(systemImage: key.radiusKind?.icon ?? "location.fill", tint: tint)
                VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                    Text(key.name).font(.headline)
                    if let kind = key.radiusKind {
                        Text(kind.label).font(.subheadline).foregroundStyle(tint)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: DS.Spacing.md) {
                if let radius = key.radiusMeters {
                    infoPill(title: "Radius", value: LocationFormat.distance(meters: radius))
                }
                if let distanceText {
                    infoPill(title: "Distance", value: distanceText)
                }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Key", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.large)
            .disabled(!canDelete)

            if !canDelete {
                Text("At least one key must exist. Add another key before deleting this one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(canDelete ? 260 : 300)])
        .presentationDragIndicator(.visible)
        .deleteConfirmation(
            title: "Delete Key?",
            itemName: key.name,
            isPresented: $showDeleteConfirmation,
            onDelete: onDelete
        )
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
