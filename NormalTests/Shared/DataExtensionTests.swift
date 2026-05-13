@testable import Normal
import Foundation
import Testing

struct DataExtensionTests {
    @Test func hexStringEmpty() {
        #expect(Data().hexString == "")
    }

    @Test func hexStringSingleByte() {
        #expect(Data([0xff]).hexString == "ff")
    }

    @Test func hexStringMultipleBytes() {
        #expect(Data([0x01, 0x0a, 0xff]).hexString == "010aff")
    }

    @Test func hexStringLeadingZero() {
        #expect(Data([0x00, 0x01]).hexString == "0001")
    }
}
