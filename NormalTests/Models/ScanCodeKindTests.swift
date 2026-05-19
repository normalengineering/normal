import Foundation
@testable import Normal
import Testing

struct ScanCodeKindTests {
    @Test func labelsAreUserFacing() {
        #expect(ScanCodeKind.qr.label == "QR Code")
        #expect(ScanCodeKind.barcode.label == "Barcode")
    }

    @Test func iconsAreSet() {
        #expect(ScanCodeKind.qr.icon == "qrcode")
        #expect(ScanCodeKind.barcode.icon == "barcode")
    }

    @Test func roundTripsThroughCodableForSwiftDataStorage() throws {
        for kind in [ScanCodeKind.qr, .barcode] {
            let data = try JSONEncoder().encode(kind)
            #expect(try JSONDecoder().decode(ScanCodeKind.self, from: data) == kind)
        }
    }
}
