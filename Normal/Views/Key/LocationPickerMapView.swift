import CoreLocation
import MapKit
import SwiftUI

struct LocationPickerMapView: View {
    let kind: LocationRadiusKind
    let zones: [Key]
    @Binding var pin: CLLocationCoordinate2D?
    @Binding var position: MapCameraPosition
    let radiusMeters: Double
    let onInspect: (Key) -> Void

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                zoneOverlays
                pinOverlay
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

    @MapContentBuilder
    private var zoneOverlays: some MapContent {
        ForEach(zones) { key in
            if let coordinate = key.coordinate, let radius = key.radiusMeters {
                MapCircle(center: coordinate, radius: radius)
                    .foregroundStyle(kind.zoneColor.opacity(0.16))
                    .stroke(kind.zoneColor.opacity(0.9), lineWidth: 1.5)
                Annotation(key.name, coordinate: coordinate) { zoneDot }
                    .annotationTitles(.hidden)
            }
        }
    }

    @MapContentBuilder
    private var pinOverlay: some MapContent {
        if let pin {
            MapCircle(center: pin, radius: radiusMeters)
                .foregroundStyle(kind.zoneColor.opacity(0.28))
                .stroke(kind.zoneColor, style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
            Annotation("New", coordinate: pin) { newPin }
                .annotationTitles(.hidden)
        }
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

    private var zoneDot: some View {
        Circle()
            .fill(kind.zoneColor.opacity(0.85))
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
        if let hit = zones.first(where: { key in
            guard let c = key.coordinate, let r = key.radiusMeters else { return false }
            return CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: tapped) <= r
        }) {
            onInspect(hit)
        } else {
            withAnimation(.easeOut(duration: 0.2)) { pin = coordinate }
        }
    }
}
