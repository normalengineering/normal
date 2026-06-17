import MapKit
import SwiftUI

struct LocationUnlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: LocationUnlockModel
    private let onVerified: () -> Void

    init(keys: [Key], provider: any LocationProviding, onVerified: @escaping () -> Void) {
        _model = State(initialValue: LocationUnlockModel(keys: keys, provider: provider))
        self.onVerified = onVerified
    }

    private var kind: LocationRadiusKind { model.kind }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                map
                statusBar
            }
            .navigationTitle("Location Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("locationUnlock.close")
                }
            }
        }
        .presentationDetents([.large])
        .task {
            await model.run()
            guard model.phase == .verified else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            onVerified()
            dismiss()
        }
    }

    private var map: some View {
        Map(initialPosition: .automatic) {
            ForEach(model.locationKeys) { key in
                if let coordinate = key.coordinate, let radius = key.radiusMeters {
                    MapCircle(center: coordinate, radius: radius)
                        .foregroundStyle(kind.zoneColor.opacity(0.16))
                        .stroke(kind.zoneColor.opacity(0.9), lineWidth: 1.5)
                    Annotation(key.name, coordinate: coordinate) { zoneDot }
                        .annotationTitles(.hidden)
                }
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .overlay(kind.fieldColor.opacity(0.10).allowsHitTesting(false))
    }

    private var zoneDot: some View {
        Circle()
            .fill(kind.zoneColor.opacity(0.85))
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 1)
            .allowsHitTesting(false)
    }

    private var statusBar: some View {
        statusContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial)
            .animation(.snappy, value: model.phase)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch model.phase {
        case .checking:
            statusRow(
                icon: "location.fill", tint: kind.zoneColor, working: true,
                title: "Checking your location…", subtitle: nil
            )
            .symbolEffect(.pulse, options: .repeating)
        case .outOfRange:
            statusRow(
                icon: "location.slash.fill", tint: .orange, working: true,
                title: outOfRangeTitle, subtitle: outOfRangeSubtitle
            )
        case .unavailable:
            statusRow(
                icon: "location.slash", tint: .secondary, working: true,
                title: "Couldn't get your location", subtitle: "Trying again…"
            )
        case .permissionDenied:
            permissionDenied
        case .verified:
            statusRow(
                icon: "checkmark.circle.fill", tint: .green, working: false,
                title: "Location verified", subtitle: "Unlocking…"
            )
            .symbolEffect(.bounce, value: model.phase)
        }
    }

    private func statusRow(
        icon: String, tint: Color, working: Bool, title: String, subtitle: String?
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: DS.Size.iconWell)
            VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if working { ProgressView() }
        }
    }

    private var permissionDenied: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            statusRow(
                icon: "location.slash", tint: .orange, working: false,
                title: "Location Permission Needed",
                subtitle: "Allow location access so Normal can verify this key. Other keys still work without it."
            )
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.bold())
        }
    }

    private var outOfRangeTitle: String {
        kind == .unblock ? "You're not in an unlock area" : "You're in a blocked area"
    }

    private var outOfRangeSubtitle: String {
        kind == .unblock
            ? "Move into a highlighted area to unlock."
            : "Leave the highlighted area to unlock."
    }
}
