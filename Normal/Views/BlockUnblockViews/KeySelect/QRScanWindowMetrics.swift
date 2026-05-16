import CoreGraphics

struct QRScanWindowMetrics: Equatable {
    let side: CGFloat
    let center: CGPoint
    let scanLineWidth: CGFloat
    let cornerLength: CGFloat

    var isVisible: Bool { side > 0 }

    init(container: CGSize) {
        let width = Self.sanitize(container.width)
        let height = Self.sanitize(container.height)

        let computedSide = Self.sanitize(min(width, height) * 0.68)
        side = max(computedSide, 0)
        center = CGPoint(x: width / 2, y: height / 2)
        scanLineWidth = max(side - 8, 0)
        cornerLength = side * 0.16
    }

    private static func sanitize(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return max(value, 0)
    }
}
