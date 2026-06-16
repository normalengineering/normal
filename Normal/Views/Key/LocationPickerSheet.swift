import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService
    @Query private var keys: [Key]

    let kind: LocationRadiusKind
    let onSave: (Double, Double, Double) -> Void
    @State private var pin: CLLocationCoordinate2D?
    @State private var radiusMeters: Double = 400
    @State private var currentLocation: CLLocation?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var permissionDenied = false
    @State private var inspectedKey: Key?

    static let minRadius: Double = 50
    static let maxRadius: Double = 5_000

    private var existingZones: [Key] {
        keys.filter { $0.type == .location && $0.radiusKind == kind && $0.coordinate != nil }
    }

    private var saveDisabled: Bool { pin == nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if permissionDenied { deniedBanner }
                map
                controls
            }
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(saveDisabled)
                        .accessibilityIdentifier("locationPicker.saveButton")
                }
            }
            .sheet(item: $inspectedKey) { key in
                LocationKeyInfoSheet(
                    key: key,
                    currentLocation: currentLocation,
                    canDelete: keys.count > 1,
                    onDelete: { delete(key) }
                )
                .presentationDetents([.height(280)])
            }
            .task(initialResolve)
        }
    }

    // MARK: - Map

    private var map: some View {
        MapReader { proxy in
            Map(position: $position) {
                ForEach(existingZones) { key in
                    if let coordinate = key.coordinate, let radius = key.radiusMeters {
                        MapCircle(center: coordinate, radius: radius)
                            .foregroundStyle(kind.zoneColor.opacity(0.16))
                            .stroke(kind.zoneColor.opacity(0.9), lineWidth: 1.5)
                        Annotation(key.name, coordinate: coordinate) {
                            zoneDot(filled: false)
                        }
                        .annotationTitles(.hidden)
                    }
                }

                if let pin {
                    MapCircle(center: pin, radius: radiusMeters)
                        .foregroundStyle(kind.zoneColor.opacity(0.28))
                        .stroke(kind.zoneColor, style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
                    Annotation("New", coordinate: pin) {
                        newPin
                    }
                    .annotationTitles(.hidden)
                }

                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .overlay(kind.fieldColor.opacity(0.10).allowsHitTesting(false))
            .overlay(alignment: .top) { tapHint }
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                handleTap(at: coordinate)
            }
        }
        .accessibilityIdentifier("locationPicker.map")
    }

    @ViewBuilder
    private var tapHint: some View {
        if pin == nil {
            Label("Tap to select a location", systemImage: "hand.tap.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, DS.Spacing.md)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private func zoneDot(filled: Bool) -> some View {
        Circle()
            .fill(kind.zoneColor.opacity(filled ? 1 : 0.85))
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 1)
            .allowsHitTesting(false)
    }

    private var newPin: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.title)
            .foregroundStyle(kind.zoneColor)
            .background(Circle().fill(.white).padding(4))
            .allowsHitTesting(false)
    }

    private func handleTap(at coordinate: CLLocationCoordinate2D) {
        let tapped = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let hit = existingZones.first(where: { key in
            guard let c = key.coordinate, let r = key.radiusMeters else { return false }
            return CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: tapped) <= r
        }) {
            inspectedKey = hit
        } else {
            withAnimation(.easeOut(duration: 0.2)) { pin = coordinate }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            legend

            HStack {
                Text(radiusLabel)
                    .font(.headline.monospacedDigit())
                Spacer()
                Button {
                    centerOnCurrent()
                } label: {
                    Label("My Location", systemImage: "location.fill").font(.subheadline)
                }
                .accessibilityIdentifier("locationPicker.useCurrentButton")
                .disabled(currentLocation == nil)
            }

            Slider(value: $radiusMeters, in: Self.minRadius ... Self.maxRadius, step: 50) {
                Text("Radius")
            }
            .tint(kind.zoneColor)
            .accessibilityIdentifier("locationPicker.radiusSlider")

            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.regularMaterial)
    }

    private var legend: some View {
        HStack(spacing: DS.Spacing.lg) {
            legendItem(color: kind.zoneColor, text: kind.zoneLegend, filled: true)
            legendItem(color: kind.fieldColor, text: kind.fieldLegend, filled: false)
            Spacer()
        }
    }

    private func legendItem(color: Color, text: String, filled: Bool) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(color.opacity(filled ? 0.85 : 0.18))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(color, lineWidth: 1.5))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var radiusLabel: String {
        "Radius: \(Self.formatted(meters: radiusMeters))"
    }

    private var hint: String {
        if pin == nil {
            return existingZones.isEmpty
                ? "Tap the map to drop a pin, or use your location."
                : "Tap the map to add another area. Tap an existing area to view or delete it."
        }
        return "Drag the slider to size the area, then Save."
    }

    private var deniedBanner: some View {
        VStack(spacing: DS.Spacing.sm) {
            Label("Location permission needed", systemImage: "location.slash")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Enable location access in Settings to use your current spot. You can still pick anywhere on the map.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.bold())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func centerOnCurrent() {
        guard let currentLocation else { return }
        pin = currentLocation.coordinate
        position = .region(MKCoordinateRegion(
            center: currentLocation.coordinate,
            latitudinalMeters: radiusMeters * 4,
            longitudinalMeters: radiusMeters * 4
        ))
    }

    @MainActor
    private func initialResolve() async {
        if currentLocation == nil, let cached = locationService.cachedLocation {
            currentLocation = cached
            if pin == nil, existingZones.isEmpty { pin = cached.coordinate }
        }
        do {
            let location = try await locationService.currentLocation()
            currentLocation = location
            if pin == nil, existingZones.isEmpty {
                pin = location.coordinate
            }
        } catch LocationKeyError.denied, LocationKeyError.restricted {
            permissionDenied = true
        } catch {
            permissionDenied = false
        }
    }

    private func delete(_ key: Key) {
        guard keys.count > 1 else { return }
        modelContext.delete(key)
        inspectedKey = nil
    }

    private func save() {
        guard let pin else { return }
        onSave(pin.latitude, pin.longitude, radiusMeters)
        dismiss()
    }

    static func formatted(meters: Double) -> String {
        if meters < 1_000 { return "\(Int(meters)) m" }
        return String(format: "%.1f km", meters / 1_000)
    }
}

private struct LocationKeyInfoSheet: View {
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
        return LocationPickerSheet.formatted(meters: currentLocation.distance(from: target)) + " away"
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
                    infoPill(title: "Radius", value: LocationPickerSheet.formatted(meters: radius))
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

/// Read-only map snapshot of a single location key, used in the key detail view.
struct LocationKeyMapPreview: View {
    let key: Key

    var body: some View {
        if let coordinate = key.coordinate, let radius = key.radiusMeters {
            let kind = key.radiusKind ?? .unblock
            Map(
                initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: radius * 4,
                    longitudinalMeters: radius * 4
                )),
                interactionModes: []
            ) {
                MapCircle(center: coordinate, radius: radius)
                    .foregroundStyle(kind.zoneColor.opacity(0.28))
                    .stroke(kind.zoneColor, lineWidth: 2)
                Annotation("", coordinate: coordinate) {
                    Circle()
                        .fill(kind.zoneColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(radius: 1)
                }
                .annotationTitles(.hidden)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }
}
