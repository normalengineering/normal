import CoreGraphics
@testable import Normal
import Testing

struct QRScanWindowMetricsTests {
    private func assertSafe(_ m: QRScanWindowMetrics) {
        #expect(m.side.isFinite && m.side >= 0)
        #expect(m.scanLineWidth.isFinite && m.scanLineWidth >= 0)
        #expect(m.cornerLength.isFinite && m.cornerLength >= 0)
        #expect(m.center.x.isFinite && m.center.y.isFinite)
    }

    @Test func zeroSizeIsNotVisibleAndSafe() {
        let m = QRScanWindowMetrics(container: .zero)
        #expect(!m.isVisible)
        #expect(m.side == 0)
        #expect(m.scanLineWidth == 0)
        assertSafe(m)
    }

    @Test func normalSizeProducesExpectedWindow() {
        let m = QRScanWindowMetrics(container: CGSize(width: 390, height: 844))
        #expect(m.isVisible)
        #expect(m.side == 390 * 0.68)
        #expect(m.center == CGPoint(x: 195, y: 422))
        #expect(m.scanLineWidth == 390 * 0.68 - 8)
        assertSafe(m)
    }

    @Test func tinySizeNeverProducesNegativeScanLine() {
        let m = QRScanWindowMetrics(container: CGSize(width: 5, height: 5))
        #expect(m.scanLineWidth == 0)
        assertSafe(m)
    }

    @Test func negativeSizeClampsToZero() {
        let m = QRScanWindowMetrics(container: CGSize(width: -100, height: -50))
        #expect(!m.isVisible)
        #expect(m.side == 0)
        assertSafe(m)
    }

    @Test func nanSizeIsSanitized() {
        let m = QRScanWindowMetrics(container: CGSize(width: CGFloat.nan, height: 800))
        #expect(!m.isVisible)
        assertSafe(m)
    }

    @Test func infiniteSizeIsSanitized() {
        let m = QRScanWindowMetrics(container: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
        assertSafe(m)
    }

    @Test func staysSafeAcrossManySizes() {
        let dimensions: [CGFloat] = [0, 1, 8, 9, 50, 320, 430, 1024, 2_000]
        for w in dimensions {
            for h in dimensions {
                assertSafe(QRScanWindowMetrics(container: CGSize(width: w, height: h)))
            }
        }
    }
}
