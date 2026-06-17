import MapKit
import SwiftUI

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

                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }
}
