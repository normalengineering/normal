import CoreLocation
import SwiftUI

struct LocationKeyInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let key: Key
    let currentLocation: CLLocation?
    let deleteDisabledReason: LocalizedStringKey?
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    private var canDelete: Bool {
        deleteDisabledReason == nil
    }

    private var tint: Color {
        key.radiusKind?.zoneColor ?? .accentColor
    }

    private var distanceText: String? {
        guard let currentLocation, let coordinate = key.coordinate else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return LocationFormat.distance(meters: currentLocation.distance(from: target)) + " away"
    }

    var body: some View {
        ScrollView {
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
                    CloseButton(placement: .inline) { dismiss() }
                        .accessibilityIdentifier("locationKeyInfo.close")
                }

                AdaptiveStack(spacing: DS.Spacing.md) {
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

                if let deleteDisabledReason {
                    Text(deleteDisabledReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .deleteConfirmation(
            title: "Delete Key?",
            itemName: key.name,
            isPresented: $showDeleteConfirmation,
            onDelete: onDelete
        )
    }

    private var detents: Set<PresentationDetent> {
        dynamicTypeSize.isAccessibilitySize ? [.medium, .large] : [.height(canDelete ? 260 : 300)]
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
