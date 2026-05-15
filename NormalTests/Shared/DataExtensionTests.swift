@testable import Normal
import Foundation
import Testing

struct DataExtensionTests {
    @Test func emptyDataHasEmptyHex() {
        #expect(Data().hexString == "")
    }

    @Test func singleByteHex() {
        #expect(Data([0x0a]).hexString == "0a")
        #expect(Data([0xff]).hexString == "ff")
    }

    @Test func multiByteHex() {
        #expect(Data([0xde, 0xad, 0xbe, 0xef]).hexString == "deadbeef")
    }

    @Test func zeroPaddedSingleDigits() {
        #expect(Data([0x00, 0x01, 0x02]).hexString == "000102")
    }
}
