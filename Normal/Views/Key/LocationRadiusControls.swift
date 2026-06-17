import SwiftUI

struct LocationRadiusControls: View {
    let kind: LocationRadiusKind
    @Binding var radiusMeters: Double
    let canUseCurrentLocation: Bool
    let hint: String
    let onUseCurrentLocation: () -> Void

    static let minRadius: Double = 50
    static let maxRadius: Double = 5000

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            legend

            HStack {
                Text(radiusLabel)
                    .font(.headline.monospacedDigit())
                Spacer()
                Button(action: onUseCurrentLocation) {
                    Label("My Location", systemImage: "location.fill").font(.subheadline)
                }
                .accessibilityIdentifier("locationPicker.useCurrentButton")
                .disabled(!canUseCurrentLocation)
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

    private var radiusLabel: String {
        "Radius: \(LocationFormat.distance(meters: radiusMeters))"
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
}
