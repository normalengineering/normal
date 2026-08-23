import Foundation

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

extension Data {
    /// Deterministic across launches, unlike `hashValue`, which Swift seeds
    /// randomly per process. Used to tell whether a persisted payload changed.
    var stableChecksum: String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in self {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return String(hash, radix: 16)
    }
}
