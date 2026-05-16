import SwiftUI

struct QRScanOverlay: View {
    let scanResult: QRService.ScanResult

    @State private var scanLineDown = false

    private var accent: Color {
        switch scanResult {
        case .none: .white
        case .valid: .green
        case .invalid: .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = QRScanWindowMetrics(container: geo.size)

            if metrics.isVisible {
                ZStack {
                    Color.black.opacity(0.55)
                        .reverseMask {
                            Rectangle()
                                .frame(width: metrics.side, height: metrics.side)
                                .position(metrics.center)
                        }

                    window(metrics: metrics)
                        .position(metrics.center)

                    if scanResult == .none {
                        Text("Point your camera at your QR code")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.black.opacity(0.4), in: Capsule())
                            .position(
                                x: metrics.center.x,
                                y: metrics.center.y + metrics.side / 2 + DS.Spacing.xxl + DS.Spacing.xl
                            )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { scanLineDown = true }
    }

    private func window(metrics: QRScanWindowMetrics) -> some View {
        ZStack {
            CornerBracketsShape(cornerLength: metrics.cornerLength)
                .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: metrics.side, height: metrics.side)
                .animation(.easeInOut(duration: 0.2), value: accent)

            if scanResult == .none {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, accent.opacity(0.9), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: metrics.scanLineWidth, height: 2)
                    .offset(y: scanLineDown ? metrics.side / 2 - 12 : -metrics.side / 2 + 12)
                    .animation(
                        .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                        value: scanLineDown
                    )
            }
        }
    }
}

private struct CornerBracketsShape: Shape {
    let cornerLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = cornerLength

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + c, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))

        return path
    }
}
