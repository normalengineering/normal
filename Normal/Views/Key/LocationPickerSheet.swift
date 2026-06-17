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
    var groupID: UUID?
    let onSave: (Double, Double, Double) -> Void

    @State private var pin: CLLocationCoordinate2D?
    @State private var radiusMeters: Double = 400
    @State private var currentLocation: CLLocation?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var permissionDenied = false
    @State private var inspectedKey: Key?

    /// Existing zones in scope (global + this group's) of the same radius kind.
    private var existingZones: [Key] {
        Key.scoped(keys, toGroup: groupID)
            .filter { $0.type == .location && $0.radiusKind == kind && $0.coordinate != nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if permissionDenied { LocationPermissionBanner() }

                LocationPickerMapView(
                    kind: kind,
                    zones: existingZones,
                    pin: $pin,
                    position: $position,
                    radiusMeters: radiusMeters,
                    onInspect: { inspectedKey = $0 }
                )

                LocationRadiusControls(
                    kind: kind,
                    radiusMeters: $radiusMeters,
                    canUseCurrentLocation: currentLocation != nil,
                    hint: hint,
                    onUseCurrentLocation: centerOnCurrent
                )
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
                        .disabled(pin == nil)
                        .accessibilityIdentifier("locationPicker.saveButton")
                }
            }
            .sheet(item: $inspectedKey) { key in
                LocationKeyInfoSheet(
                    key: key,
                    currentLocation: currentLocation,
                    canDelete: Key.canDelete(key, in: keys),
                    onDelete: { delete(key) }
                )
                .presentationDetents([.height(280)])
            }
            .task(initialResolve)
        }
    }

    private var hint: String {
        if pin == nil {
            return existingZones.isEmpty
                ? "Tap the map to drop a pin, or use your location."
                : "Tap the map to add another area. Tap an existing area to view or delete it."
        }
        return "Drag the slider to size the area, then Save."
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
        guard Key.canDelete(key, in: keys) else { return }
        modelContext.delete(key)
        inspectedKey = nil
    }

    private func save() {
        guard let pin else { return }
        onSave(pin.latitude, pin.longitude, radiusMeters)
        dismiss()
    }
}
