import Foundation
@testable import Normal
import Testing

struct DataExtensionTests {
    @Test func emptyDataHasEmptyHex() {
        #expect(Data().hexString == "")
    }

    @Test func singleByteHex() {
        #expect(Data([0x0A]).hexString == "0a")
        #expect(Data([0xFF]).hexString == "ff")
    }

    @Test func multiByteHex() {
        #expect(Data([0xDE, 0xAD, 0xBE, 0xEF]).hexString == "deadbeef")
    }

    @Test func zeroPaddedSingleDigits() {
        #expect(Data([0x00, 0x01, 0x02]).hexString == "000102")
    }
}
